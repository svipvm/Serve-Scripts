#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

HEADSCALE_CONFIG_DIR="/opt/headscale/config"
CADDY_CONFIG_DIR="/opt/caddy/config"

echo "=========================================="
echo "Headscale 部署脚本"
echo "=========================================="

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "错误: 请使用 sudo 运行此脚本"
        echo "示例: sudo ./start.sh"
        exit 1
    fi
}

load_env() {
    if [ ! -f "$ENV_FILE" ]; then
        echo "错误: .env 文件不存在"
        echo "请复制 .env.example 为 .env 并配置 SERVER_HOST"
        exit 1
    fi
    
    set -a
    source "$ENV_FILE"
    set +a
    
    if [ -z "$SERVER_HOST" ] || [ "$SERVER_HOST" = "your-server-ip-or-domain" ]; then
        echo "错误: 请在 .env 中设置 SERVER_HOST"
        exit 1
    fi
    
    echo "服务器地址: $SERVER_HOST"
}

create_directories() {
    echo ""
    echo "创建目录..."
    
    mkdir -p /opt/headscale/data /opt/headscale/run
    mkdir -p "$HEADSCALE_CONFIG_DIR"
    mkdir -p /opt/caddy/data
    mkdir -p "$CADDY_CONFIG_DIR"
    
    echo "✓ 目录创建完成"
}

generate_headscale_config() {
    echo ""
    echo "生成 Headscale 配置文件..."
    
    cat > "${HEADSCALE_CONFIG_DIR}/config.yaml" << EOF
server_url: http://${SERVER_HOST}:${HEADSCALE_PORT:-8080}
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 0.0.0.0:9090
grpc_listen_addr: 0.0.0.0:50443

noise:
  private_key_path: /var/lib/headscale/noise_private.key

database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite

derp:
  server:
    enabled: true
    region_id: ${DERP_REGION_ID:-999}
    region_code: "${DERP_REGION_CODE:-headscale}"
    region_name: "${DERP_REGION_NAME:-Headscale Embedded DERP}"
    stun_listen_addr: "0.0.0.0:3478"
    private_key_path: /var/lib/headscale/derp_server_private.key
    automatically_add_embedded_derp_region: true
    ipv4: "${SERVER_HOST}"
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  paths: []
  auto_update_enabled: true
  update_frequency: 24h

prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential

dns:
  magic_dns: false
  override_local_dns: false
  nameservers:
    global: []

log:
  format: text
  level: info

disable_check_updates: true
ephemeral_node_inactivity_timeout: 30m
randomize_client_port: true

unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
EOF
    
    echo "✓ 生成 config.yaml"
}

generate_derp_config() {
    echo ""
    echo "生成 DERP 配置文件..."
    
    cat > "${HEADSCALE_CONFIG_DIR}/derp.yaml" << EOF
regions:
  900:
    regionid: 900
    regioncode: "headscale"
    regionname: "Headscale Embedded DERP"
    nodes:
      - name: "headscale-embedded"
        regionid: 900
        hostname: "${SERVER_HOST}"
        stunport: ${HEADSCALE_STUN_PORT:-3478}
        derpport: ${HEADSCALE_PORT:-8080}
        ipv4: "${SERVER_HOST}"
        insecure_for_tests: true
EOF
    
    echo "✓ 生成 derp.yaml"
}

generate_caddy_config() {
    echo ""
    echo "生成 Caddy 配置文件..."
    
    PASSWORD_HASH='$2a$14$WBdqJBcNsSxNdolCWj7MS.armz2e2My2jiGToHMA/h6tVrtld54te'
    
    cat > "${CADDY_CONFIG_DIR}/Caddyfile" << EOF
{
    auto_https off
}

:80 {
    @api path /api/*
    handle @api {
        reverse_proxy host.docker.internal:${HEADSCALE_PORT:-8080}
    }
    
    handle {
        reverse_proxy headscale-ui:8080
    }
}

:${UI_HTTP_PORT:-8008} {
    basic_auth {
        ${UI_AUTH_USER:-admin} ${PASSWORD_HASH}
    }
    
    @web path /web*
    handle @web {
        reverse_proxy headscale-ui:8080
    }
    
    handle {
        redir /web/ permanent
    }
}

:${UI_API_PORT:-8081} {
    @preflight method OPTIONS
    
    handle @preflight {
        header Access-Control-Allow-Origin "http://${SERVER_HOST}:${UI_HTTP_PORT:-8008}"
        header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        header Access-Control-Allow-Headers "Authorization, Content-Type"
        header Access-Control-Allow-Credentials "true"
        header Access-Control-Max-Age "86400"
        respond "" 204
    }
    
    handle {
        reverse_proxy host.docker.internal:${HEADSCALE_PORT:-8080} {
            header_down +Access-Control-Allow-Origin "http://${SERVER_HOST}:${UI_HTTP_PORT:-8008}"
            header_down +Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            header_down +Access-Control-Allow-Headers "Authorization, Content-Type"
            header_down +Access-Control-Allow-Credentials "true"
        }
    }
}
EOF
    
    echo "✓ 生成 Caddyfile"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "错误: Docker 未安装"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "错误: 无法连接 Docker"
        exit 1
    fi
    
    echo "✓ Docker 已就绪"
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "错误: Docker Compose 未安装"
        exit 1
    fi
    echo "✓ Docker Compose 已就绪"
}

deploy() {
    echo ""
    echo "部署服务..."
    
    cd "$SCRIPT_DIR"
    
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        echo "停止现有服务..."
        docker-compose down
    fi
    
    echo "构建镜像..."
    docker-compose build
    
    echo "启动服务..."
    docker-compose up -d
    
    echo "✓ 服务已启动"
}

show_info() {
    echo ""
    echo "=========================================="
    echo "部署完成！"
    echo "=========================================="
    echo ""
    echo "配置文件位置:"
    echo "  Headscale: ${HEADSCALE_CONFIG_DIR}"
    echo "  Caddy: ${CADDY_CONFIG_DIR}"
    echo ""
    echo "访问地址:"
    echo "  UI: http://${SERVER_HOST}:${UI_HTTP_PORT:-8008}/web/"
    echo "  API: http://${SERVER_HOST}:${UI_API_PORT:-8081}"
    echo "  服务: http://${SERVER_HOST}:${HEADSCALE_PORT:-8080}"
    echo ""
    echo "UI 认证:"
    echo "  用户名: ${UI_AUTH_USER:-admin}"
    echo "  密码: ${UI_AUTH_PASSWORD:-headscale}"
    echo ""
    echo "DERP 服务器:"
    echo "  状态: 已启用"
    echo "  STUN 端口: ${HEADSCALE_STUN_PORT:-3478}/udp"
    echo ""
    echo "创建 API Key:"
    echo "  sudo docker exec headscale headscale apikeys create --expiration 87600h"
    echo ""
    echo "创建 PreAuth Key:"
    echo "  sudo docker exec headscale headscale users create <用户名>"
    echo "  sudo docker exec headscale headscale preauthkeys create --user <ID> --reusable --expiration 8760h"
    echo ""
}

main() {
    check_root
    
    echo ""
    echo "步骤 1/6: 加载配置"
    load_env
    
    echo ""
    echo "步骤 2/6: 创建目录"
    create_directories
    
    echo ""
    echo "步骤 3/6: 生成 Headscale 配置"
    generate_headscale_config
    
    echo ""
    echo "步骤 4/6: 生成 DERP 和 Caddy 配置"
    generate_derp_config
    generate_caddy_config
    
    echo ""
    echo "步骤 5/6: 检查环境并部署"
    check_docker
    check_docker_compose
    deploy
    
    echo ""
    echo "步骤 6/6: 验证服务"
    sleep 3
    docker-compose ps
    
    show_info
}

main "$@"

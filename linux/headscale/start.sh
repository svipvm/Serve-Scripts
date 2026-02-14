#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
TEMPLATE_DIR="$SCRIPT_DIR/config"

HEADSCALE_CONFIG_DIR="/opt/headscale/config"
CADDY_CONFIG_DIR="/opt/caddy/config"
PASSWORD_HASH=""

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

generate_tls_certificates() {
    local TLS_ENABLED="${TLS_ENABLED:-true}"
    local TLS_CERT="${TLS_CERT_PATH:-/opt/headscale/config/tls.crt}"
    local TLS_KEY="${TLS_KEY_PATH:-/opt/headscale/config/tls.key}"
    
    if [ "$TLS_ENABLED" = "true" ]; then
        echo ""
        echo "生成 TLS 自签名证书..."
        
        if [ ! -f "$TLS_CERT" ] || [ ! -f "$TLS_KEY" ]; then
            openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
                -keyout "$TLS_KEY" \
                -out "$TLS_CERT" \
                -subj "/CN=${SERVER_HOST}" \
                -addext "subjectAltName=IP:${SERVER_HOST},DNS:${SERVER_HOST}"
            
            chmod 600 "$TLS_KEY"
            chmod 644 "$TLS_CERT"
            
            echo "✓ 生成自签名证书 (有效期 10 年)"
            echo "  证书: $TLS_CERT"
            echo "  私钥: $TLS_KEY"
        else
            echo "✓ 使用现有证书"
        fi
    fi
}

generate_headscale_config() {
    echo ""
    echo "生成 Headscale 配置文件..."
    
    local TEMPLATE="${TEMPLATE_DIR}/config.yaml.template"
    local OUTPUT="${HEADSCALE_CONFIG_DIR}/config.yaml"
    
    if [ ! -f "$TEMPLATE" ]; then
        echo "错误: 模板文件不存在: $TEMPLATE"
        exit 1
    fi
    
    cp "$TEMPLATE" "$OUTPUT"
    
    sed -i "s|\${SERVER_HOST}|${SERVER_HOST}|g" "$OUTPUT"
    sed -i "s|\${HEADSCALE_PORT}|${HEADSCALE_PORT:-8080}|g" "$OUTPUT"
    sed -i "s|\${DERP_ENABLED}|${DERP_ENABLED:-true}|g" "$OUTPUT"
    sed -i "s|\${DERP_REGION_ID}|${DERP_REGION_ID:-999}|g" "$OUTPUT"
    sed -i "s|\${DERP_REGION_CODE}|${DERP_REGION_CODE:-headscale}|g" "$OUTPUT"
    sed -i "s|\${DERP_REGION_NAME}|${DERP_REGION_NAME:-Headscale Embedded DERP}|g" "$OUTPUT"
    sed -i "s|\${DERP_IPV6}|${DERP_IPV6:-\"\"}|g" "$OUTPUT"
    sed -i "s|\${DNS_MAGIC_DNS}|${DNS_MAGIC_DNS:-false}|g" "$OUTPUT"
    sed -i "s|\${DNS_BASE_DOMAIN}|${DNS_BASE_DOMAIN:-example.com}|g" "$OUTPUT"
    # TLS 配置留空，由 Caddy 处理 HTTPS
    sed -i "s|\${TLS_CERT_PATH}||g" "$OUTPUT"
    sed -i "s|\${TLS_KEY_PATH}||g" "$OUTPUT"
    
    echo "✓ 生成 config.yaml"
}

generate_derp_config() {
    echo ""
    echo "生成 DERP 配置文件..."
    
    local TEMPLATE="${TEMPLATE_DIR}/derp.yaml.template"
    local OUTPUT="${HEADSCALE_CONFIG_DIR}/derp.yaml"
    
    if [ ! -f "$TEMPLATE" ]; then
        echo "错误: 模板文件不存在: $TEMPLATE"
        exit 1
    fi
    
    cp "$TEMPLATE" "$OUTPUT"
    
    sed -i "s|\${SERVER_HOST}|${SERVER_HOST}|g" "$OUTPUT"
    sed -i "s|\${HEADSCALE_STUN_PORT}|${HEADSCALE_STUN_PORT:-3478}|g" "$OUTPUT"
    sed -i "s|\${HEADSCALE_PORT}|${HEADSCALE_PORT:-8080}|g" "$OUTPUT"
    
    echo "✓ 生成 derp.yaml"
}

generate_caddy_config() {
    echo ""
    echo "生成 Caddy 配置文件..."
    
    local TEMPLATE="${TEMPLATE_DIR}/Caddyfile.template"
    local OUTPUT="${CADDY_CONFIG_DIR}/Caddyfile"
    
    if [ ! -f "$TEMPLATE" ]; then
        echo "错误: 模板文件不存在: $TEMPLATE"
        exit 1
    fi
    
    local UI_PASSWORD="${UI_AUTH_PASSWORD:-headscale}"
    PASSWORD_HASH=$(docker run --rm caddy:2.10.2 caddy hash-password --plaintext "$UI_PASSWORD")
    
    cp "$TEMPLATE" "$OUTPUT"
    
    sed -i "s|\${SERVER_HOST}|${SERVER_HOST}|g" "$OUTPUT"
    sed -i "s|\${HEADSCALE_PORT}|${HEADSCALE_PORT:-8080}|g" "$OUTPUT"
    sed -i "s|\${UI_HTTP_PORT}|${UI_HTTP_PORT:-8008}|g" "$OUTPUT"
    sed -i "s|\${UI_API_PORT}|${UI_API_PORT:-8081}|g" "$OUTPUT"
    sed -i "s|\${CADDY_HTTPS_PORT}|${CADDY_HTTPS_PORT:-8443}|g" "$OUTPUT"
    sed -i "s|\${UI_AUTH_USER}|${UI_AUTH_USER:-admin}|g" "$OUTPUT"
    sed -i "s|\${PASSWORD_HASH}|${PASSWORD_HASH}|g" "$OUTPUT"
    
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

configure_firewall() {
    echo ""
    echo "配置防火墙..."
    
    if ! command -v ufw &> /dev/null; then
        echo "UFW 未安装，正在安装..."
        apt-get install -y -qq ufw
        echo "✓ UFW 已安装"
    fi
    
    ufw allow ${HEADSCALE_PORT:-8080}/tcp comment 'Headscale Control' || true
    ufw allow ${HEADSCALE_STUN_PORT:-3478}/udp comment 'Headscale STUN' || true
    ufw allow ${UI_HTTP_PORT:-8008}/tcp comment 'Headscale UI' || true
    ufw allow ${UI_API_PORT:-8081}/tcp comment 'Headscale UI API' || true
    ufw allow ${CADDY_HTTPS_PORT:-8443}/tcp comment 'Headscale HTTPS' || true
    
    echo "✓ 防火墙规则已配置"
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
    local TLS_ENABLED="${TLS_ENABLED:-true}"
    local PROTOCOL="https"
    [ "$TLS_ENABLED" != "true" ] && PROTOCOL="http"
    
    echo "访问地址:"
    echo "  UI 界面: http://${SERVER_HOST}:${UI_HTTP_PORT:-8008}/web/"
    echo "  API 端口: http://${SERVER_HOST}:${UI_API_PORT:-8081}"
    echo "  Headscale HTTP: http://${SERVER_HOST}:${HEADSCALE_PORT:-8080}"
    echo "  Headscale HTTPS: https://${SERVER_HOST}:${CADDY_HTTPS_PORT:-8443} (用于 Tailscale 客户端)"
    echo ""
    echo "证书信息:"
    echo "  证书路径: ${TLS_CERT_PATH:-/opt/headscale/config/tls.crt}"
    echo "  私钥路径: ${TLS_KEY_PATH:-/opt/headscale/config/tls.key}"
    echo "  注意: Windows 客户端首次连接时会提示证书不受信任，需要手动接受"
    echo "        建议先访问 https://${SERVER_HOST}:${CADDY_HTTPS_PORT:-8443} 手动信任证书"
    echo ""
    echo "UI 认证:"
    echo "  用户名: ${UI_AUTH_USER:-admin}"
    echo "  密码: ${UI_AUTH_PASSWORD:-headscale}"
    echo "  密码哈希: ${PASSWORD_HASH}"
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
    echo "步骤 1/7: 加载配置"
    load_env
    
    echo ""
    echo "步骤 2/7: 创建目录"
    create_directories
    
    echo ""
    echo "步骤 3/7: 生成 TLS 证书"
    generate_tls_certificates
    
    echo ""
    echo "步骤 4/7: 生成 Headscale 配置"
    generate_headscale_config
    
    echo ""
    echo "步骤 5/7: 生成 DERP 和 Caddy 配置"
    generate_derp_config
    generate_caddy_config

    echo ""
    echo "步骤 6/7: 配置防火墙"
    configure_firewall

    echo ""
    echo "步骤 7/7: 检查环境并部署"
    check_docker
    check_docker_compose
    deploy

    echo ""
    echo "步骤 8/8: 验证服务"
    sleep 3
    docker-compose ps
    
    show_info
}

main "$@"

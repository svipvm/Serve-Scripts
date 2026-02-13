#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

echo "=========================================="
echo "Tailscale 客户端部署脚本"
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
        echo "请复制 .env.example 为 .env 并配置相关参数"
        exit 1
    fi
    
    set -a
    source "$ENV_FILE"
    set +a
    
    if [ -z "$TAILSCALE_AUTH_KEY" ] || [ "$TAILSCALE_AUTH_KEY" = "your-auth-key-here" ]; then
        echo "错误: 请在 .env 中设置 TAILSCALE_AUTH_KEY"
        exit 1
    fi
    
    if [ -z "$TS_LOGIN_SERVER" ]; then
        echo "错误: 请在 .env 中设置 TS_LOGIN_SERVER"
        exit 1
    fi
    
    echo "登录服务器: $TS_LOGIN_SERVER"
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

deploy() {
    echo ""
    echo "部署服务..."
    
    cd "$SCRIPT_DIR"
    
    export TAILSCALE_AUTH_KEY
    export TS_LOGIN_SERVER
    
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        echo "停止现有服务..."
        docker-compose down
    fi
    
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
    echo "登录服务器: $TS_LOGIN_SERVER"
    echo ""
    echo "查看状态:"
    echo "  sudo docker logs tailscale-client"
    echo ""
    echo "查看节点:"
    echo "  sudo docker exec headscale headscale nodes list"
    echo ""
}

main() {
    check_root
    
    echo ""
    echo "步骤 1/3: 加载配置"
    load_env
    
    echo ""
    echo "步骤 2/3: 检查环境"
    check_docker
    
    echo ""
    echo "步骤 3/3: 部署服务"
    deploy
    
    sleep 3
    docker-compose ps
    
    show_info
}

main "$@"

#!/bin/bash
# RustDesk Server 启动脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
}

check_env() {
    if [ ! -f ".env" ]; then
        log_warn ".env 文件不存在，从 .env.example 复制..."
        cp .env.example .env
        log_info "已创建 .env 文件，请根据需要修改配置"
    fi
}

create_data_dirs() {
    source .env 2>/dev/null || true
    DATA_DIR="${DATA_DIR:-/opt/rustdesk-server}"

    sudo mkdir -p "$DATA_DIR/hbbs" "$DATA_DIR/hbbr"
    log_info "数据目录已创建: $DATA_DIR"
}

configure_firewall() {
    if command -v ufw &> /dev/null; then
        log_info "配置防火墙规则..."
        sudo ufw allow 21114/tcp 2>/dev/null || true
        sudo ufw allow 21115/tcp 2>/dev/null || true
        sudo ufw allow 21116/tcp 2>/dev/null || true
        sudo ufw allow 21116/udp 2>/dev/null || true
        sudo ufw allow 21117/tcp 2>/dev/null || true
        sudo ufw allow 21118/tcp 2>/dev/null || true
        sudo ufw allow 21119/tcp 2>/dev/null || true
        log_info "防火墙规则已配置"
    fi
}

start_services() {
    log_info "启动 RustDesk Server..."

    if docker compose version &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi

    sleep 2

    log_info "服务状态:"
    docker ps --filter "name=hbbs" --filter "name=hbbr" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

show_public_key() {
    source .env 2>/dev/null || true
    DATA_DIR="${DATA_DIR:-/opt/rustdesk-server}"
    KEY_FILE="${KEY_FILE:-id_ed25519}"
    PUB_KEY="$DATA_DIR/hbbs/${KEY_FILE}.pub"
    PUB_KEY_FILE="$DATA_DIR/id.pub"

    sleep 3

    if [ -f "$PUB_KEY" ]; then
        PUB_KEY_CONTENT=$(cat "$PUB_KEY")
        
        log_info "公钥内容 (客户端连接时需要):"
        echo ""
        echo "$PUB_KEY_CONTENT"
        echo ""
        
        echo "$PUB_KEY_CONTENT" | sudo tee "$PUB_KEY_FILE" > /dev/null
        log_info "公钥已保存到: $PUB_KEY_FILE"
    else
        log_warn "公钥文件尚未生成，请稍后查看: $PUB_KEY"
    fi
}

main() {
    log_info "RustDesk Server 启动脚本"
    echo "======================================"

    check_docker
    check_env
    create_data_dirs
    configure_firewall
    start_services
    show_public_key

    echo "======================================"
    log_info "RustDesk Server 已启动完成!"
    log_info "服务器地址: $(hostname -I | awk '{print $1}')"
    log_info "请将公钥配置到客户端以完成连接"
}

main "$@"

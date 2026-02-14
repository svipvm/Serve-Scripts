#!/bin/bash
# RustDesk Server 停止脚本

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

stop_services() {
    log_info "停止 RustDesk Server..."

    if docker compose version &> /dev/null; then
        docker compose down
    else
        docker-compose down
    fi

    log_info "服务已停止"
}

remove_firewall() {
    if command -v ufw &> /dev/null; then
        log_info "移除防火墙规则..."
        sudo ufw delete allow 21114/tcp 2>/dev/null || true
        sudo ufw delete allow 21115/tcp 2>/dev/null || true
        sudo ufw delete allow 21116/tcp 2>/dev/null || true
        sudo ufw delete allow 21116/udp 2>/dev/null || true
        sudo ufw delete allow 21117/tcp 2>/dev/null || true
        sudo ufw delete allow 21118/tcp 2>/dev/null || true
        sudo ufw delete allow 21119/tcp 2>/dev/null || true
        log_info "防火墙规则已移除"
    fi
}

show_status() {
    log_info "容器状态:"
    docker ps -a --filter "name=hbbs" --filter "name=hbbr" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "无相关容器"
}

clean_data() {
    if [ "$1" == "--clean" ]; then
        source .env 2>/dev/null || true
        DATA_DIR="${DATA_DIR:-/opt/rustdesk-server}"

        log_warn "即将删除数据目录: $DATA_DIR"
        read -p "确认删除? (y/N): " confirm

        if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
            sudo rm -rf "$DATA_DIR"
            log_info "数据目录已删除"
        else
            log_info "取消删除"
        fi
    fi
}

main() {
    log_info "RustDesk Server 停止脚本"
    echo "======================================"

    stop_services
    show_status

    if [ "$1" == "--clean" ]; then
        remove_firewall
        clean_data "$1"
    fi

    echo "======================================"
    log_info "RustDesk Server 已停止"
}

main "$@"

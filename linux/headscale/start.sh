#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Headscale Docker 部署脚本"
echo "=========================================="

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "错误: Docker 未安装，请先安装 Docker"
        exit 1
    fi
    echo "✓ Docker 已安装"
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "错误: Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    echo "✓ Docker Compose 已安装"
}

create_directories() {
    echo ""
    echo "创建必要的目录结构..."
    mkdir -p /opt/headscale/data /opt/headscale/run
    chmod 770 /opt/headscale/data
    chmod 770 /opt/headscale/run
    echo "✓ 目录结构创建完成: /opt/headscale"
}

build_image() {
    echo ""
    echo "构建 Headscale Docker 镜像..."
    if docker-compose build; then
        echo "✓ 镜像构建完成"
    else
        echo "错误: 镜像构建失败"
        exit 1
    fi
}

start_service() {
    echo ""
    echo "启动 Headscale 服务..."
    echo "设置目录权限..."
    chown -R 999:999 /opt/headscale/data /opt/headscale/run
    echo "✓ 目录权限设置完成"
    if docker-compose up -d; then
        echo "✓ 服务启动成功"
    else
        echo "错误: 服务启动失败"
        exit 1
    fi
}

check_service_status() {
    echo ""
    echo "检查服务状态..."
    sleep 3
    if docker-compose ps | grep -q "Up"; then
        echo "✓ Headscale 服务正在运行"
        echo ""
        echo "服务信息:"
        docker-compose ps
        echo ""
        echo "访问地址:"
        echo "  - HTTP API: http://localhost:8080"
        echo "  - Metrics: http://localhost:9090"
        echo "  - gRPC: localhost:50443"
        echo ""
        echo "查看日志: docker-compose logs -f"
        echo "停止服务: ./stop.sh"
        echo "重启服务: ./restart.sh"
    else
        echo "警告: 服务可能未正常启动，请检查日志"
        docker-compose logs
    fi
}

main() {
    check_docker
    check_docker_compose
    create_directories
    build_image
    start_service
    check_service_status
    
    echo ""
    echo "=========================================="
    echo "部署完成！"
    echo "=========================================="
}

main "$@"

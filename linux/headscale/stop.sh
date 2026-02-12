#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "停止 Headscale 服务"
echo "=========================================="

if docker-compose down; then
    echo "✓ Headscale 服务已停止"
else
    echo "警告: 停止服务时出现错误"
    exit 1
fi

echo ""
echo "查看容器状态:"
docker ps -a | grep headscale || echo "没有找到 headscale 容器"

echo ""
echo "=========================================="
echo "服务已停止"
echo "=========================================="

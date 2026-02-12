#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "重启 Headscale 服务"
echo "=========================================="

if docker-compose restart; then
    echo "✓ Headscale 服务已重启"
else
    echo "错误: 重启服务失败"
    exit 1
fi

echo ""
echo "等待服务启动..."
sleep 3

echo ""
echo "检查服务状态:"
docker-compose ps

echo ""
echo "=========================================="
echo "服务已重启"
echo "=========================================="

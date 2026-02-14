#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

cd "$SCRIPT_DIR" || { echo "错误：无法切换到脚本目录 $SCRIPT_DIR"; exit 1; }

if ! docker-compose down; then
    echo "错误：停止 Docker Compose 服务失败"
    exit 1
fi

echo "Nextcloud 服务已成功停止"

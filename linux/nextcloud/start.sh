#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "错误: docker 命令不存在，请先安装 Docker"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo "错误: docker-compose 命令不存在，请先安装 Docker Compose"
        exit 1
    fi
}

load_env() {
    local env_file="$SCRIPT_DIR/.env"
    if [[ ! -f "$env_file" ]]; then
        echo "错误: .env 文件不存在: $env_file"
        exit 1
    fi

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        export "$key=$value"
    done < "$env_file"
}

create_nextcloud_dir() {
    local nextcloud_dir="/opt/nextcloud"
    if [[ ! -d "$nextcloud_dir" ]]; then
        mkdir -p "$nextcloud_dir" || {
            echo "错误: 无法创建目录 $nextcloud_dir"
            exit 1
        }
        echo "已创建目录: $nextcloud_dir"
    fi
}

process_config_template() {
    local template_file="$SCRIPT_DIR/config/config.php.template"
    local output_file="/opt/nextcloud/config/config.php"
    local output_dir
    output_dir=$(dirname "$output_file")

    if [[ ! -f "$template_file" ]]; then
        echo "错误: 配置模板文件不存在: $template_file"
        exit 1
    fi

    mkdir -p "$output_dir" || {
        echo "错误: 无法创建目录 $output_dir"
        exit 1
    }

    local content
    content=$(cat "$template_file")

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        content="${content//\$\{$key\}/$value}"
    done < "$SCRIPT_DIR/.env"

    echo "$content" > "$output_file" || {
        echo "错误: 无法写入配置文件 $output_file"
        exit 1
    }
    echo "已生成配置文件: $output_file"
}

start_docker_compose() {
    cd "$SCRIPT_DIR" || {
        echo "错误: 无法切换到脚本目录 $SCRIPT_DIR"
        exit 1
    }

    docker-compose up -d || {
        echo "错误: Docker Compose 启动失败"
        exit 1
    }
}

main() {
    echo "=== Nextcloud 启动脚本 ==="

    echo "[1/5] 检查 Docker 环境..."
    check_docker

    echo "[2/5] 加载 .env 文件..."
    load_env

    echo "[3/5] 创建 Nextcloud 目录..."
    create_nextcloud_dir

    echo "[4/5] 处理配置文件模板..."
    process_config_template

    echo "[5/5] 启动 Docker Compose 服务..."
    start_docker_compose

    echo ""
    echo "=== Nextcloud 启动成功 ==="
}

main "$@"

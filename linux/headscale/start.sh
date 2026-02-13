#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
DERP_FILE="$CONFIG_DIR/derp.yaml"

echo "=========================================="
echo "Headscale 自适应部署脚本"
echo "=========================================="

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "错误: 请使用 sudo 运行此脚本"
        echo "示例: sudo ./deploy.sh"
        exit 1
    fi
}

detect_ip() {
    echo "自动检测 IP 地址..."
    
    if command -v hostname &> /dev/null; then
        IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    elif command -v ip &> /dev/null; then
        IP=$(ip route get 1 2>/dev/null | awk '{print $7}')
    else
        echo "错误: 无法检测到本地 IP 地址"
        exit 1
    fi
    
    if [ -z "$IP" ]; then
        echo "错误: IP 检测失败"
        exit 1
    fi
    
    echo "检测到本地 IP 地址: $IP"
    echo "$IP"
}

update_config() {
    local ip=$1
    local config_file=$2
    local config_key=$3
    
    if [ ! -f "$config_file" ]; then
        echo "错误: 配置文件不存在: $config_file"
        return 1
    fi
    
    echo "更新 $config_file 中的 $config_key..."
    
    case "$config_key" in
        server_url)
            sed -i "s|^server_url:.*|server_url: http://$ip:8080|" "$config_file"
            ;;
        listen_addr)
            sed -i "s|^listen_addr:.*|listen_addr: 0.0.0.0:8080|" "$config_file"
            ;;
        *)
            echo "警告: 未知的配置键: $config_key"
            return 1
            ;;
    esac
    
    echo "✓ 已更新 $config_file 中的 $config_key"
    return 0
}

update_derp_config() {
    local ip=$1
    local derp_file=$2
    
    if [ ! -f "$derp_file" ]; then
        echo "错误: DERP 配置文件不存在: $derp_file"
        return 1
    fi
    
    echo "更新 $derp_file 中的 DERP 配置..."
    
    sed -i 's|hostname: ".*"|hostname: "'"$ip"'"|' "$derp_file"
    sed -i 's|ipv4: ".*"|ipv4: "'"$ip"'"|' "$derp_file"
    
    echo "✓ 已更新 $derp_file 中的 DERP 配置"
    return 0
}

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

stop_existing_container() {
    echo ""
    echo "停止现有容器..."
    
    if docker-compose ps | grep -q "headscale"; then
        echo "停止现有 Headscale 容器..."
        docker-compose down
    else
        echo "没有运行中的 Headscale 容器"
    fi
}

start_service() {
    echo ""
    echo "启动 Headscale 服务..."
    
    if docker-compose up -d; then
        echo "✓ 服务启动成功"
    else
        echo "错误: 服务启动失败"
        exit 1
    fi
}

check_service_status() {
    echo ""
    echo "验证服务状态..."
    sleep 5
    
    if docker-compose ps | grep -q "Up"; then
        echo "✅ Headscale 容器正在运行"
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
        echo "❌ Headscale 容器未运行"
        echo ""
        echo "查看日志以排查问题:"
        echo "  docker logs headscale"
        exit 1
    fi
}

show_usage() {
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -i, --ip IP_ADDRESS      指定 IP 地址（可选）"
    echo "  -h, --help              显示帮助信息"
    echo ""
    echo "示例:"
    echo "  sudo $0                          自动检测 IP 并部署"
    echo "  sudo $0 -i 192.168.1.100       使用指定 IP 部署"
    echo "  sudo $0 --ip 203.0.113.1      使用指定公网 IP 部署"
    exit 0
}

main() {
    local ip_address=""
    
    args=("$@")
    i=0
    while [ $i -lt ${#args[@]} ]; do
        case "${args[$i]}" in
            -i|--ip)
                if [ $((i + 1)) -lt ${#args[@]} ]; then
                    ip_address="${args[$((i + 1))]}"
                    i=$((i + 2))
                else
                    echo "错误: -i/--ip 选项需要参数"
                    exit 1
                fi
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                echo "未知选项: ${args[$i]}"
                show_usage
                ;;
        esac
        i=$((i + 1))
    done
    
    echo "开始部署流程..."
    echo ""
    
    echo "步骤 1: 检测 IP 地址"
    detected_ip=$(detect_ip)
    
    if [ -z "$detected_ip" ]; then
        echo "错误: IP 检测失败"
        exit 1
    fi
    
    if [ -n "$ip_address" ]; then
        echo "使用指定的 IP 地址: $ip_address"
        detected_ip="$ip_address"
    fi
    
    echo ""
    echo "步骤 2: 更新配置文件"
    if ! update_config "$detected_ip" "$CONFIG_FILE" "server_url"; then
        exit 1
    fi
    if ! update_config "$detected_ip" "$CONFIG_FILE" "listen_addr"; then
        exit 1
    fi
    if ! update_derp_config "$detected_ip" "$DERP_FILE"; then
        exit 1
    fi
    
    echo ""
    echo "步骤 3: 检查 Docker 环境"
    check_docker
    check_docker_compose
    create_directories
    
    echo ""
    echo "步骤 4: 构建镜像"
    build_image
    
    echo ""
    echo "步骤 5: 停止现有容器"
    stop_existing_container
    
    echo ""
    echo "步骤 6: 启动 Headscale 服务"
    start_service
    
    echo ""
    echo "步骤 7: 验证服务状态"
    check_service_status
    
    echo ""
    echo "=========================================="
    echo "部署完成！"
    echo "=========================================="
    echo ""
    echo "配置信息:"
    echo "  IP 地址: $detected_ip"
    echo "  配置文件: $CONFIG_FILE"
    echo "  DERP 配置: $DERP_FILE"
    echo ""
    echo "查看日志:"
    echo "  docker logs -f headscale"
    echo ""
    echo "查看状态:"
    echo "  docker-compose ps"
    echo ""
}

check_root
main "$@"

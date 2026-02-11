#!/usr/bin/env bash

set -Eeuo pipefail

########################################
# 全局只读变量
########################################
readonly WORKDIR="/opt/frp"
readonly LOG_PREFIX="[FRP-PROD]"
readonly COMPOSE_FILE="$WORKDIR/docker-compose.yml"

########################################
# 日志函数
########################################
log_info() {
    echo -e "\033[32m$LOG_PREFIX [INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[33m$LOG_PREFIX [WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[31m$LOG_PREFIX [ERROR]\033[0m $1"
}

########################################
# 错误捕获
########################################
trap 'log_error "脚本异常退出，行号: $LINENO"' ERR

########################################
# 生成随机密钥
########################################
FRP_TOKEN=$(openssl rand -hex 24)
DASH_PASS=$(openssl rand -base64 12)

########################################
# 检查 root
########################################
if [[ $EUID -ne 0 ]]; then
   log_error "请使用 root 运行"
   exit 1
fi

########################################
# 安装依赖
########################################
install_base() {
    log_info "安装基础依赖"
    apt install -y \
        docker.io docker-compose \
        curl wget openssl ufw fail2ban
}

########################################
# 启动 Docker
########################################
setup_docker() {
    log_info "启动 Docker"
    systemctl enable docker
    systemctl start docker
}

########################################
# 防火墙
########################################
setup_firewall() {
    log_info "配置防火墙"
    ufw allow 22/tcp || true
    ufw allow 80/tcp || true
    ufw allow 443/tcp || true
    ufw allow 7000/tcp || true
    ufw allow 7500/tcp || true
    ufw --force enable
}

########################################
# fail2ban
########################################
setup_fail2ban() {
    log_info "启动 fail2ban"
    systemctl enable fail2ban
    systemctl restart fail2ban
}

########################################
# 创建目录
########################################
create_dirs() {
    log_info "创建目录结构"
    mkdir -p "$WORKDIR/frps"
    mkdir -p "$WORKDIR/nginx"
    mkdir -p "$WORKDIR/logs"
}

########################################
# 写 frps 配置
########################################
write_frps_config() {

cat > "$WORKDIR/frps/frps.toml" <<EOF
bindPort = 7000

auth.method = "token"
auth.token = "$FRP_TOKEN"

webServer.port = 7500
webServer.addr = "0.0.0.0"
webServer.user = "admin"
webServer.password = "$DASH_PASS"

log.to = "/var/log/frp/frps.log"
log.level = "info"
EOF

}

########################################
# 写 nginx 配置
########################################
write_nginx_config() {

cat > "$WORKDIR/nginx/nginx.conf" <<EOF
events {}

http {
    server {
        listen 80;
        location / {
            return 200 'FRP Enterprise Running';
        }
    }
}
EOF

}

########################################
# 写 compose
########################################
write_compose() {

cat > "$COMPOSE_FILE" <<EOF
version: "3.3"

services:

  frps:
    image: snowdreamtech/frps
    container_name: frps
    restart: always
    volumes:
      - $WORKDIR/frps/frps.toml:/etc/frp/frps.toml
      - $WORKDIR/logs:/var/log/frp
    ports:
      - "7000:7000"
      - "7500:7500"

  nginx:
    image: nginx:stable
    container_name: frp-nginx
    restart: always
    volumes:
      - $WORKDIR/nginx/nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "80:80"
EOF

}

########################################
# 自动识别 compose
########################################
compose_up() {

    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        log_info "使用 docker compose"
        docker compose -f "$COMPOSE_FILE" up -d
    else
        log_info "使用 docker-compose"
        docker-compose -f "$COMPOSE_FILE" up -d
    fi
}

########################################
# 健康检查
########################################
health_check() {

    sleep 5

    if docker ps | grep frps &>/dev/null; then
        log_info "FRPS 运行正常"
    else
        log_error "FRPS 未启动"
        exit 1
    fi
}

########################################
# 主流程
########################################
main() {

    install_base
    setup_docker
    setup_firewall
    setup_fail2ban
    create_dirs
    write_frps_config
    write_nginx_config
    write_compose
    compose_up
    health_check

    IP=$(curl -s ifconfig.me || echo "请手动查询")

    log_info "部署完成"
    echo ""
    echo "FRP Token: $FRP_TOKEN"
    echo "Dashboard: http://$IP:7500"
    echo "User: admin"
    echo "Pass: $DASH_PASS"
    echo "FRPS: $IP:7000"
}

main


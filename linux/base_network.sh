#!/usr/bin/env bash

set -Eeuo pipefail

########################################
# 全局只读变量
########################################
readonly LOG_PREFIX="[BASE-NETWORK]"

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
# 检查 root
########################################
if [[ $EUID -ne 0 ]]; then
   log_error "请使用 root 运行"
   exit 1
fi

########################################
# 检查并安装包
########################################
check_and_install() {
    local pkg="$1"
    if dpkg -l | grep -q "^ii  $pkg"; then
        log_info "$pkg 已安装"
    else
        log_info "正在安装 $pkg"
        apt install -y "$pkg"
    fi
}

########################################
# 安装依赖
########################################
install_packages() {
    log_info "更新软件包列表"
    apt update

    check_and_install "ufw"
    check_and_install "fail2ban"
}

########################################
# 配置并启动 UFW
########################################
setup_ufw() {
    log_info "配置 UFW 防火墙"
    ufw status
    systemctl status status
}

########################################
# 配置并启动 fail2ban
########################################
setup_fail2ban() {
    log_info "启动 fail2ban"

    systemctl enable fail2ban
    systemctl restart fail2ban

    log_info "fail2ban 状态:"
    systemctl status fail2ban --no-pager
}

########################################
# 主流程
########################################
main() {
    install_packages
    setup_ufw
    setup_fail2ban

    log_info "网络基础服务配置完成"
}

main

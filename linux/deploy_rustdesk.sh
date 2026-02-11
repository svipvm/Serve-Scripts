#!/bin/bash
# 一键部署 RustDesk Server (hbb-server) 脚本
# 适用于 Ubuntu/Debian
# 支持 Docker + Docker Compose + 可选 TLS (Let's Encrypt)

set -e

# ====== 配置区 ======
HBBS_PORT=21115
HBBS_RELAY_PORT=21116
HBBR_PORT=21117
DATA_DIR="/opt/rustdesk-server"

# ====== 安装 Docker 和 Docker Compose ======
if ! command -v docker &> /dev/null; then
    echo "安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
fi

if ! command -v docker-compose &> /dev/null; then
    echo "安装 Docker Compose..."
    sudo apt install -y docker-compose
fi

# ====== 创建数据目录 ======
echo "创建数据目录 $DATA_DIR ..."
mkdir -p $DATA_DIR
echo "创建 docker-compose.yml ..."

cat > $DATA_DIR/docker-compose.yml << EOF
version: '3.3'

services:
  hbbs:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbs
    restart: always
    command: hbbs
    network_mode: "host"
    depends_on:
      - hbbr
    volumes:
      - ./data/hbbs:/root

  hbbr:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbr
    restart: always
    command: hbbr
    network_mode: "host"
    volumes:
      - ./data/hbbr:/root
EOF

# ====== 启动服务 ======
echo "启动 RustDesk Server ..."
cd $DATA_DIR
docker-compose up -d

# 允许 RustDesk 所需端口
ufw allow 21114/tcp
ufw allow 21115/tcp
ufw allow 21116/tcp
ufw allow 21116/udp
ufw allow 21117/tcp
ufw allow 21118/tcp
ufw allow 21119/tcp

echo "======================================"
echo "RustDesk Server 已部署完成！"
echo "Docker 容器状态："
docker ps | grep hbbs
docker ps | grep hbbr
echo "======================================"


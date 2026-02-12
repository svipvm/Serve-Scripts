# Headscale Docker 部署

## 项目结构

```
headscale/
├── Dockerfile              # Docker 镜像构建文件
├── docker-compose.yml      # Docker Compose 配置文件
├── config/
│   └── config.yaml         # Headscale 配置文件
├── package/
│   └── headscale_0.28.0_linux_amd64.deb  # Headscale 安装包
├── start.sh                # 一键启动脚本
├── stop.sh                 # 停止服务脚本
└── restart.sh              # 重启服务脚本

/opt/headscale/             # 数据持久化目录（自动创建）
├── data/                   # 数据目录
└── run/                    # 运行时目录
```

## 前置要求

- Docker (20.10 或更高版本)
- Docker Compose (2.0 或更高版本)

## 快速开始

### 一键启动

```bash
cd /root/Serve-Scripts/linux/headscale
chmod +x *.sh
./start.sh
```

启动脚本会自动完成以下操作：
1. 检查 Docker 和 Docker Compose 是否安装
2. 创建必要的目录结构
3. 构建 Headscale Docker 镜像
4. 启动 Headscale 服务
5. 检查服务状态

### 手动部署

如果需要手动部署，请按以下步骤操作：

1. 创建数据目录：
```bash
mkdir -p /opt/headscale/data /opt/headscale/run
chmod 770 /opt/headscale/run
```

2. 构建镜像：
```bash
docker compose build
```

3. 启动服务：
```bash
docker compose up -d
```

## 服务管理

### 查看服务状态
```bash
docker compose ps
```

### 查看日志
```bash
docker compose logs -f
```

### 停止服务
```bash
./stop.sh
# 或
docker compose down
```

### 重启服务
```bash
./restart.sh
# 或
docker compose restart
```

### 进入容器
```bash
docker compose exec headscale bash
```

## 服务端口

- **8080**: HTTP API 服务
- **9090**: Metrics 监控接口
- **50443**: gRPC 管理接口

## 配置说明

配置文件位于 `config/config.yaml`，主要配置项包括：

- `server_url`: 客户端连接的服务器地址
- `listen_addr`: 服务监听地址
- `prefixes`: IP 地址分配范围
- `derp`: DERP 中继服务器配置
- `dns`: DNS 配置

## 数据持久化

以下目录会被挂载到容器中，确保数据持久化：

- `/opt/headscale/data` → `/var/lib/headscale`: 存储数据库、密钥等数据
- `/opt/headscale/run` → `/var/run/headscale`: 存储 Unix socket 文件

## 健康检查

服务配置了健康检查，每 30 秒检查一次服务状态：
```bash
docker inspect headscale | grep -A 10 Health
```

## 故障排查

### 服务无法启动
1. 检查端口是否被占用：
```bash
netstat -tlnp | grep -E '8080|9090|50443'
```

2. 查看详细日志：
```bash
docker compose logs
```

### 配置修改后生效
修改 `config/config.yaml` 后，需要重启服务：
```bash
./restart.sh
```

### 清理所有数据
```bash
docker compose down -v
rm -rf /opt/headscale/*
```

## 注册客户端

服务启动后，可以使用以下命令注册第一个客户端：

1. 创建 API Key：
```bash
docker compose exec headscale headscale apikeys create
```

2. 在客户端使用 tailscale 命令连接：
```bash
tailscale up --login-server=http://YOUR_SERVER_IP:8080
```

## 版本信息

- Headscale 版本: 0.28.0
- 基础镜像: debian:12
- 安装方式: 本地 DEB 包安装
- APT 镜像源: 清华大学镜像源（加速下载）

如需修改版本，请将新的 DEB 包放置到 `package/` 目录，并更新 Dockerfile 中的包文件名。

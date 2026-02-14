# RustDesk Server

RustDesk 远程桌面服务器的 Docker 部署方案。

## 项目结构

```
rustdesk/
├── config/              # 配置说明文档
├── .env.example        # 环境变量模板
├── .gitignore          # Git 忽略规则
├── docker-compose.yml  # Docker Compose 配置
├── start.sh            # 启动脚本
├── stop.sh             # 停止脚本
└── README.md           # 项目说明

数据目录 (挂载到 /opt):
/opt/rustdesk-server/
├── hbbs/               # hbbs 服务数据 (含密钥)
├── hbbr/               # hbbr 服务数据
└── public_key.txt      # 公钥文件 (启动时自动生成)
```

## 服务组件

| 服务 | 说明 |
|------|------|
| hbbs | RustDesk ID/中继服务器，负责 ID 注册和心跳 |
| hbbr | RustDesk 中继服务器，负责远程连接中继 |

## 端口说明

| 端口 | 协议 | 用途 |
|------|------|------|
| 21114 | TCP | Web 管理端 (可选) |
| 21115 | TCP | NAT 类型测试 |
| 21116 | TCP/UDP | ID 注册/心跳 |
| 21117 | TCP | 中继服务 |
| 21118 | TCP | Web 客户端 (可选) |
| 21119 | TCP | Web 客户端 (可选) |

## 云服务器端口配置

在云服务器上部署时，需要在安全组/防火墙中开放以下端口：

### 必须开放的端口

| 端口 | 协议 | 说明 |
|------|------|------|
| 21115 | TCP | hbbs 主端口，客户端连接必需 |
| 21116 | TCP | ID 注册/心跳 |
| 21116 | UDP | ID 注册/心跳 (必须同时开放 TCP 和 UDP) |
| 21117 | TCP | hbbr 中继端口，远程连接必需 |

### 可选端口

| 端口 | 协议 | 说明 |
|------|------|------|
| 21114 | TCP | Web 管理端 |
| 21118 | TCP | Web 客户端 |
| 21119 | TCP | Web 客户端 |

### 各云平台配置示例

**阿里云/腾讯云安全组规则：**

| 方向 | 协议 | 端口范围 | 来源 | 说明 |
|------|------|----------|------|------|
| 入方向 | TCP | 21115 | 0.0.0.0/0 | hbbs 主端口 |
| 入方向 | TCP | 21116 | 0.0.0.0/0 | ID 注册 |
| 入方向 | UDP | 21116 | 0.0.0.0/0 | ID 注册 |
| 入方向 | TCP | 21117 | 0.0.0.0/0 | 中继服务 |

> 注意：21116 端口必须同时开放 TCP 和 UDP 协议，否则客户端无法正常注册和连接。

## 快速开始

### 1. 环境准备

确保已安装 Docker 和 Docker Compose：

```bash
# 检查 Docker
docker --version

# 检查 Docker Compose
docker compose version
```

### 2. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 根据需要修改配置
vim .env
```

### 3. 启动服务

```bash
# 添加执行权限
chmod +x start.sh stop.sh

# 启动服务
./start.sh
```

### 4. 获取公钥

启动后，公钥会自动生成并显示，同时保存到 `/opt/rustdesk-server/public_key.txt` 文件中。

也可以手动查看：

```bash
cat /opt/rustdesk-server/public_key.txt
# 或
cat /opt/rustdesk-server/hbbs/id_ed25519.pub
```

### 5. 客户端配置

在 RustDesk 客户端中设置：

1. 打开设置 → 网络 → ID/中继服务器
2. 填写服务器 IP 地址
3. 填写公钥内容
4. 点击应用

## 常用命令

```bash
# 启动服务
./start.sh

# 停止服务
./stop.sh

# 停止并清理数据
./stop.sh --clean

# 查看日志
docker logs hbbs
docker logs hbbr

# 查看状态
docker ps --filter "name=hbbs" --filter "name=hbbr"
```

## 配置选项

编辑 `.env` 文件修改配置：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `HBBS_PORT` | 21115 | hbbs 主端口 |
| `HBBS_NAT_PORT` | 21116 | NAT 类型测试端口 |
| `HBBR_PORT` | 21117 | hbbr 中继端口 |
| `KEY_FILE` | id_ed25519 | 密钥文件名 |
| `RELAY_SERVER` | - | 外部中继服务器地址 |
| `DATA_DIR` | /opt/rustdesk-server | 数据存储目录 |
| `RUSTDESK_IMAGE` | rustdesk/rustdesk-server:latest | Docker 镜像 |

## 故障排除

### 客户端无法连接

1. 检查防火墙是否开放端口
2. 确认服务器 IP 地址正确
3. 确认公钥配置正确

### 服务启动失败

```bash
# 查看容器日志
docker logs hbbs
docker logs hbbr

# 检查端口占用
netstat -tlnp | grep -E '2111[5-7]'

# 重新创建容器
docker compose down
docker compose up -d
```

### 密钥问题

```bash
# 删除旧密钥重新生成
sudo rm -f /opt/rustdesk-server/hbbs/id_ed25519*
./stop.sh
./start.sh
```

## 参考资料

- [RustDesk 官方文档](https://rustdesk.com/docs/)
- [RustDesk GitHub](https://github.com/rustdesk/rustdesk)
- [RustDesk Server GitHub](https://github.com/rustdesk/rustdesk-server)

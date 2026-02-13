# Headscale 服务

Headscale 是一个开源的 Tailscale 控制服务器实现，允许您自建 Tailscale 控制服务器，无需依赖官方的 Tailscale 服务。

## 什么是 Headscale？

Headscale 是 Tailscale 控制服务器的开源替代方案，它提供了以下功能：

- 自建 Tailscale 控制服务器
- 完全控制您的设备和网络
- 无需依赖官方 Tailscale 服务
- 支持 DERP 中继服务器
- 支持用户和设备管理
- 兼容 Tailscale 客户端

## 服务架构

本部署使用 Docker Compose 来管理 Headscale 服务，包含以下组件：

```
┌─────────────────────────────────────┐
│         Headscale 服务             │
│  ┌─────────────────────────────┐  │
│  │   Headscale 容器          │  │
│  │   - HTTP API (8080)       │  │
│  │   - Debug API (9090)      │  │
│  │   - DERP Server (8080)    │  │
│  │   - STUN Server (3478)     │  │
│  └─────────────────────────────┘  │
└─────────────────────────────────────┘
```

## 功能特性

### 核心功能
- ✅ 自建 Tailscale 控制服务器
- ✅ 用户和设备管理
- ✅ 内置 DERP 中继服务器
- ✅ 内置 STUN 服务器
- ✅ HTTP API 接口
- ✅ Debug 和 Metrics 接口
- ✅ 路由和出口节点支持

### 部署特性
- ✅ Docker Compose 部署
- ✅ 自适应 IP 检测
- ✅ 自动配置更新
- ✅ 配置文件自动备份
- ✅ 支持本地和云服务器环境

## 快速开始

### 环境要求

- Docker 20.10+
- Docker Compose 1.29+
- Python 3.x（用于部署脚本）
- sudo 权限

### 一键部署

使用自适应部署脚本自动部署：

```bash
# 本地环境部署（自动检测 IP）
sudo ./start.sh
```

### 手动部署

如果需要手动部署：

```bash
# 1. 克隆或下载项目
cd linux/headscale

# 2. 修改配置文件
vim config/config.yaml
vim config/derp.yaml

# 3. 启动服务
sudo docker-compose up -d

# 4. 查看服务状态
sudo docker-compose ps
```

## 配置说明

### 主配置文件 (config/config.yaml)

主要配置项：

```yaml
# 服务器 URL（客户端连接地址）
server_url: http://YOUR_IP:8080

# 监听地址
listen_addr: 0.0.0.0:8080

# DERP 服务器配置
derp:
  server:
    enabled: true
    region_id: 999
    region_code: "headscale"
    region_name: "Headscale Embedded"
```

### DERP 配置文件 (config/derp.yaml)

DERP 中继服务器配置：

```yaml
regions:
  900:
    regionid: 900
    regioncode: "headscale"
    regionname: "Headscale Embedded"
    nodes:
      - name: "headscale-embedded"
        regionid: 900
        hostname: "YOUR_IP"
        stunport: 3478
        derpport: 8080
        ipv4: "YOUR_IP"
```

## 使用指南

### 创建用户

```bash
# 创建新用户
sudo docker exec headscale headscale users create user1

# 列出所有用户
sudo docker exec headscale headscale users list
```

### 连接客户端

#### Linux 客户端

```bash
# 安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 连接到 Headscale 服务器
sudo tailscale up --login-server=http://YOUR_IP:8080 --auth-key=YOUR_AUTH_KEY
```

#### Docker 客户端

```bash
# 使用 Docker 运行 Tailscale 客户端
sudo docker-compose -f docker-compose.tailscale.yml up -d
```

### 管理节点

```bash
# 列出所有节点
sudo docker exec headscale headscale nodes list

# 删除节点
sudo docker exec headscale headscale nodes delete <node-id>

# 重命名节点
sudo docker exec headscale headscale nodes rename <node-id> <new-name>
```

### 生成认证密钥

```bash
# 生成临时认证密钥（24小时有效）
sudo docker exec headscale headscale preauthkeys create -e 24h

# 列出所有认证密钥
sudo docker exec headscale headscale preauthkeys list

# 删除认证密钥
sudo docker exec headscale headscale preauthkeys delete <key-id>
```

## 服务管理

### 查看服务状态

```bash
# 查看容器状态
sudo docker-compose ps

# 查看服务日志
sudo docker logs -f headscale

# 查看实时日志
sudo docker-compose logs -f
```

### 重启服务

```bash
# 重启 Headscale 服务
sudo docker-compose restart

# 停止服务
sudo docker-compose down

# 启动服务
sudo docker-compose up -d
```

### 更新服务

```bash
# 重新构建并启动
sudo docker-compose up -d --build

# 拉取最新镜像
sudo docker-compose pull
sudo docker-compose up -d
```

## 端口说明

| 端口 | 协议 | 用途 |
|------|------|------|
| 8080 | TCP | Headscale HTTP API 和 DERP 服务器 |
| 9090 | TCP | Debug 和 Metrics 接口 |
| 3478 | UDP | STUN 服务器 |
| 50443 | TCP | 备用端口 |

## 数据持久化

服务使用以下目录进行数据持久化：

- `/opt/headscale/data`：Headscale 数据目录
- `/opt/headscale/run`：Headscale 运行时目录

## 故障排除

### 服务无法启动

```bash
# 检查端口占用
sudo netstat -tunlp | grep -E "8080|9090|3478"

# 查看容器日志
sudo docker logs headscale

# 检查 Docker 服务状态
sudo systemctl status docker
```

### 客户端无法连接

```bash
# 检查防火墙设置
sudo ufw status

# 开放必要端口
sudo ufw allow 8080/tcp
sudo ufw allow 3478/udp

# 检查 Headscale 服务状态
sudo docker exec headscale headscale status
```

### DERP 中继不工作

```bash
# 检查 DERP 配置
sudo docker exec headscale headscale derp check

# 查看 DERP 服务器日志
sudo docker logs headscale | grep -i derp
```

## 安全建议

1. **使用 HTTPS**：在生产环境中，建议使用反向代理（如 Nginx）配置 HTTPS
2. **防火墙配置**：只开放必要的端口
3. **认证密钥管理**：定期轮换认证密钥
4. **访问控制**：配置适当的访问控制策略
5. **备份策略**：定期备份 `/opt/headscale/data` 目录

## 高级配置

### 配置反向代理

使用 Nginx 作为反向代理：

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 配置多个 DERP 节点

编辑 `config/derp.yaml` 添加更多 DERP 节点：

```yaml
regions:
  900:
    regionid: 900
    regioncode: "headscale"
    regionname: "Headscale Embedded"
    nodes:
      - name: "node1"
        regionid: 900
        hostname: "node1.example.com"
        stunport: 3478
        derpport: 8080
        ipv4: "1.2.3.4"
      - name: "node2"
        regionid: 900
        hostname: "node2.example.com"
        stunport: 3478
        derpport: 8080
        ipv4: "5.6.7.8"
```

## 相关资源

- [Headscale 官方文档](https://headscale.juanfont.net/)
- [Tailscale 官方文档](https://tailscale.com/kb/)
- [Headscale GitHub](https://github.com/juanfont/headscale)
- [Docker Hub](https://hub.docker.com/r/headscale/headscale)

## 许可证

本项目遵循 MIT 许可证。

## 支持

如有问题或建议，请：

1. 查看本文档的故障排除部分
2. 查看官方文档
3. 提交 Issue 或 Pull Request

## 更新日志

### v1.0.0
- 初始版本
- 支持 Docker Compose 部署
- 自适应部署脚本
- 内置 DERP 服务器
- 完整的文档

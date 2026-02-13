# Headscale 部署项目

Headscale 是一个开源的 Tailscale 控制服务器实现，本项目提供完整的 Docker 部署方案。

## 目录结构

```
headscale/
├── config/
│   ├── config.yaml      # 配置模板（不会被修改）
│   ├── derp.yaml        # 配置模板（不会被修改）
│   └── Caddyfile        # 配置模板（不会被修改）
├── package/
│   ├── headscale_0.26.1_linux_amd64.deb
│   └── headscale_0.26.1_linux_arm64.deb
├── .env.example         # 环境变量模板
├── .env                 # 环境变量配置（不提交到 git）
├── docker-compose.yml   # Docker Compose 配置
├── Dockerfile           # Headscale 镜像构建文件
├── start.sh             # 一键部署脚本
├── stop.sh              # 停止服务脚本
├── restart.sh           # 重启服务脚本
└── README.md            # 本文档
```

## 部署后目录结构

```
/opt/
├── headscale/
│   ├── config/
│   │   ├── config.yaml  # 实际使用的配置
│   │   └── derp.yaml    # 实际使用的配置
│   ├── data/            # 数据库
│   └── run/             # 运行时文件
└── caddy/
    ├── config/
    │   └── Caddyfile    # 实际使用的配置
    └── data/            # Caddy 数据
```

## 完整使用流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        部署 Headscale                            │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     创建用户 (users create)                      │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
┌───────────────────────────┐   ┌───────────────────────────┐
│   创建 API Key             │   │   创建 PreAuth Key         │
│   (用于 UI 登录)           │   │   (用于客户端注册)         │
└───────────────────────────┘   └───────────────────────────┘
                    │                       │
                    ▼                       ▼
┌───────────────────────────┐   ┌───────────────────────────┐
│   访问 UI 管理界面         │   │   客户端注册到网络         │
│   (输入 API Key 登录)      │   │   (tailscale up)          │
└───────────────────────────┘   └───────────────────────────┘
```

---

## 一、部署服务

### 1. 环境准备

```bash
# 克隆仓库
git clone <repo-url>
cd Serve-Scripts/linux/headscale

# 复制配置文件
cp .env.example .env

# 编辑配置，设置 SERVER_HOST（必填）
vi .env
```

### 2. 配置说明

编辑 `.env` 文件，**必须设置 `SERVER_HOST`**：

```bash
# 服务器公网 IP 或域名（必填）
SERVER_HOST=your-server-ip-or-domain
```

### 3. 一键部署

```bash
sudo ./start.sh
```

脚本会自动：
1. 从 `.env` 读取 `SERVER_HOST`
2. 生成配置文件到 `/opt` 目录
3. 创建数据目录
4. 构建并启动服务

### 4. 访问服务

| 服务 | 地址 | 说明 |
|------|------|------|
| Headscale UI | `http://SERVER_IP:8008/web/` | 需要认证 |
| Headscale API | `http://SERVER_IP:8081` | 需要 API Key |
| Headscale 服务 | `http://SERVER_IP:8080` | 客户端连接 |

---

## 二、创建用户

Headscale 需要先创建用户，客户端归属于用户。

```bash
# 创建用户
sudo docker exec headscale headscale users create <用户名>

# 查看用户列表
sudo docker exec headscale headscale users list

# 示例
sudo docker exec headscale headscale users create mynetwork
```

**输出示例：**
```
User created:
ID: 1
Name: mynetwork
```

---

## 三、创建 API Key（用于 UI 登录）

API Key 用于 headscale-ui 登录和 API 调用。

```bash
# 创建长期有效的 API Key（10 年）
sudo docker exec headscale headscale apikeys create --expiration 87600h

# 查看所有 API Key
sudo docker exec headscale headscale apikeys list
```

**输出示例：**
```
GoUQsq_.EyXHXFzlkHckX3rTlqHU4OjuyBYywI1y
```

⚠️ **Key 只在创建时显示一次，请立即保存！**

### UI 登录步骤

1. 访问 `http://SERVER_IP:8008/web/`
2. 输入 Basic Auth 用户名密码（默认：admin / headscale）
3. 在 UI 中输入服务器地址：`http://SERVER_IP:8081`
4. 输入 API Key 完成登录

---

## 四、创建 PreAuth Key（用于客户端注册）

PreAuth Key 用于 Tailscale 客户端注册到 Headscale。

```bash
# 创建长期有效的 PreAuth Key（1 年，可重复使用）
sudo docker exec headscale headscale preauthkeys create --user <用户ID> --reusable --expiration 8760h

# 查看所有 PreAuth Key
sudo docker exec headscale headscale preauthkeys list --user <用户ID>

# 示例（用户 ID 为 1）
sudo docker exec headscale headscale preauthkeys create --user 1 --reusable --expiration 8760h
```

**输出示例：**
```
b0ec51f9dde9ef4a86a306a746e4f8d32e1c6d728fac0f37
```

⚠️ **Key 只在创建时显示一次，请立即保存！**

---

## 五、客户端注册

### Linux/macOS

```bash
# 安装 Tailscale 客户端
curl -fsSL https://tailscale.com/install.sh | sh

# 注册到 Headscale
sudo tailscale up --login-server=http://SERVER_IP:8080 --authkey=<PREAUTH_KEY>
```

### Windows

```powershell
# 下载安装 Tailscale 客户端后
tailscale up --login-server=http://SERVER_IP:8080 --authkey=<PREAUTH_KEY>
```

### 验证连接

```bash
# 查看连接状态
tailscale status

# 查看网络中的所有节点
sudo docker exec headscale headscale nodes list
```

---

## 六、日常管理

### 服务管理

```bash
# 启动服务
sudo ./start.sh

# 停止服务
sudo ./stop.sh

# 重启服务
sudo ./restart.sh

# 查看日志
sudo docker-compose logs -f headscale
```

### 节点管理

```bash
# 查看所有节点
sudo docker exec headscale headscale nodes list

# 删除节点
sudo docker exec headscale headscale nodes delete --id <节点ID>

# 使节点过期
sudo docker exec headscale headscale nodes expire --id <节点ID>
```

### Key 管理

```bash
# API Key
sudo docker exec headscale headscale apikeys list
sudo docker exec headscale headscale apikeys expire --prefix <前缀>

# PreAuth Key
sudo docker exec headscale headscale preauthkeys list --user <用户ID>
sudo docker exec headscale headscale preauthkeys expire --id <ID>
```

---

## 配置说明

### 环境变量 (.env)

```bash
# 服务器公网 IP 或域名（必填）
SERVER_HOST=your-server-ip-or-domain

# 端口配置
HEADSCALE_PORT=8080          # Headscale 主服务端口
HEADSCALE_STUN_PORT=3478     # STUN/DERP 端口
UI_HTTP_PORT=8008            # UI 访问端口
UI_API_PORT=8081             # API 代理端口

# UI 认证
UI_AUTH_USER=admin           # Basic Auth 用户名
UI_AUTH_PASSWORD=headscale   # Basic Auth 密码
```

### 端口说明

| 端口 | 服务 | 公网访问 | 说明 |
|------|------|----------|------|
| 8080 | Headscale | ✅ 是 | Tailscale 客户端连接 |
| 3478/udp | STUN/DERP | ✅ 是 | NAT 穿透 |
| 8008 | UI (Caddy) | ✅ 是 | 管理界面（Basic Auth） |
| 8081 | API (Caddy) | ✅ 是 | API 代理（API Key） |
| 9090 | Metrics | ❌ 否 | 监控指标（仅内网） |
| 50443 | gRPC | ❌ 否 | 远程控制（仅内网） |

### DERP 服务器

本项目默认启用嵌入式 DERP 服务器：

- **状态**: 已启用
- **STUN 端口**: 3478/udp
- **功能**: NAT 穿透，帮助客户端建立直连

---

## Key 有效期参考

| 时间 | 参数值 |
|------|--------|
| 1 小时 | `1h` |
| 1 天 | `24h` |
| 90 天 | `90d` |
| 1 年 | `8760h` |
| 10 年 | `87600h` |

---

## 安全建议

1. **修改默认密码**：修改 `.env` 中的 `UI_AUTH_PASSWORD`
2. **使用 HTTPS**：生产环境建议配置域名和 SSL 证书
3. **防火墙配置**：仅开放必要端口
4. **定期备份**：备份 `/opt/headscale/data/` 目录
5. **定期轮换 Key**：建议每年更换 API Key

---

## 故障排查

### 查看日志

```bash
sudo docker logs headscale
sudo docker logs caddy
```

### 常见问题

1. **UI 无法访问**
   - 检查 Caddy 容器是否正常运行
   - 检查防火墙是否开放 8008 端口

2. **客户端无法连接**
   - 检查 8080 和 3478/udp 端口是否开放
   - 检查 PreAuth Key 是否有效
   - 检查 DERP 服务器是否启用

3. **API 调用返回 401**
   - 检查 API Key 是否正确
   - 检查 API Key 是否过期

---

## 版本信息

| 组件 | 版本 |
|------|------|
| Headscale | 0.26.1 |
| Headscale-UI | 2025.08.23 |
| Caddy | 2.10.2 |

## 参考资料

- [Headscale 官方文档](https://headscale.net/)
- [Headscale GitHub](https://github.com/juanfont/headscale)
- [Headscale-UI GitHub](https://github.com/gurucomputing/headscale-ui)
- [Tailscale 官方文档](https://tailscale.com/kb/)

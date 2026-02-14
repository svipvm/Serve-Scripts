# Headscale 部署项目

Headscale 是一个开源的 Tailscale 控制服务器实现，本项目提供完整的 Docker 部署方案，无需 Web UI，全部通过命令行管理。

## 目录结构

```
headscale/
├── config/
│   ├── config.yaml.template  # Headscale 配置模板
│   ├── derp.yaml.template    # DERP 配置模板
│   └── Caddyfile.template    # Caddy 配置模板
├── package/
│   ├── headscale_0.26.1_linux_amd64.deb
│   └── headscale_0.26.1_linux_arm64.deb
├── .env.example              # 环境变量模板
├── .env                      # 环境变量配置（不提交到 git）
├── docker-compose.yml        # Docker Compose 配置
├── Dockerfile                # Headscale 镜像构建文件
├── start.sh                  # 一键部署脚本
├── stop.sh                   # 停止服务脚本
├── restart.sh                # 重启服务脚本
└── README.md                 # 本文档
```

## 部署后目录结构

```
/opt/
├── headscale/
│   ├── config/
│   │   ├── config.yaml      # 实际使用的配置
│   │   ├── derp.yaml        # DERP 配置
│   │   ├── tls.crt          # TLS 证书
│   │   └── tls.key          # TLS 私钥
│   ├── data/                # 数据库
│   └── run/                 # 运行时文件
└── caddy/
    ├── config/
    │   └── Caddyfile        # Caddy 配置
    └── data/                # Caddy 数据
```

## 完整使用流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        部署 Headscale                            │
│                    sudo ./start.sh                               │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     创建用户                                     │
│          sudo docker exec headscale headscale users create       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     创建预授权密钥                               │
│       sudo docker exec headscale headscale preauthkeys create    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     客户端注册到网络                             │
│       tailscale up --login-server=https://IP:8080 --authkey=     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 一、端口说明

### 必需开放的端口（云服务器安全组）

| 端口 | 协议 | 说明 | 必需 |
|------|------|------|------|
| **8080** | TCP | **Headscale HTTPS 服务** | ✅ **必须** |
| **3478** | UDP | **STUN/DERP 服务** | ✅ **必须** |

### 可选端口

| 端口 | 协议 | 说明 | 必需 |
|------|------|------|------|
| 80 | TCP | HTTP 服务（可选） | ❌ 可选 |
| 9090 | TCP | Metrics 监控 | ❌ 可选 |
| 50443 | TCP | gRPC 远程控制 | ❌ 可选 |

**注意：**
- 8080 端口被 Caddy 占用提供 HTTPS 服务
- Headscale 内部使用 8081 端口（不暴露到宿主机）
- **Windows 客户端** 首次连接需手动信任自签名证书

---

## 二、部署服务

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

### 3. 云服务器安全组配置

在阿里云/腾讯云/AWS 控制台添加安全组规则：

| 端口 | 协议 | 授权对象 | 说明 |
|------|------|----------|------|
| 8080 | TCP | 0.0.0.0/0 | Headscale HTTPS 服务 |
| 3478 | UDP | 0.0.0.0/0 | STUN/DERP NAT 穿透 |
| 9090 | TCP | 0.0.0.0/0 | Metrics（可选） |

### 4. 一键部署

```bash
sudo ./start.sh
```

脚本会自动：
1. 生成自签名 TLS 证书（有效期10年）
2. 生成配置文件到 `/opt` 目录
3. 创建数据目录
4. 配置防火墙规则
5. 构建并启动服务

### 5. 访问服务

| 服务 | 地址 | 说明 |
|------|------|------|
| Headscale HTTPS | `https://SERVER_IP:8080` | **Tailscale 客户端连接** |
| Metrics | `http://SERVER_IP:9090/metrics` | 监控指标（可选） |

---

## 三、创建用户

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

## 四、创建预授权密钥（PreAuth Key）

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

# 注册到 Headscale（注意是 https://）
sudo tailscale up --login-server=https://SERVER_IP:8080 --authkey=<PREAUTH_KEY>
```

### Windows

```powershell
# 下载安装 Tailscale 客户端后
tailscale up --login-server=https://SERVER_IP:8080 --authkey=<PREAUTH_KEY>
```

**⚠️ Windows 首次连接注意：**
由于使用自签名证书，浏览器会提示不安全：
1. 先访问 `https://SERVER_IP:8080` 一次
2. 点击"高级" → "继续前往"（信任证书）
3. 再执行 `tailscale up` 命令

### 验证连接

```bash
# 查看连接状态
tailscale status

# 查看网络中的所有节点
sudo docker exec headscale headscale nodes list
```

---

## 六、日常管理命令

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

### 用户管理

```bash
# 查看所有用户
sudo docker exec headscale headscale users list

# 创建用户
sudo docker exec headscale headscale users create <用户名>

# 删除用户
sudo docker exec headscale headscale users delete --name <用户名>
```

### 节点（设备）管理

```bash
# 查看所有节点
sudo docker exec headscale headscale nodes list

# 删除节点
sudo docker exec headscale headscale nodes delete --id <节点ID>

# 使节点过期
sudo docker exec headscale headscale nodes expire --id <节点ID>

# 查看节点路由
sudo docker exec headscale headscale routes list

# 启用路由
sudo docker exec headscale headscale routes enable --id <路由ID>
```

### Key 管理

```bash
# PreAuth Key
sudo docker exec headscale headscale preauthkeys list --user <用户ID>
sudo docker exec headscale headscale preauthkeys expire --id <ID>

# API Key（用于第三方工具）
sudo docker exec headscale headscale apikeys create --expiration 87600h
sudo docker exec headscale headscale apikeys list
```

---

## 七、配置说明

### 环境变量 (.env)

```bash
# 服务器公网 IP 或域名（必填）
SERVER_HOST=your-server-ip-or-domain

# Headscale 服务端口（内部使用）
HEADSCALE_PORT=8080

# Caddy HTTPS 端口（外部暴露）
CADDY_HTTPS_PORT=8080

# DERP 配置
DERP_ENABLED=true
DERP_STUN_PORT=3478
```

### 网络架构

```
                    云服务器
                       │
        ┌──────────────┼──────────────┐
        │              │              │
       80/tcp       8080/tcp      3478/udp
     (HTTP)       (HTTPS)        (STUN)
        │              │              │
    ┌───▼───┐    ┌───▼───┐    ┌───▼────┐
    │ Caddy │───▶│Headscale│   │Headscale│
    │:80    │    │:8081   │    │:3478   │
    └───────┘    └────────┘    └────────┘
```

- **Caddy** (8080): 处理 HTTPS，反向代理到 Headscale 内部 8081 端口
- **Headscale** (8081): 内部服务端口，不暴露到宿主机
- **Headscale** (3478/udp): STUN/DERP 服务，用于 NAT 穿透

---

## 八、Key 有效期参考

| 时间 | 参数值 |
|------|--------|
| 1 小时 | `1h` |
| 1 天 | `24h` |
| 90 天 | `90d` |
| 1 年 | `8760h` |
| 10 年 | `87600h` |

---

## 九、安全建议

1. **防火墙配置**：仅开放 8080/tcp 和 3478/udp
2. **定期备份**：备份 `/opt/headscale/data/` 目录
3. **定期轮换 Key**：建议每年更换 PreAuth Key
4. **证书信任**：Windows 客户端需手动信任自签名证书

---

## 十、故障排查

### 查看日志

```bash
# Headscale 日志
sudo docker logs headscale

# Caddy 日志
sudo docker logs caddy

# 实时日志
sudo docker-compose logs -f
```

### 常见问题

1. **客户端无法连接 8080**
   - 检查云服务器安全组是否开放 8080/tcp
   - 检查 UFW 防火墙: `sudo ufw status`
   - 测试端口连通性: `telnet SERVER_IP 8080`

2. **Windows 客户端证书错误**
   - 先访问 `https://SERVER_IP:8080` 信任证书
   - 或导入 `/opt/headscale/config/tls.crt` 到受信任的根证书

3. **客户端显示连接但无法通信**
   - 检查 3478/udp 是否开放（NAT 穿透必需）
   - 检查 DERP 是否启用: `sudo docker exec headscale headscale routes list`

4. **PreAuth Key 无效**
   - 检查 Key 是否过期: `sudo docker exec headscale headscale preauthkeys list`
   - 重新创建 Key 并确保 `--user` 参数正确

---

## 版本信息

| 组件 | 版本 |
|------|------|
| Headscale | 0.26.1 |
| Caddy | 2.10.2 |

## 参考资料

- [Headscale 官方文档](https://headscale.net/)
- [Headscale GitHub](https://github.com/juanfont/headscale)
- [Tailscale 官方文档](https://tailscale.com/kb/)

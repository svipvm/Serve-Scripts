# RustDesk Server 配置说明

## 端口配置

RustDesk Server 需要以下端口：

| 端口 | 协议 | 服务 | 说明 |
|------|------|------|------|
| 21114 | TCP | hbbs | Web 管理端 (可选) |
| 21115 | TCP | hbbs | NAT 类型测试 |
| 21116 | TCP | hbbs | ID 注册/心跳 |
| 21116 | UDP | hbbs | ID 注册/心跳 |
| 21117 | TCP | hbbr | 中继服务 |
| 21118 | TCP | hbbs | Web 客户端 (可选) |
| 21119 | TCP | hbbr | Web 客户端 (可选) |

## 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `HBBS_PORT` | 21115 | hbbs 主端口 |
| `HBBS_NAT_PORT` | 21116 | NAT 类型测试端口 |
| `HBBR_PORT` | 21117 | hbbr 中继端口 |
| `KEY_FILE` | id_ed25519 | 密钥文件名 |
| `RELAY_SERVER` | - | 中继服务器地址 |

## 密钥配置

RustDesk 使用公钥/私钥对进行加密通信。首次启动时会自动生成密钥对：

- 私钥: `/opt/rustdesk-server/hbbs/id_ed25519`
- 公钥: `/opt/rustdesk-server/hbbs/id_ed25519.pub`

客户端连接时需要提供公钥内容。

## 自定义密钥

如需使用自定义密钥，将密钥文件放入 `/opt/rustdesk-server/hbbs/` 目录：

```bash
# 生成密钥对
openssl genpkey -algorithm ED25519 -out id_ed25519
openssl pkey -in id_ed25519 -pubout -out id_ed25519.pub

# 复制到数据目录
sudo cp id_ed25519* /opt/rustdesk-server/hbbs/
```

## 网络模式

默认使用 `host` 网络模式，确保端口直接映射到主机。

如需使用 bridge 模式，修改 docker-compose.yml 中的 `network_mode` 并添加 `ports` 映射。

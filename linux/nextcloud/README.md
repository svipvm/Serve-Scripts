# NextCloud Docker 部署

基于 Docker Compose 的 NextCloud 私有云存储部署方案。

## 项目结构

```
nextcloud/
├── .env                    # 环境变量配置文件
├── .env.example            # 环境变量示例文件
├── docker-compose.yml      # Docker Compose 服务编排
├── start.sh               # 启动脚本
├── stop.sh                # 停止脚本
├── config/
│   └── config.php.template # NextCloud 配置模板
└── README.md              # 说明文档
```

## 快速开始

### 1. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，修改必要的配置参数
```

### 2. 启动服务

```bash
sudo ./start.sh
```

### 3. 访问服务

浏览器访问 `http://<服务器IP>:8080`，首次访问时创建管理员账号。

### 4. 停止服务

```bash
sudo ./stop.sh
```

## 环境变量说明

| 变量 | 默认值 | 说明 |
|------|--------|------|
| **NextCloud 配置** |||
| `NEXTCLOUD_PORT` | `8080` | NextCloud Web 访问端口 |
| `NEXTCLOUD_TRUSTED_DOMAIN` | `localhost` | 受信任的域名/IP，用于通过该域名访问 NextCloud |
| **数据库配置** |||
| `MYSQL_HOST` | `db` | MySQL 主机名（容器内使用服务名） |
| `MYSQL_PORT` | `3306` | MySQL 端口 |
| `MYSQL_DATABASE` | `nextcloud` | 数据库名称 |
| `MYSQL_USER` | `nextcloud` | 数据库用户名 |
| `MYSQL_PASSWORD` | `nextcloud123` | 数据库用户密码 **（建议修改）** |
| `MYSQL_ROOT_PASSWORD` | `root123` | 数据库 root 密码 **（建议修改）** |
| **Redis 配置** |||
| `REDIS_HOST` | `redis` | Redis 主机名（容器内使用服务名） |
| `REDIS_PORT` | `6379` | Redis 端口 |
| **存储配置** |||
| `DATA_DIR` | `/opt/nextcloud` | 宿主机数据存储目录 |

## 服务组件

| 服务 | 镜像 | 容器名 | IP 地址 |
|------|------|--------|---------|
| nextcloud | `nextcloud:latest` | nextcloud | 172.26.0.10 |
| db | `mariadb:latest` | nextcloud-db | 172.26.0.20 |
| redis | `redis:alpine` | nextcloud-redis | 172.26.0.30 |

## 数据目录

启动后将在 `DATA_DIR` 目录下创建以下子目录：

```
/opt/nextcloud/
├── data/          # 用户数据文件（独立挂载）
│   └── <用户名>/files/  # 用户上传的文件
├── mysql/         # 数据库数据
└── redis/         # Redis 数据
```

**用户文件路径：**
```
/opt/nextcloud/data/<用户名>/files/
```

例如，用户 `admin` 上传的文件位于：
```
/opt/nextcloud/data/admin/files/
```

> **注意**：数据目录权限为 `drwxrwx---`（770），属于 `www-data:www-data`，需要 `sudo` 才能访问。

## 常用操作

### 查看服务状态

```bash
sudo docker-compose ps
```

### 查看日志

```bash
sudo docker logs nextcloud
```

### 扫描手动添加的文件

如果直接在文件系统中复制文件到数据目录，需要手动扫描：

```bash
# 复制文件到用户目录
sudo cp your_file.txt /opt/nextcloud/data/admin/files/

# 设置正确权限
sudo chown -R 33:33 /opt/nextcloud/data/admin/files/

# 扫描新文件
sudo docker exec -u www-data nextcloud php occ files:scan admin
```

### 数据备份

```bash
# 备份用户数据
sudo tar -czvf nextcloud-data-backup.tar.gz /opt/nextcloud/data/

# 完整备份（包含数据库）
sudo tar -czvf nextcloud-full-backup.tar.gz /opt/nextcloud/
```

### 数据迁移

1. 停止服务：`sudo ./stop.sh`
2. 复制整个 `/opt/nextcloud/` 目录到新服务器
3. 复制项目目录到新服务器
4. 启动服务：`sudo ./start.sh`

## 同步客户端

NextCloud 支持多平台同步客户端：

| 平台 | 下载方式 |
|------|----------|
| Windows/macOS/Linux | [官网下载](https://nextcloud.com/install/#install-clients) |
| iOS | App Store 搜索 "NextCloud" |
| Android | Google Play 搜索 "NextCloud" |

配置同步客户端时，服务器地址填写 `http://<服务器IP>:8080`

## 注意事项

1. **权限要求**：启动脚本需要 root 权限以创建 `/opt/nextcloud` 目录
2. **密码安全**：生产环境请务必修改 `.env` 中的默认密码
3. **域名配置**：如需通过域名访问，请将 `NEXTCLOUD_TRUSTED_DOMAIN` 设置为对应域名
4. **端口冲突**：确保 `NEXTCLOUD_PORT` 端口未被占用
5. **数据备份**：定期备份 `/opt/nextcloud/data/` 目录下的用户数据

## 常见问题

### 无法访问 NextCloud

1. 检查容器状态：`sudo docker-compose ps`
2. 检查日志：`sudo docker logs nextcloud`
3. 确认防火墙已开放对应端口

### 配置修改后生效

修改 `.env` 文件后，重新执行 `sudo ./start.sh` 即可应用新配置。

### 忘记管理员密码

```bash
sudo docker exec -u www-data nextcloud php occ user:resetpassword admin
```

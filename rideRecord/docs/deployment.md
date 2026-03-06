# Docker 部署指南

本文档说明如何使用 Docker 和 Docker Compose 部署 RideRecord 服务端。

## 快速开始

### 1. 准备环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件，填入实际配置
vim .env
```

### 2. 构建并启动服务

```bash
# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f api
```

### 3. 验证服务

```bash
# 健康检查
curl http://localhost:3000/health

# API 文档
open http://localhost:3000/api-docs
```

## 常用命令

### 服务管理

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart api

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f api
```

### 数据管理

```bash
# 备份数据库
docker run --rm -v riderecord-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/riderecord-data-$(date +%Y%m%d).tar.gz /data

# 恢复数据库
docker run --rm -v riderecord-data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/riderecord-data-20260306.tar.gz -C /

# 查看数据卷
docker volume ls | grep riderecord
```

### 更新部署

```bash
# 拉取最新镜像
docker-compose pull

# 重新构建并启动
docker-compose up -d --build

# 清理旧镜像
docker image prune -f
```

## 生产环境部署

### 1. 使用 HTTPS

编辑 `nginx/nginx.conf`，取消 HTTPS 配置的注释，并准备 SSL 证书：

```bash
# 创建 SSL 目录
mkdir -p nginx/ssl

# 放置证书文件
cp your-cert.pem nginx/ssl/cert.pem
cp your-key.pem nginx/ssl/key.pem
```

### 2. 优化配置

编辑 `docker-compose.yml`：

```yaml
services:
  api:
    environment:
      - NODE_ENV=production
      - LOG_LEVEL=warn
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

### 3. 设置日志轮转

```yaml
services:
  api:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
```

## 故障排查

### 查看容器日志

```bash
# 查看最近的日志
docker-compose logs --tail=100 api

# 实时查看日志
docker-compose logs -f api
```

### 进入容器调试

```bash
# 进入 API 容器
docker-compose exec api sh

# 检查数据库
docker-compose exec api ls -la /app/data
```

### 检查网络

```bash
# 查看网络配置
docker network inspect riderecord_ride-record-network

# 测试服务连通性
docker-compose exec nginx ping api
```

## 性能优化

### 镜像大小优化

当前镜像大小：~100MB (Alpine 基础镜像)

优化措施：
- 多阶段构建
- 使用 Alpine 基础镜像
- 只复制必要的生产文件
- 清理缓存和临时文件

### 资源限制

```yaml
services:
  api:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

## 监控

### 健康检查

```bash
# 通过 curl 检查
curl -f http://localhost:3000/health || exit 1

# 通过 Docker 检查
docker inspect --format='{{.State.Health.Status}}' riderecord-api
```

### 资源使用

```bash
# 查看容器资源使用
docker stats riderecord-api

# 查看容器详情
docker inspect riderecord-api
```

## 安全建议

1. **不要在镜像中存储敏感信息** - 使用环境变量或密钥管理
2. **定期更新基础镜像** - `docker-compose pull && docker-compose up -d`
3. **使用非 root 用户运行** - 已在 Dockerfile 中配置
4. **启用 HTTPS** - 生产环境必须
5. **配置防火墙** - 只开放必要端口
6. **定期备份数据** - 数据库和上传文件

## 相关文件

```
rideRecord/
├── docker-compose.yml          # Docker Compose 配置
├── server/
│   ├── Dockerfile              # API 服务镜像
│   ├── .dockerignore           # Docker 忽略文件
│   └── .env.example            # 环境变量模板
├── nginx/
│   └── nginx.conf              # Nginx 配置
└── .github/
    └── workflows/
        └── docker-publish.yml  # GitHub Actions 自动构建
```

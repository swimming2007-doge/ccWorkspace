# 安装部署 Jitsi Meet（适配中国大陆 + 4U8G 服务器）

本文档提供一套在 **Ubuntu 20.04/22.04** 上部署 **Jitsi Meet** 的完整流程，适配：

- 中国大陆网络环境  
- 4 核 8GB 内存（4U8G）服务器，后续用得多了可以扩大
- Docker + Docker Compose v2  
- HTTPS访问是必须的

---

## 1. 系统更新与基础依赖

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git
```

## 2. 安装 

添加阿里云 GPG key

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

添加阿里云 Docker 源

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

安装 Docker

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

启动 Docker

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

检查Docke Compose是否ready

```bash
docker compose
docker compose version
```

## 3. 下载 Jitsi Meet（Gitee 国内镜像）

```bash
cd ~/workspace
git clone https://gitee.com/mirrors/docker-jitsi-meet.git
cd docker-jitsi-meet
```

## 4. 生成配置文件

```bash
cp env.example .env
./gen-passwords.sh
``` 

## 5. 编辑 .env 适配 4U8G + HTTP

```bash
vim .env
```

```bash
PUBLIC_URL=http://你的服务器IP:8000
HTTP_PORT=8000
HTTPS_PORT=8443
TZ=Asia/Shanghai
```



## 6. 使用Docker Compose管理服务进程

```bash
docker compose pull
docker compose up -d
docker ps
```

后续进程重启就用

```bash
docker compose down
docker compose up -d
```

## 防火墙与安全组配置

```bash
sudo ufw allow 8000/tcp
sudo ufw allow 8443/tcp
sudo ufw allow 10000/udp
```
云 ECS 需在安全组开放上下行：

- TCP 8000

- TCP 8443

- UDP 10000

## WebRTC is not available in your browser

- PUBLIC_URL 未设置

- 访问方式错误（使用 HTTPS）

- 浏览器不支持 WebRTC（IE/360 兼容模式），chrome，手机自带原生浏览器都是OK的

- 未开放 UDP 10000

## 进入登陆界面后仍然有各种小问题，通过看日志解决

- docker logs docker-jitsi-meet-web-1 --tail=200
- 把输出日志给大模型看，他的解决方案可参考，但不能完全照搬


## 一些常见问题： Jitsi Meet（Docker）部署与排障 10 条核心经验总结

1. **HTTPS 是必须的**：公网访问 Jitsi 时，浏览器会在 HTTP 下禁用 WebRTC，导致直接跳转 webrtcUnsupported.html。  
2. **PUBLIC_URL 必须与实际访问一致**：访问用 HTTPS，就必须写成 `PUBLIC_URL=https://IP:8443`。  
3. **JVB 必须设置公网 IP**：`.env` 中添加 `JVB_ADVERTISE_IP=你的公网IP`，否则 ICE 失败、会议断开。  
4. **JVB 密码不能为空**：`JVB_AUTH_PASSWORD`、`JICOFO_AUTH_PASSWORD` 必须设置，否则 JVB 无法登录 XMPP。  
5. **修改密码后必须删除旧配置**：删除 `~/.jitsi-meet-cfg`，否则 Prosody 会继续使用旧密码。  
6. **UDP 10000 必须放行**：云安全组 + 防火墙都要放行 `UDP 10000`，否则只有视频没有声音。  
7. **确认 JVB 是否监听端口**：`netstat -tunlp | grep 10000` 必须能看到 UDP 监听。  
8. **浏览器麦克风权限要允许**：PC 上取消静音无效通常是浏览器或系统层面禁用了麦克风。  
9. **国产浏览器可能屏蔽 WebRTC**：手机端建议用 Chrome/Edge 测试，鸿蒙/华为浏览器可能限制音频。  
10. **多端测试能快速定位问题**：PC ↔ 手机、WiFi ↔ 4G 交叉测试可判断是服务器问题还是客户端权限问题。

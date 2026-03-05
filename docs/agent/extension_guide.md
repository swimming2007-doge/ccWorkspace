# 内网扩展指南

## 1. 概述

本文档说明如何将 ArXiv Blog Agent 从公网环境扩展到完全封闭的内网环境。

## 2. 扩展场景

### 2.1 常见内网场景
| 场景 | 描述 | 需要修改的组件 |
|-----|------|--------------|
| 纯内网部署 | 无法访问公网 | 网络层、数据源 |
| 混合网络 | 部分可访问公网 | 代理配置 |
| 私有博客平台 | 内部博客系统 | 发布 Skill |
| 内网知识库 | 替代 ArXiv | 爬取 Skill |

### 2.2 扩展难度评估
| 扩展类型 | 难度 | 工作量 |
|---------|------|--------|
| 代理配置 | 低 | 修改配置文件 |
| SSL 跳过 | 低 | 修改配置文件 |
| 内网博客适配 | 中 | 继承并重写 Skill |
| 内网数据源适配 | 高 | 实现新 Skill |

## 3. 配置文件修改

### 3.1 切换到内网配置

```bash
# 使用内网配置文件
python main.py --config configs/prod_config.yaml
```

### 3.2 prod_config.yaml 模板

```yaml
# 内网环境配置模板

# 网络配置
network:
  timeout: 60
  connect_timeout: 30
  proxy: "http://internal-proxy.internal.corp:8080"
  ssl_verify: false  # 内网自签名证书场景
  pool_connections: 20

# ArXiv 爬取配置（内网镜像）
arxiv_scraper:
  base_url: "https://arxiv-mirror.internal.corp/search/"
  timeout: 60
  proxy: "http://internal-proxy.internal.corp:8080"
  ssl_verify: false

# 内容生成配置（保持不变）
content_generator:
  title_prefix: "内网知识库周报 - "
  default_category: "技术分享"

# 博客发布配置（内网平台）
blog_poster:
  api_base: "https://internal-blog.internal.corp/api/v1"
  blog_id: "${INTERNAL_BLOG_ID}"
  access_token: "${INTERNAL_BLOG_TOKEN}"
  proxy: "http://internal-proxy.internal.corp:8080"
  ssl_verify: false

# 日志配置
logging:
  level: "DEBUG"
  file: "/var/log/arxiv-blog-agent/agent.log"
```

## 4. 网络层适配

### 4.1 代理配置

```python
from skills.network_adapter import NetworkAdapter

# 内网代理配置
internal_network_config = {
    "proxy": "http://proxy.internal.corp:8080",
    "ssl_verify": False,
    "timeout": 60,
}

# 创建网络适配器
network = NetworkAdapter(internal_network_config)
```

### 4.2 SOCKS 代理支持

```python
# 需要安装: pip install requests[socks]

config = {
    "proxy": "socks5://user:password@proxy.internal.corp:1080",
}
```

### 4.3 证书配置

```python
# 使用自定义 CA 证书
config = {
    "ssl_verify": "/path/to/ca-bundle.crt",
}

# 或跳过验证（不推荐生产环境）
config = {
    "ssl_verify": False,
}
```

## 5. 内网博客平台适配

### 5.1 创建适配器

```python
from skills.blog_poster import BlogPosterSkill, BlogContent, PostResult

class InternalBlogPoster(BlogPosterSkill):
    """内网博客平台适配器"""

    def _build_post_url(self) -> str:
        """重写 API 地址"""
        return f"{self.config['api_base']}/posts"

    def _prepare_post_data(self, blog_content: BlogContent, status: str = None) -> dict:
        """适配内网 API 格式"""
        return {
            "title": blog_content.title,
            "content": blog_content.content,
            "summary": blog_content.summary,
            "tags": blog_content.tags,
            "category": blog_content.category,
            "publish": status == "publish",
        }

    def execute(self, blog_content: BlogContent, status: str = None) -> PostResult:
        """重写发布逻辑"""
        # 内网特有的认证方式
        self._session.headers.update({
            "X-Internal-Token": self.config.get("internal_token"),
        })

        return super().execute(blog_content, status)
```

### 5.2 注册适配器

```python
# 在 agent 初始化时替换 Skill
from agents.arxiv_blog_agent import ArXivBlogAgent

class InternalAgent(ArXivBlogAgent):
    def _register_skills(self):
        super()._register_skills()
        # 替换为内网适配器
        self.skills["blog_poster"] = InternalBlogPoster(self.config.blog_poster)
```

## 6. 内网数据源适配

### 6.1 内网知识库爬取

```python
from skills.arxiv_scraper import ArXivScraperSkill, ArXivPaper, ScraperResult

class InternalKnowledgeScraper(ArXivScraperSkill):
    """内网知识库爬取器"""

    def _build_search_url(self, query: str, max_results: int,
                          sort_by: str, sort_order: str) -> str:
        """构建内网知识库搜索 URL"""
        return f"{self.config['base_url']}/api/search?q={query}&limit={max_results}"

    def _parse_paper_from_item(self, item: dict) -> ArXivPaper:
        """解析内网数据格式"""
        return ArXivPaper(
            title=item.get("doc_title", ""),
            authors=item.get("authors", []),
            abstract=item.get("summary", ""),
            arxiv_id=item.get("doc_id", ""),
            url=item.get("doc_url", ""),
            pdf_url=item.get("pdf_url", ""),
            submitted_date=item.get("create_time", ""),
            categories=item.get("tags", []),
        )

    def execute(self, query: str = None, max_results: int = None,
                sort_by: str = None, sort_order: str = None) -> ScraperResult:
        """执行内网爬取"""
        # 调用内网 API
        url = self._build_search_url(query, max_results, sort_by, sort_order)
        response = self._get_session().get(url)

        # 解析 JSON 响应（内网通常返回 JSON）
        data = response.json()

        papers = [self._parse_paper_from_item(item) for item in data.get("results", [])]

        return ScraperResult(
            success=True,
            papers=papers,
            total_count=len(papers),
        )
```

## 7. 环境变量配置

### 7.1 .env 文件（公网）

```bash
# .env
WORDPRESS_ACCESS_TOKEN=your_real_token_here
BLOG_ID=791025341
```

### 7.2 .env.internal 文件（内网）

```bash
# .env.internal
INTERNAL_BLOG_ID=internal_blog_001
INTERNAL_BLOG_TOKEN=internal_token_here
PROXY_URL=http://proxy.internal.corp:8080
ARXIV_MIRROR_URL=https://arxiv-mirror.internal.corp
```

### 7.3 加载环境变量

```python
from dotenv import load_dotenv
import os

# 加载内网配置
load_dotenv(".env.internal")

config = {
    "blog_id": os.getenv("INTERNAL_BLOG_ID"),
    "access_token": os.getenv("INTERNAL_BLOG_TOKEN"),
    "proxy": os.getenv("PROXY_URL"),
}
```

## 8. 部署配置

### 8.1 Docker 部署

```dockerfile
# Dockerfile
FROM python:3.10-slim

WORKDIR /app

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制代码
COPY . .

# 设置环境变量
ENV CONFIG_FILE=configs/prod_config.yaml

# 运行
CMD ["python", "main.py"]
```

### 8.2 docker-compose.yml

```yaml
version: '3.8'

services:
  arxiv-blog-agent:
    build: .
    environment:
      - CONFIG_FILE=configs/prod_config.yaml
      - INTERNAL_BLOG_TOKEN=${INTERNAL_BLOG_TOKEN}
    volumes:
      - ./logs:/app/logs
      - ./configs:/app/configs:ro
    networks:
      - internal-network

networks:
  internal-network:
    driver: bridge
```

## 9. 安全配置

### 9.1 敏感信息管理

```python
# 不要在代码中硬编码敏感信息
# 使用环境变量或密钥管理服务

import os
from typing import Optional

def get_secret(key: str, default: str = None) -> Optional[str]:
    """从环境变量或密钥服务获取配置"""
    # 优先从环境变量获取
    value = os.getenv(key)
    if value:
        return value

    # 从内网密钥服务获取（需要实现）
    # return get_from_vault(key)

    return default
```

### 9.2 日志脱敏

```python
import re

def sanitize_log_message(message: str) -> str:
    """日志脱敏处理"""
    # 隐藏 token
    message = re.sub(r'(token["\s:=]+)[\w-]+', r'\g<1>***', message)
    # 隐藏密码
    message = re.sub(r'(password["\s:=]+)[\w-]+', r'\g<1>***', message)
    return message
```

## 10. 测试内网配置

### 10.1 连通性测试

```python
from skills.network_adapter import NetworkAdapter

def test_internal_network():
    """测试内网连通性"""
    config = {
        "proxy": "http://proxy.internal.corp:8080",
        "ssl_verify": False,
    }

    adapter = NetworkAdapter(config)

    # 测试代理连通性
    result = adapter.test_connectivity("https://internal-blog.internal.corp/health")
    print(f"连通性测试: {result}")

    adapter.close()
```

### 10.2 端到端测试

```python
def test_internal_workflow():
    """测试内网完整工作流"""
    agent = ArXivBlogAgent(config_path="configs/prod_config.yaml")
    result = agent.run()

    assert result.success, f"工作流失败: {result.error_message}"
    print(f"测试成功: {result.post_url}")
```

## 11. 故障排查

### 11.1 常见问题

| 问题 | 可能原因 | 解决方案 |
|-----|---------|---------|
| SSL 错误 | 自签名证书 | 设置 `ssl_verify: false` |
| 代理超时 | 代理服务器问题 | 检查代理地址和端口 |
| 认证失败 | Token 过期 | 更新 access_token |
| 连接拒绝 | 防火墙规则 | 联系网络管理员 |

### 11.2 调试模式

```python
# 开启调试日志
config = {
    "log_level": "DEBUG",
}

# 或通过命令行
python main.py --debug
```

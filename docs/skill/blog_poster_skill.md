# Blog Poster Skill

## 1. Skill 定义

### 1.1 功能描述
将生成的博客内容发布到 WordPress.com 博客平台，支持公网测试和内网扩展。

### 1.2 输入参数
| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|------|-------|------|
| blog_content | BlogContent | 是 | - | 博客内容 |
| status | str | 否 | "publish" | 发布状态 |
| blog_id | str | 否 | 见配置 | 博客 ID |

### 1.3 输出结构
```python
@dataclass
class PostResult:
    success: bool           # 是否成功
    post_id: str            # 文章 ID
    post_url: str           # 文章链接
    error_message: str      # 错误信息（如有）
    posted_at: str          # 发布时间戳
```

## 2. 实现代码

```python
"""
Blog Poster Skill - 发布博客到 WordPress.com

默认配置：
- 平台: WordPress.com
- 博客 ID: 791025341
- 参考站点: https://swimming2007.wordpress.com/
- 认证: Bearer Token（测试令牌，实际使用需替换）
- 状态: publish

重要说明：
- 默认使用测试令牌，实际发布前需替换为真实令牌
- 支持 WordPress.com REST API
- 预留内网博客平台扩展接口
"""

import json
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

import requests

# 导入博客内容数据结构
from skills.content_generator import BlogContent


@dataclass
class PostResult:
    """发布结果数据结构"""
    success: bool
    post_id: str = ""
    post_url: str = ""
    error_message: str = ""
    posted_at: str = ""


class BlogPosterSkill:
    """
    博客发布技能

    功能：将博客内容发布到 WordPress.com
    支持：公网 WordPress.com / 内网博客平台扩展
    """

    # 默认配置（硬编码，确保无需配置即可运行）
    DEFAULT_CONFIG = {
        # WordPress.com API 配置
        "api_base": "https://public-api.wordpress.com/rest/v1.1",
        "blog_id": "791025341",  # swimming2007.wordpress.com
        "blog_url": "https://swimming2007.wordpress.com/",

        # 认证配置
        # 注意：此为测试令牌，实际使用时需替换为真实令牌
        # 获取方式：https://developer.wordpress.com/docs/oauth2/
        "access_token": "NzkxMDI1MzQxJTNBYXp4cCUyMGY0ZHYlMjB5c2tzJTIweWJxdiUyMA==",

        # 发布配置
        "default_status": "publish",  # publish, draft, private
        "default_category": "AI/大模型",

        # 网络配置
        "timeout": 20,
        "max_retries": 3,
        "retry_delay": 2,
        "proxy": None,
        "ssl_verify": True,
    }

    def __init__(self, config: Optional[dict] = None):
        """
        初始化博客发布器

        Args:
            config: 配置字典，覆盖默认配置
        """
        self.config = {**self.DEFAULT_CONFIG, **(config or {})}
        self._session = None

    def _get_session(self) -> requests.Session:
        """获取或创建 HTTP 会话"""
        if self._session is None:
            self._session = requests.Session()
            self._session.headers.update({
                "Authorization": f"Bearer {self.config['access_token']}",
                "Content-Type": "application/json",
                "User-Agent": "ArXiv-Blog-Agent/1.0",
            })
            if self.config.get("proxy"):
                self._session.proxies = {
                    "http": self.config["proxy"],
                    "https": self.config["proxy"],
                }
        return self._session

    def _build_post_url(self) -> str:
        """构建发布 API URL"""
        return f"{self.config['api_base']}/sites/{self.config['blog_id']}/posts/new"

    def _prepare_post_data(self, blog_content: BlogContent,
                           status: str = None) -> dict:
        """准备发布数据"""
        return {
            "title": blog_content.title,
            "content": blog_content.content,
            "excerpt": blog_content.summary,
            "status": status or self.config["default_status"],
            "categories": blog_content.category,
            "tags": ",".join(blog_content.tags) if blog_content.tags else "",
            "date": datetime.now().isoformat(),
        }

    def execute(self, blog_content: BlogContent,
                status: str = None) -> PostResult:
        """
        执行博客发布任务

        Args:
            blog_content: 博客内容
            status: 发布状态（publish/draft/private）

        Returns:
            PostResult: 发布结果
        """
        result = PostResult(
            success=False,
            posted_at=datetime.now().isoformat(),
        )

        # 验证内容
        if not blog_content or not blog_content.title:
            result.error_message = "博客内容无效或标题为空"
            return result

        url = self._build_post_url()
        post_data = self._prepare_post_data(blog_content, status)

        for attempt in range(self.config["max_retries"]):
            try:
                session = self._get_session()
                response = session.post(
                    url,
                    data=json.dumps(post_data),
                    timeout=self.config["timeout"],
                    verify=self.config["ssl_verify"],
                )

                # 解析响应
                response_data = response.json()

                if response.status_code == 200:
                    result.success = True
                    result.post_id = str(response_data.get("ID", ""))
                    result.post_url = response_data.get("URL", "")
                    return result

                elif response.status_code == 401:
                    result.error_message = (
                        "认证失败：请检查 access_token 是否有效。"
                        "默认令牌仅用于测试，实际发布需替换为真实令牌。"
                    )
                    break

                elif response.status_code == 403:
                    result.error_message = "权限不足：请检查博客 ID 和用户权限"
                    break

                else:
                    error_msg = response_data.get("error", response_data.get("message", "未知错误"))
                    result.error_message = f"发布失败 (HTTP {response.status_code}): {error_msg}"

                    if attempt < self.config["max_retries"] - 1:
                        import time
                        time.sleep(self.config["retry_delay"])

            except requests.exceptions.RequestException as e:
                result.error_message = f"网络请求失败: {str(e)}"
                if attempt < self.config["max_retries"] - 1:
                    import time
                    time.sleep(self.config["retry_delay"])

            except json.JSONDecodeError as e:
                result.error_message = f"响应解析失败: {str(e)}"
                break

            except Exception as e:
                result.error_message = f"未知错误: {str(e)}"
                break

        return result

    def test_connection(self) -> dict:
        """
        测试 API 连接

        Returns:
            dict: 连接测试结果
        """
        try:
            session = self._get_session()
            # 获取站点信息
            url = f"{self.config['api_base']}/sites/{self.config['blog_id']}"
            response = session.get(url, timeout=self.config["timeout"])

            if response.status_code == 200:
                data = response.json()
                return {
                    "success": True,
                    "site_name": data.get("name", ""),
                    "site_url": data.get("URL", ""),
                    "message": "连接成功",
                }
            else:
                return {
                    "success": False,
                    "message": f"连接失败: HTTP {response.status_code}",
                }
        except Exception as e:
            return {
                "success": False,
                "message": f"连接异常: {str(e)}",
            }

    def close(self):
        """关闭会话"""
        if self._session:
            self._session.close()
            self._session = None


class MockBlogPosterSkill(BlogPosterSkill):
    """
    模拟博客发布器（用于测试）

    不实际发送请求，返回模拟的成功结果
    """

    def execute(self, blog_content: BlogContent,
                status: str = None) -> PostResult:
        """模拟发布"""
        return PostResult(
            success=True,
            post_id="mock_post_12345",
            post_url=f"{self.config['blog_url']}mock-post-{datetime.now().strftime('%Y%m%d')}",
            posted_at=datetime.now().isoformat(),
        )


# 便捷函数
def post_to_wordpress(blog_content: BlogContent,
                      status: str = "publish",
                      config: dict = None) -> PostResult:
    """
    便捷函数：发布到 WordPress

    Args:
        blog_content: 博客内容
        status: 发布状态
        config: 额外配置

    Returns:
        PostResult: 发布结果
    """
    poster = BlogPosterSkill(config)
    try:
        return poster.execute(blog_content=blog_content, status=status)
    finally:
        poster.close()
```

## 3. 使用示例

### 3.1 基础用法
```python
from skills.blog_poster import BlogPosterSkill
from skills.content_generator import BlogContent

# 创建博客内容
blog_content = BlogContent(
    title="测试文章",
    summary="这是一篇测试文章",
    content="# 测试\n\n这是正文内容。",
    tags=["AI", "测试"],
    category="AI/大模型"
)

# 发布博客
poster = BlogPosterSkill()
result = poster.execute(blog_content)

if result.success:
    print(f"发布成功！文章链接: {result.post_url}")
else:
    print(f"发布失败: {result.error_message}")
```

### 3.2 使用真实令牌
```python
# 替换为真实令牌
config = {
    "access_token": "YOUR_REAL_ACCESS_TOKEN",  # 替换为实际令牌
    "blog_id": "YOUR_BLOG_ID",                  # 替换为实际博客 ID
}
poster = BlogPosterSkill(config)
result = poster.execute(blog_content)
```

### 3.3 测试连接
```python
# 测试 API 连接
poster = BlogPosterSkill()
test_result = poster.test_connection()
print(f"连接测试: {test_result}")
```

### 3.4 模拟发布（用于测试）
```python
from skills.blog_poster import MockBlogPosterSkill

# 使用模拟发布器进行测试
mock_poster = MockBlogPosterSkill()
result = mock_poster.execute(blog_content)
# 始终返回成功，不实际发送请求
```

## 4. 获取 WordPress.com 访问令牌

### 4.1 步骤
1. 访问 [WordPress.com Developer](https://developer.wordpress.com/apps/)
2. 创建新应用
3. 获取 Client ID 和 Client Secret
4. 使用 OAuth2 流程获取访问令牌

### 4.2 快速获取测试令牌
```bash
# 使用 WordPress.com CLI
wp oauth2 get-token --client_id=YOUR_CLIENT_ID --client_secret=YOUR_CLIENT_SECRET
```

## 5. 内网扩展

### 5.1 内网博客平台配置
```yaml
# configs/prod_config.yaml
blog_poster:
  api_base: "https://internal-blog.internal.corp/api/v1"
  blog_id: "internal_blog_001"
  access_token: "${INTERNAL_BLOG_TOKEN}"
  proxy: "http://proxy.internal.corp:8080"
  ssl_verify: false
```

### 5.2 自定义博客平台适配
```python
class InternalBlogPoster(BlogPosterSkill):
    """内网博客平台适配器"""

    def _build_post_url(self) -> str:
        return f"{self.config['api_base']}/posts"

    def _prepare_post_data(self, blog_content, status=None):
        # 适配内网 API 格式
        return {
            "post_title": blog_content.title,
            "post_content": blog_content.content,
            "post_status": status or "publish",
            "post_category": blog_content.category,
        }
```

## 6. 错误处理

| 错误码 | 说明 | 处理建议 |
|-------|------|---------|
| 401 | 认证失败 | 检查令牌是否有效 |
| 403 | 权限不足 | 检查博客 ID 和用户权限 |
| 404 | 博客不存在 | 检查博客 ID 是否正确 |
| 429 | 请求频率限制 | 等待后重试 |
| 500 | 服务器错误 | 重试或联系支持 |

## 7. 配置说明

```yaml
# configs/config.yaml
blog_poster:
  api_base: "https://public-api.wordpress.com/rest/v1.1"
  blog_id: "791025341"
  access_token: "NzkxMDI1MzQxJTNBYXp4cCUyMGY0ZHYlMjB5c2tzJTIweWJxdiUyMA=="
  default_status: "publish"
  timeout: 20
  max_retries: 3
  proxy: null
  ssl_verify: true
```

**重要提示**：默认 access_token 仅供测试使用，实际发布前必须替换为真实令牌！

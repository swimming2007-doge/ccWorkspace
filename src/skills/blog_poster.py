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
import time
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, List

import requests


@dataclass
class BlogContent:
    """博客内容数据结构"""
    title: str
    summary: str
    content: str
    tags: List[str] = field(default_factory=list)
    category: str = "AI/大模型"
    created_at: str = ""


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

    DEFAULT_CONFIG = {
        "api_base": "https://public-api.wordpress.com/rest/v1.1",
        "blog_id": "791025341",
        "blog_url": "https://swimming2007.wordpress.com/",
        "access_token": "NzkxMDI1MzQxJTNBYXp4cCUyMGY0ZHYlMjB5c2tzJTIweWJxdiUyMA==",
        "default_status": "publish",
        "default_category": "AI/大模型",
        "timeout": 20,
        "max_retries": 3,
        "retry_delay": 2,
        "proxy": None,
        "ssl_verify": True,
    }

    def __init__(self, config: Optional[dict] = None):
        """初始化博客发布器"""
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
                        time.sleep(self.config["retry_delay"])

            except requests.exceptions.RequestException as e:
                result.error_message = f"网络请求失败: {str(e)}"
                if attempt < self.config["max_retries"] - 1:
                    time.sleep(self.config["retry_delay"])

            except json.JSONDecodeError as e:
                result.error_message = f"响应解析失败: {str(e)}"
                break

            except Exception as e:
                result.error_message = f"未知错误: {str(e)}"
                break

        return result

    def test_connection(self) -> dict:
        """测试 API 连接"""
        try:
            session = self._get_session()
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

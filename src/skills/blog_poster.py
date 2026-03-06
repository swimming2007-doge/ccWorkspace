"""
Blog Poster Skill - 发布博客到 WordPress

所有配置必须从 config.yaml 获取，代码中不设置默认值
"""

import json
import logging
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
    category: str = ""
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

    所有配置从 config.yaml 获取，必须包含以下字段：
    - api_base: WordPress API 地址
    - blog_id: 博客 ID
    - blog_url: 博客 URL
    - access_token: 访问令牌
    - status: 发布状态
    - default_category: 默认分类
    - timeout: 超时时间
    - max_retries: 最大重试次数
    - retry_delay: 重试间隔
    - proxy: 代理地址（可选）
    - ssl_verify: SSL 验证（可选）
    """

    def __init__(self, config: dict):
        """
        初始化博客发布器

        Args:
            config: 从 config.yaml 加载的配置字典，必须包含所有必需字段

        Raises:
            ValueError: 缺少必需配置项
        """
        # 验证必需配置项
        required_keys = [
            "api_base", "blog_id", "blog_url", "access_token",
            "status", "default_category", "timeout", "max_retries", "retry_delay"
        ]
        missing = [k for k in required_keys if k not in config or config.get(k) is None or config.get(k) == ""]

        if missing:
            raise ValueError(f"BlogPosterSkill 缺少必需配置项: {missing}\n"
                           f"请在 config.yaml 的 blog 节中配置以下字段: {missing}")

        # 从 config 获取所有配置，不设置任何默认值
        self.api_base = config["api_base"]
        self.blog_id = config["blog_id"]
        self.blog_url = config["blog_url"]
        self.access_token = config["access_token"]
        self.status = config["status"]
        self.default_category = config["default_category"]
        self.timeout = config["timeout"]
        self.max_retries = config["max_retries"]
        self.retry_delay = config["retry_delay"]
        self.proxy = config.get("proxy")
        self.ssl_verify = config.get("ssl_verify", True)

        self._session = None
        self._logger = logging.getLogger("blog_poster")

    def _get_session(self) -> requests.Session:
        """获取或创建 HTTP 会话"""
        if self._session is None:
            self._session = requests.Session()
            self._session.headers.update({
                "Authorization": f"Bearer {self.access_token}",
                "Content-Type": "application/json",
                "User-Agent": "ArXiv-Blog-Agent/1.0",
            })
            if self.proxy:
                self._session.proxies = {
                    "http": self.proxy,
                    "https": self.proxy,
                }
        return self._session

    def _build_post_url(self) -> str:
        """构建发布 API URL"""
        return f"{self.api_base}/sites/{self.blog_id}/posts/new"

    def _prepare_post_data(self, blog_content: BlogContent) -> dict:
        """准备发布数据"""
        return {
            "title": blog_content.title,
            "content": blog_content.content,
            "excerpt": blog_content.summary,
            "status": self.status,
            "categories": blog_content.category or self.default_category,
            "tags": ",".join(blog_content.tags) if blog_content.tags else "",
            "date": datetime.now().isoformat(),
        }

    def _log_request(self, url: str, headers: dict, body_json: str, attempt: int):
        """记录请求详情"""
        self._logger.info("=" * 70)
        self._logger.info(f"[REQUEST] Attempt {attempt + 1}/{self.max_retries}")
        self._logger.info("-" * 70)
        self._logger.info(f"URL: {url}")
        self._logger.info(f"Method: POST")
        self._logger.info("-" * 70)
        self._logger.info("Headers:")
        for k, v in headers.items():
            self._logger.info(f"  {k}: {v}")
        self._logger.info("-" * 70)
        self._logger.info("Request Body:")
        try:
            body_obj = json.loads(body_json)
            for line in json.dumps(body_obj, indent=2, ensure_ascii=False).split('\n'):
                self._logger.info(f"  {line}")
        except Exception:
            self._logger.info(f"  {body_json}")
        self._logger.info("=" * 70)

    def _log_response(self, response: requests.Response, duration: float):
        """记录响应详情"""
        self._logger.info("=" * 70)
        self._logger.info("[RESPONSE]")
        self._logger.info("-" * 70)
        self._logger.info(f"Status Code: {response.status_code}")
        self._logger.info(f"Response Time: {duration:.3f}s")
        self._logger.info("-" * 70)
        self._logger.info("Response Headers:")
        for k, v in response.headers.items():
            self._logger.info(f"  {k}: {v}")
        self._logger.info("-" * 70)
        self._logger.info("Response Body:")
        try:
            resp_json = response.json()
            for line in json.dumps(resp_json, indent=2, ensure_ascii=False).split('\n'):
                self._logger.info(f"  {line}")
        except Exception:
            self._logger.info(f"  {response.text}")
        self._logger.info("=" * 70)

    def execute(self, blog_content: BlogContent) -> PostResult:
        """
        执行博客发布任务

        Args:
            blog_content: 博客内容

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
            self._logger.error(f"[VALIDATION ERROR] {result.error_message}")
            return result

        url = self._build_post_url()
        post_data = self._prepare_post_data(blog_content)
        body_json = json.dumps(post_data)

        self._logger.info(f"[BLOG POSTER] Starting publish task")
        self._logger.info(f"  Blog ID: {self.blog_id}")
        self._logger.info(f"  Blog URL: {self.blog_url}")
        self._logger.info(f"  Target Status: {self.status}")

        for attempt in range(self.max_retries):
            try:
                session = self._get_session()

                # 记录请求
                self._log_request(url, dict(session.headers), body_json, attempt)

                # 发送请求
                start_time = time.time()
                response = session.post(
                    url,
                    data=body_json,
                    timeout=self.timeout,
                    verify=self.ssl_verify,
                )
                duration = time.time() - start_time

                # 记录响应
                self._log_response(response, duration)

                # 解析结果
                response_data = response.json()

                if response.status_code == 200:
                    result.success = True
                    result.post_id = str(response_data.get("ID", ""))
                    result.post_url = response_data.get("URL", "")
                    self._logger.info(f"[SUCCESS] Post published!")
                    self._logger.info(f"  Post ID: {result.post_id}")
                    self._logger.info(f"  Post URL: {result.post_url}")
                    return result

                elif response.status_code == 401:
                    result.error_message = "认证失败：access_token 无效或已过期"
                    self._logger.error(f"[AUTH ERROR] {result.error_message}")
                    break

                elif response.status_code == 403:
                    result.error_message = "权限不足：无权访问此博客"
                    self._logger.error(f"[FORBIDDEN ERROR] {result.error_message}")
                    break

                elif response.status_code == 404:
                    result.error_message = "资源不存在：blog_id 不正确"
                    self._logger.error(f"[NOT FOUND ERROR] {result.error_message}")
                    break

                else:
                    error_msg = response_data.get("error", response_data.get("message", "未知错误"))
                    result.error_message = f"发布失败 (HTTP {response.status_code}): {error_msg}"
                    self._logger.error(f"[API ERROR] {result.error_message}")

                    if attempt < self.max_retries - 1:
                        self._logger.info(f"Retrying in {self.retry_delay}s...")
                        time.sleep(self.retry_delay)

            except requests.exceptions.Timeout as e:
                self._logger.error(f"[TIMEOUT ERROR] {e}")
                result.error_message = f"请求超时: {e}"
                if attempt < self.max_retries - 1:
                    time.sleep(self.retry_delay)

            except requests.exceptions.ConnectionError as e:
                self._logger.error(f"[CONNECTION ERROR] {e}")
                result.error_message = f"连接错误: {e}"
                if attempt < self.max_retries - 1:
                    time.sleep(self.retry_delay)

            except json.JSONDecodeError as e:
                self._logger.error(f"[JSON ERROR] {e}")
                result.error_message = f"响应解析失败: {e}"
                break

            except Exception as e:
                self._logger.error(f"[UNKNOWN ERROR] {e}")
                result.error_message = f"未知错误: {e}"
                break

        return result

    def close(self):
        """关闭会话"""
        if self._session:
            self._session.close()
            self._session = None


class MockBlogPosterSkill:
    """
    模拟博客发布器（用于干运行测试）

    不实际发送请求，仅打印配置和内容
    """

    def __init__(self, config: dict):
        """初始化"""
        self.api_base = config.get("api_base", "")
        self.blog_id = config.get("blog_id", "")
        self.blog_url = config.get("blog_url", "")
        self.access_token = config.get("access_token", "")
        self.status = config.get("status", "")
        self.default_category = config.get("default_category", "")
        self._logger = logging.getLogger("blog_poster")

    def execute(self, blog_content: BlogContent) -> PostResult:
        """模拟发布"""
        self._logger.info("=" * 70)
        self._logger.info("[MOCK MODE] Simulating blog post (dry run)")
        self._logger.info("-" * 70)
        self._logger.info("Config from config.yaml:")
        self._logger.info(f"  api_base: {self.api_base}")
        self._logger.info(f"  blog_id: {self.blog_id}")
        self._logger.info(f"  blog_url: {self.blog_url}")
        self._logger.info(f"  access_token: {self.access_token}")
        self._logger.info(f"  status: {self.status}")
        self._logger.info(f"  default_category: {self.default_category}")
        self._logger.info("-" * 70)
        self._logger.info("Request Body (JSON):")
        post_data = {
            "title": blog_content.title,
            "content": f"[{len(blog_content.content)} chars]",
            "excerpt": blog_content.summary,
            "status": self.status,
            "categories": blog_content.category or self.default_category,
            "tags": ",".join(blog_content.tags) if blog_content.tags else "",
        }
        for line in json.dumps(post_data, indent=2, ensure_ascii=False).split('\n'):
            self._logger.info(f"  {line}")
        self._logger.info("-" * 70)
        self._logger.info("[MOCK RESPONSE]")
        self._logger.info(f"  Status Code: 200 (simulated)")
        self._logger.info(f"  Post ID: mock_post")
        self._logger.info(f"  Post URL: {self.blog_url}?p=mock")
        self._logger.info("=" * 70)

        return PostResult(
            success=True,
            post_id="mock_post",
            post_url=f"{self.blog_url}?p=mock",
            posted_at=datetime.now().isoformat(),
        )

    def close(self):
        pass

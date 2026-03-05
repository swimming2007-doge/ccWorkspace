"""
HTTP Client - 统一 HTTP 客户端工具

功能：
- 统一的 HTTP 请求接口
- 自动重试机制
- 代理支持
- SSL 配置
- 连接池管理
"""

import time
import logging
from typing import Optional, Dict, Any, Union
from dataclasses import dataclass

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


@dataclass
class HttpClientConfig:
    """HTTP 客户端配置"""
    timeout: int = 20
    connect_timeout: int = 10
    read_timeout: int = 20
    max_retries: int = 3
    retry_delay: float = 1.0
    pool_connections: int = 10
    pool_maxsize: int = 10
    proxy: Optional[str] = None
    ssl_verify: bool = True
    user_agent: str = "ArXiv-Blog-Agent/1.0"


class HttpClient:
    """
    HTTP 客户端类

    提供统一的 HTTP 请求接口，支持重试、代理、SSL 等配置
    """

    DEFAULT_CONFIG = HttpClientConfig()

    def __init__(self, config: Optional[Union[HttpClientConfig, dict]] = None):
        """
        初始化 HTTP 客户端

        Args:
            config: 配置对象或字典
        """
        if isinstance(config, dict):
            self.config = HttpClientConfig(**config)
        else:
            self.config = config or self.DEFAULT_CONFIG

        self._session: Optional[requests.Session] = None
        self._logger = logging.getLogger(__name__)

    def _create_session(self) -> requests.Session:
        """创建配置好的 Session"""
        session = requests.Session()

        # 重试策略
        retry_strategy = Retry(
            total=self.config.max_retries,
            backoff_factor=self.config.retry_delay,
            status_forcelist=[429, 500, 502, 503, 504],
        )

        adapter = HTTPAdapter(
            max_retries=retry_strategy,
            pool_connections=self.config.pool_connections,
            pool_maxsize=self.config.pool_maxsize,
        )

        session.mount("http://", adapter)
        session.mount("https://", adapter)

        # 代理配置
        if self.config.proxy:
            session.proxies = {
                "http": self.config.proxy,
                "https": self.config.proxy,
            }

        # 默认 Headers
        session.headers.update({
            "User-Agent": self.config.user_agent,
        })

        return session

    @property
    def session(self) -> requests.Session:
        """获取 Session（懒加载）"""
        if self._session is None:
            self._session = self._create_session()
        return self._session

    def request(self, method: str, url: str, **kwargs) -> requests.Response:
        """
        发送 HTTP 请求

        Args:
            method: HTTP 方法
            url: 请求 URL
            **kwargs: requests 参数

        Returns:
            Response 对象
        """
        # 默认超时
        if "timeout" not in kwargs:
            kwargs["timeout"] = (
                self.config.connect_timeout,
                self.config.read_timeout
            )

        # SSL 验证
        if "verify" not in kwargs:
            kwargs["verify"] = self.config.ssl_verify

        self._logger.debug(f"Request: {method} {url}")

        response = self.session.request(method, url, **kwargs)

        self._logger.debug(f"Response: {response.status_code}")

        return response

    def get(self, url: str, **kwargs) -> requests.Response:
        """GET 请求"""
        return self.request("GET", url, **kwargs)

    def post(self, url: str, **kwargs) -> requests.Response:
        """POST 请求"""
        return self.request("POST", url, **kwargs)

    def put(self, url: str, **kwargs) -> requests.Response:
        """PUT 请求"""
        return self.request("PUT", url, **kwargs)

    def delete(self, url: str, **kwargs) -> requests.Response:
        """DELETE 请求"""
        return self.request("DELETE", url, **kwargs)

    def close(self):
        """关闭 Session"""
        if self._session:
            self._session.close()
            self._session = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


# 便捷函数
def http_get(url: str, **kwargs) -> requests.Response:
    """便捷 GET 请求"""
    with HttpClient() as client:
        return client.get(url, **kwargs)


def http_post(url: str, **kwargs) -> requests.Response:
    """便捷 POST 请求"""
    with HttpClient() as client:
        return client.post(url, **kwargs)

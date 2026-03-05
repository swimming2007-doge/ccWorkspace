"""
Network Adapter Skill - 网络适配层

功能：
- 统一 HTTP 客户端接口
- 代理支持
- SSL 配置
- 重试机制
- 日志记录

默认配置：
- 超时: 20秒
- 连接池: 10
- SSL 验证: True
- 代理: None
"""

import time
import logging
from dataclasses import dataclass
from typing import Optional, Dict

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


@dataclass
class NetworkConfig:
    """网络配置数据结构"""
    timeout: int = 20
    connect_timeout: int = 10
    read_timeout: int = 20
    max_retries: int = 3
    retry_delay: float = 1.0
    pool_connections: int = 10
    pool_maxsize: int = 10
    proxy: Optional[str] = None
    proxy_http: Optional[str] = None
    proxy_https: Optional[str] = None
    ssl_verify: bool = True
    cert_path: Optional[str] = None
    user_agent: str = "ArXiv-Blog-Agent/1.0"
    log_level: str = "INFO"


class NetworkAdapter:
    """
    网络适配器

    提供统一的 HTTP 客户端接口，支持各种网络环境配置
    """

    DEFAULT_CONFIG = NetworkConfig()

    def __init__(self, config: Optional[dict] = None):
        """
        初始化网络适配器

        Args:
            config: 网络配置字典
        """
        if config:
            self.config = NetworkConfig(**{
                k: v for k, v in config.items()
                if k in NetworkConfig.__dataclass_fields__
            })
        else:
            self.config = self.DEFAULT_CONFIG

        self._session: Optional[requests.Session] = None
        self._logger = logging.getLogger("network_adapter")

    def _create_session(self) -> requests.Session:
        """创建配置好的 HTTP 会话"""
        session = requests.Session()

        retry_strategy = Retry(
            total=self.config.max_retries,
            backoff_factor=self.config.retry_delay,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["HEAD", "GET", "OPTIONS", "POST", "PUT", "DELETE"],
        )

        adapter = HTTPAdapter(
            max_retries=retry_strategy,
            pool_connections=self.config.pool_connections,
            pool_maxsize=self.config.pool_maxsize,
        )

        session.mount("http://", adapter)
        session.mount("https://", adapter)

        proxies = self._build_proxies()
        if proxies:
            session.proxies.update(proxies)

        session.headers.update({
            "User-Agent": self.config.user_agent,
        })

        return session

    def _build_proxies(self) -> Dict[str, str]:
        """构建代理配置"""
        proxies = {}

        if self.config.proxy:
            proxies["http"] = self.config.proxy
            proxies["https"] = self.config.proxy

        if self.config.proxy_http:
            proxies["http"] = self.config.proxy_http
        if self.config.proxy_https:
            proxies["https"] = self.config.proxy_https

        return proxies

    @property
    def session(self) -> requests.Session:
        """获取 HTTP 会话（懒加载）"""
        if self._session is None:
            self._session = self._create_session()
        return self._session

    def request(self, method: str, url: str, **kwargs) -> requests.Response:
        """发送 HTTP 请求"""
        if "timeout" not in kwargs:
            kwargs["timeout"] = (
                self.config.connect_timeout,
                self.config.read_timeout
            )

        if "verify" not in kwargs:
            kwargs["verify"] = self.config.ssl_verify

        if self.config.cert_path and "cert" not in kwargs:
            kwargs["cert"] = self.config.cert_path

        self._logger.debug(f"请求: {method} {url}")

        response = self.session.request(method, url, **kwargs)

        self._logger.debug(f"响应: {response.status_code}")
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
        """关闭会话"""
        if self._session:
            self._session.close()
            self._session = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def test_connectivity(self, test_url: str = "https://httpbin.org/get") -> dict:
        """测试网络连通性"""
        result = {
            "success": False,
            "url": test_url,
            "status_code": None,
            "response_time": None,
            "error": None,
        }

        start_time = time.time()

        try:
            response = self.get(test_url)
            result["status_code"] = response.status_code
            result["response_time"] = time.time() - start_time

            if response.status_code == 200:
                result["success"] = True
            else:
                result["error"] = f"HTTP {response.status_code}"

        except Exception as e:
            result["error"] = str(e)
            result["response_time"] = time.time() - start_time

        return result


# 全局默认适配器
_default_adapter: Optional[NetworkAdapter] = None


def get_default_adapter() -> NetworkAdapter:
    """获取全局默认网络适配器"""
    global _default_adapter
    if _default_adapter is None:
        _default_adapter = NetworkAdapter()
    return _default_adapter


def set_default_adapter(adapter: NetworkAdapter):
    """设置全局默认网络适配器"""
    global _default_adapter
    _default_adapter = adapter

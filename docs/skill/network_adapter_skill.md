# Network Adapter Skill

## 1. Skill 定义

### 1.1 功能描述
网络适配层，提供统一的 HTTP 客户端接口，支持公网/内网环境切换、代理配置、SSL 验证等功能。

### 1.2 核心能力
- **统一 HTTP 客户端**：封装 requests 库，提供一致的接口
- **代理支持**：支持 HTTP/HTTPS/SOCKS 代理
- **SSL 配置**：支持跳过 SSL 验证（内网自签名证书场景）
- **重试机制**：自动重试失败请求
- **日志记录**：请求/响应日志

### 1.3 设计原则
- **配置驱动**：所有网络行为通过配置文件控制
- **环境隔离**：公网/内网配置分离
- **透明代理**：上层业务无需感知网络细节

## 2. 实现代码

```python
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
from typing import Optional, Dict, Any, Union
from urllib.parse import urlparse

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

    def __init__(self, config: Optional[Union[NetworkConfig, dict]] = None):
        """
        初始化网络适配器

        Args:
            config: 网络配置，可以是 NetworkConfig 对象或字典
        """
        if isinstance(config, dict):
            self.config = NetworkConfig(**config)
        else:
            self.config = config or self.DEFAULT_CONFIG

        self._session: Optional[requests.Session] = None
        self._logger = self._setup_logger()

    def _setup_logger(self) -> logging.Logger:
        """设置日志器"""
        logger = logging.getLogger("network_adapter")
        logger.setLevel(getattr(logging, self.config.log_level, logging.INFO))

        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)

        return logger

    def _create_session(self) -> requests.Session:
        """创建配置好的 HTTP 会话"""
        session = requests.Session()

        # 配置重试策略
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

        # 配置代理
        proxies = self._build_proxies()
        if proxies:
            session.proxies.update(proxies)
            self._logger.info(f"代理已配置: {list(proxies.keys())}")

        # 配置默认 headers
        session.headers.update({
            "User-Agent": self.config.user_agent,
        })

        return session

    def _build_proxies(self) -> Dict[str, str]:
        """构建代理配置"""
        proxies = {}

        # 通用代理
        if self.config.proxy:
            proxies["http"] = self.config.proxy
            proxies["https"] = self.config.proxy

        # 分别配置的代理
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
        """
        发送 HTTP 请求

        Args:
            method: HTTP 方法
            url: 请求 URL
            **kwargs: 额外参数传递给 requests

        Returns:
            requests.Response: 响应对象
        """
        # 设置超时
        if "timeout" not in kwargs:
            kwargs["timeout"] = (
                self.config.connect_timeout,
                self.config.read_timeout
            )

        # SSL 验证
        if "verify" not in kwargs:
            kwargs["verify"] = self.config.ssl_verify

        # 客户端证书
        if self.config.cert_path and "cert" not in kwargs:
            kwargs["cert"] = self.config.cert_path

        self._logger.debug(f"请求: {method} {url}")

        try:
            response = self.session.request(method, url, **kwargs)
            self._logger.debug(f"响应: {response.status_code}")
            return response

        except requests.exceptions.SSLError as e:
            self._logger.error(f"SSL 错误: {e}")
            raise

        except requests.exceptions.ProxyError as e:
            self._logger.error(f"代理错误: {e}")
            raise

        except requests.exceptions.ConnectTimeout as e:
            self._logger.error(f"连接超时: {e}")
            raise

        except requests.exceptions.ReadTimeout as e:
            self._logger.error(f"读取超时: {e}")
            raise

        except requests.exceptions.RequestException as e:
            self._logger.error(f"请求异常: {e}")
            raise

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

    def head(self, url: str, **kwargs) -> requests.Response:
        """HEAD 请求"""
        return self.request("HEAD", url, **kwargs)

    def close(self):
        """关闭会话"""
        if self._session:
            self._session.close()
            self._session = None
            self._logger.info("HTTP 会话已关闭")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def test_connectivity(self, test_url: str = "https://httpbin.org/get") -> dict:
        """
        测试网络连通性

        Args:
            test_url: 测试 URL

        Returns:
            dict: 测试结果
        """
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


# 全局默认适配器实例
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
```

## 3. 使用示例

### 3.1 基础用法
```python
from skills.network_adapter import NetworkAdapter

# 使用默认配置
adapter = NetworkAdapter()

# GET 请求
response = adapter.get("https://api.example.com/data")
print(response.json())

# POST 请求
response = adapter.post(
    "https://api.example.com/create",
    json={"name": "test"}
)

# 关闭连接
adapter.close()
```

### 3.2 上下文管理器
```python
# 使用 with 语句自动管理连接
with NetworkAdapter() as adapter:
    response = adapter.get("https://api.example.com/data")
    print(response.json())
```

### 3.3 代理配置
```python
# 配置代理
config = {
    "proxy": "http://proxy.example.com:8080",
    "timeout": 30,
}

adapter = NetworkAdapter(config)
response = adapter.get("https://api.example.com/data")
```

### 3.4 内网配置（跳过 SSL）
```python
# 内网环境配置
internal_config = {
    "proxy": "http://internal-proxy:8080",
    "ssl_verify": False,  # 跳过 SSL 验证
    "timeout": 60,
    "user_agent": "Internal-Agent/1.0",
}

adapter = NetworkAdapter(internal_config)
```

### 3.5 测试网络连通性
```python
adapter = NetworkAdapter()
result = adapter.test_connectivity()

if result["success"]:
    print(f"网络正常，响应时间: {result['response_time']:.2f}s")
else:
    print(f"网络异常: {result['error']}")
```

## 4. 配置说明

### 4.1 公网配置
```yaml
# configs/config.yaml
network:
  timeout: 20
  connect_timeout: 10
  read_timeout: 20
  max_retries: 3
  retry_delay: 1.0
  pool_connections: 10
  pool_maxsize: 10
  proxy: null
  ssl_verify: true
  user_agent: "ArXiv-Blog-Agent/1.0"
  log_level: "INFO"
```

### 4.2 内网配置
```yaml
# configs/prod_config.yaml
network:
  timeout: 60
  connect_timeout: 30
  read_timeout: 60
  max_retries: 5
  retry_delay: 2.0
  pool_connections: 20
  pool_maxsize: 20

  # 内网代理
  proxy: "http://internal-proxy:8080"
  # 或分别配置
  # proxy_http: "http://internal-proxy:8080"
  # proxy_https: "http://internal-proxy:8443"

  # SSL 配置（内网自签名证书）
  ssl_verify: false
  # 或指定证书路径
  # cert_path: "/path/to/cert.pem"

  user_agent: "Internal-Blog-Agent/1.0"
  log_level: "DEBUG"
```

## 5. 与其他 Skill 集成

```python
from skills.network_adapter import NetworkAdapter
from skills.arxiv_scraper import ArXivScraperSkill

# 创建网络适配器
network = NetworkAdapter({
    "proxy": "http://internal-proxy:8080",
    "ssl_verify": False,
})

# 将网络适配器注入到其他 Skill
scraper = ArXivScraperSkill({
    "session": network.session,  # 复用会话
    "timeout": 30,
})
```

## 6. 错误处理

| 异常类型 | 说明 | 处理建议 |
|---------|------|---------|
| SSLError | SSL 证书验证失败 | 设置 ssl_verify=False 或添加证书 |
| ProxyError | 代理连接失败 | 检查代理地址和端口 |
| ConnectTimeout | 连接超时 | 增加超时时间或检查网络 |
| ReadTimeout | 读取超时 | 增加读取超时时间 |
| ConnectionError | 连接失败 | 检查目标地址和网络连通性 |

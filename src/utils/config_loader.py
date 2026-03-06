"""
配置加载器 - 集中式配置管理

功能：
- 从单一 YAML 文件加载所有配置
- 支持环境变量覆盖
- 提供默认值
"""

import os
import re
from typing import Any, Dict, Optional
from dataclasses import dataclass, field

import yaml


@dataclass
class ArxivConfig:
    """ArXiv 爬取配置"""
    query: str = "large model training inference"
    max_results: int = 10
    api_url: str = "https://export.arxiv.org/api/query"
    timeout: int = 30
    max_retries: int = 3
    retry_delay: int = 3
    proxy: Optional[str] = None
    ssl_verify: bool = True


@dataclass
class ContentConfig:
    """内容生成配置"""
    style: str = "professional"
    language: str = "zh"
    title_prefix: str = "ArXiv 大模型训推进展 - "
    category: str = "AI/大模型"
    max_abstract_length: int = 300
    include_pdf_link: bool = True


@dataclass
class BlogConfig:
    """博客发布配置"""
    api_base: str = "https://public-api.wordpress.com/rest/v1.1"
    blog_id: str = "791025341"
    blog_url: str = "https://swimming2007.wordpress.com/"
    access_token: str = ""
    status: str = "publish"
    timeout: int = 20
    max_retries: int = 3
    retry_delay: int = 2
    proxy: Optional[str] = None
    ssl_verify: bool = True


@dataclass
class NetworkConfig:
    """网络配置"""
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
    user_agent: str = "ArXiv-Blog-Agent/1.0"


@dataclass
class LoggingConfig:
    """日志配置"""
    level: str = "INFO"
    file: str = "./logs/agent.log"
    format: str = "[%(asctime)s] %(levelname)s [%(name)s] %(message)s"
    console_level: str = "INFO"
    file_level: str = "DEBUG"


@dataclass
class AgentConfigData:
    """Agent 配置"""
    dry_run: bool = False
    checkpoint_file: str = "./logs/checkpoint.json"


@dataclass
class Config:
    """集中式配置"""
    arxiv: ArxivConfig = field(default_factory=ArxivConfig)
    content: ContentConfig = field(default_factory=ContentConfig)
    blog: BlogConfig = field(default_factory=BlogConfig)
    network: NetworkConfig = field(default_factory=NetworkConfig)
    logging: LoggingConfig = field(default_factory=LoggingConfig)
    agent: AgentConfigData = field(default_factory=AgentConfigData)


def expand_env_vars(value: Any) -> Any:
    """
    展开环境变量

    支持 ${VAR_NAME} 格式
    """
    if isinstance(value, str):
        # 匹配 ${VAR_NAME} 格式
        pattern = r'\$\{([^}]+)\}'
        matches = re.findall(pattern, value)

        for var_name in matches:
            env_value = os.getenv(var_name, "")
            value = value.replace(f"${{{var_name}}}", env_value)

        return value
    elif isinstance(value, dict):
        return {k: expand_env_vars(v) for k, v in value.items()}
    elif isinstance(value, list):
        return [expand_env_vars(item) for item in value]
    else:
        return value


def load_config(config_path: str = "config.yaml") -> Config:
    """
    加载配置文件

    Args:
        config_path: 配置文件路径

    Returns:
        Config: 配置对象
    """
    # 默认配置
    config = Config()

    # 尝试加载配置文件
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                raw_config = yaml.safe_load(f) or {}

            # 展开环境变量
            raw_config = expand_env_vars(raw_config)

            # 解析各模块配置
            if "arxiv" in raw_config:
                arxiv_data = raw_config["arxiv"]
                config.arxiv = ArxivConfig(
                    query=arxiv_data.get("query", config.arxiv.query),
                    max_results=arxiv_data.get("max_results", config.arxiv.max_results),
                    api_url=arxiv_data.get("api_url", config.arxiv.api_url),
                    timeout=arxiv_data.get("timeout", config.arxiv.timeout),
                    max_retries=arxiv_data.get("max_retries", config.arxiv.max_retries),
                    retry_delay=arxiv_data.get("retry_delay", config.arxiv.retry_delay),
                    proxy=arxiv_data.get("proxy", config.arxiv.proxy),
                    ssl_verify=arxiv_data.get("ssl_verify", config.arxiv.ssl_verify),
                )

            if "content" in raw_config:
                content_data = raw_config["content"]
                config.content = ContentConfig(
                    style=content_data.get("style", config.content.style),
                    language=content_data.get("language", config.content.language),
                    title_prefix=content_data.get("title_prefix", config.content.title_prefix),
                    category=content_data.get("category", config.content.category),
                    max_abstract_length=content_data.get("max_abstract_length", config.content.max_abstract_length),
                    include_pdf_link=content_data.get("include_pdf_link", config.content.include_pdf_link),
                )

            if "blog" in raw_config:
                blog_data = raw_config["blog"]
                config.blog = BlogConfig(
                    api_base=blog_data.get("api_base", config.blog.api_base),
                    blog_id=blog_data.get("blog_id", config.blog.blog_id),
                    blog_url=blog_data.get("blog_url", config.blog.blog_url),
                    access_token=blog_data.get("access_token", config.blog.access_token),
                    status=blog_data.get("status", config.blog.status),
                    timeout=blog_data.get("timeout", config.blog.timeout),
                    max_retries=blog_data.get("max_retries", config.blog.max_retries),
                    retry_delay=blog_data.get("retry_delay", config.blog.retry_delay),
                    proxy=blog_data.get("proxy", config.blog.proxy),
                    ssl_verify=blog_data.get("ssl_verify", config.blog.ssl_verify),
                )

            if "network" in raw_config:
                network_data = raw_config["network"]
                config.network = NetworkConfig(
                    timeout=network_data.get("timeout", config.network.timeout),
                    connect_timeout=network_data.get("connect_timeout", config.network.connect_timeout),
                    read_timeout=network_data.get("read_timeout", config.network.read_timeout),
                    max_retries=network_data.get("max_retries", config.network.max_retries),
                    retry_delay=network_data.get("retry_delay", config.network.retry_delay),
                    pool_connections=network_data.get("pool_connections", config.network.pool_connections),
                    pool_maxsize=network_data.get("pool_maxsize", config.network.pool_maxsize),
                    proxy=network_data.get("proxy", config.network.proxy),
                    proxy_http=network_data.get("proxy_http", config.network.proxy_http),
                    proxy_https=network_data.get("proxy_https", config.network.proxy_https),
                    ssl_verify=network_data.get("ssl_verify", config.network.ssl_verify),
                    user_agent=network_data.get("user_agent", config.network.user_agent),
                )

            if "logging" in raw_config:
                logging_data = raw_config["logging"]
                config.logging = LoggingConfig(
                    level=logging_data.get("level", config.logging.level),
                    file=logging_data.get("file", config.logging.file),
                    format=logging_data.get("format", config.logging.format),
                    console_level=logging_data.get("console_level", config.logging.console_level),
                    file_level=logging_data.get("file_level", config.logging.file_level),
                )

            if "agent" in raw_config:
                agent_data = raw_config["agent"]
                config.agent = AgentConfigData(
                    dry_run=agent_data.get("dry_run", config.agent.dry_run),
                    checkpoint_file=agent_data.get("checkpoint_file", config.agent.checkpoint_file),
                )

        except Exception as e:
            print(f"Warning: Failed to load config file: {e}")
    else:
        print(f"Warning: Config file not found: {config_path}, using defaults")

    return config


def get_config_dict(config: Config) -> Dict[str, Any]:
    """
    将配置对象转换为字典格式

    Args:
        config: 配置对象

    Returns:
        Dict: 配置字典
    """
    from dataclasses import asdict
    return {
        "arxiv": asdict(config.arxiv),
        "content": asdict(config.content),
        "blog": asdict(config.blog),
        "network": asdict(config.network),
        "logging": asdict(config.logging),
        "agent": asdict(config.agent),
    }

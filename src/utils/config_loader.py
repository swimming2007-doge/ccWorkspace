"""
配置加载器 - 集中式配置管理

功能：
- 从单一 YAML 文件加载所有配置
- 支持环境变量覆盖
- 所有配置必须从 YAML 文件获取
"""

import os
import re
from typing import Any, Dict, Optional
from dataclasses import dataclass, field

import yaml


@dataclass
class ArxivConfig:
    """ArXiv 爬取配置"""
    query: str = ""
    max_results: int = 0
    api_url: str = ""
    timeout: int = 0
    max_retries: int = 0
    retry_delay: int = 0
    proxy: Optional[str] = None
    ssl_verify: bool = True


@dataclass
class AIConfig:
    """AI 内容生成配置"""
    provider: str = ""
    api_key: str = ""
    model: str = ""
    temperature: float = 0.7
    max_tokens: int = 4000
    timeout: int = 60


@dataclass
class ContentConfig:
    """内容生成配置"""
    style: str = ""
    language: str = ""
    title_prefix: str = ""
    category: str = ""
    max_abstract_length: int = 0
    include_pdf_link: bool = True


@dataclass
class BlogConfig:
    """博客发布配置 - 所有参数必须从 config.yaml 获取"""
    api_base: str = ""
    blog_id: str = ""
    blog_url: str = ""
    access_token: str = ""
    status: str = ""
    default_category: str = ""
    timeout: int = 0
    max_retries: int = 0
    retry_delay: int = 0
    proxy: Optional[str] = None
    ssl_verify: bool = True


@dataclass
class LoggingConfig:
    """日志配置"""
    level: str = ""
    file: str = ""
    format: str = ""


@dataclass
class AgentConfigData:
    """Agent 配置"""
    dry_run: bool = False


@dataclass
class Config:
    """集中式配置"""
    arxiv: ArxivConfig = field(default_factory=ArxivConfig)
    ai: AIConfig = field(default_factory=AIConfig)
    content: ContentConfig = field(default_factory=ContentConfig)
    blog: BlogConfig = field(default_factory=BlogConfig)
    logging: LoggingConfig = field(default_factory=LoggingConfig)
    agent: AgentConfigData = field(default_factory=AgentConfigData)


def expand_env_vars(value: Any) -> Any:
    """
    展开环境变量

    支持 ${VAR_NAME} 格式
    """
    if isinstance(value, str):
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


def _validate_required_config(config_name: str, data: dict, required_keys: list):
    """验证必需的配置项"""
    missing = [k for k in required_keys if k not in data or data[k] is None or data[k] == ""]
    if missing:
        raise ValueError(f"[{config_name}] 缺少必需配置项: {missing}")


def load_config(config_path: str = "config.yaml") -> Config:
    """
    加载配置文件

    Args:
        config_path: 配置文件路径

    Returns:
        Config: 配置对象

    Raises:
        FileNotFoundError: 配置文件不存在
        ValueError: 缺少必需配置项
    """
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"配置文件不存在: {config_path}")

    with open(config_path, "r", encoding="utf-8") as f:
        raw_config = yaml.safe_load(f)

    if not raw_config:
        raise ValueError(f"配置文件为空: {config_path}")

    # 展开环境变量
    raw_config = expand_env_vars(raw_config)

    config = Config()

    # 验证并加载 ArXiv 配置
    if "arxiv" not in raw_config:
        raise ValueError("配置文件缺少 'arxiv' 配置节")
    arxiv_data = raw_config["arxiv"]
    _validate_required_config("arxiv", arxiv_data,
        ["query", "max_results", "api_url", "timeout", "max_retries", "retry_delay"])
    config.arxiv = ArxivConfig(
        query=arxiv_data["query"],
        max_results=arxiv_data["max_results"],
        api_url=arxiv_data["api_url"],
        timeout=arxiv_data["timeout"],
        max_retries=arxiv_data["max_retries"],
        retry_delay=arxiv_data["retry_delay"],
        proxy=arxiv_data.get("proxy"),
        ssl_verify=arxiv_data.get("ssl_verify", True),
    )

    # 验证并加载 AI 配置（可选）
    if "ai" in raw_config:
        ai_data = raw_config["ai"]
        config.ai = AIConfig(
            provider=ai_data.get("provider", "zhipu"),
            api_key=ai_data.get("api_key", ""),
            model=ai_data.get("model", "glm-4-flash"),
            temperature=ai_data.get("temperature", 0.7),
            max_tokens=ai_data.get("max_tokens", 4000),
            timeout=ai_data.get("timeout", 60),
        )

    # 验证并加载 Content 配置
    if "content" not in raw_config:
        raise ValueError("配置文件缺少 'content' 配置节")
    content_data = raw_config["content"]
    _validate_required_config("content", content_data,
        ["style", "language", "title_prefix", "category", "max_abstract_length"])
    config.content = ContentConfig(
        style=content_data["style"],
        language=content_data["language"],
        title_prefix=content_data["title_prefix"],
        category=content_data["category"],
        max_abstract_length=content_data["max_abstract_length"],
        include_pdf_link=content_data.get("include_pdf_link", True),
    )

    # 验证并加载 Blog 配置
    if "blog" not in raw_config:
        raise ValueError("配置文件缺少 'blog' 配置节")
    blog_data = raw_config["blog"]
    _validate_required_config("blog", blog_data,
        ["api_base", "blog_id", "blog_url", "access_token", "status",
         "default_category", "timeout", "max_retries", "retry_delay"])
    config.blog = BlogConfig(
        api_base=blog_data["api_base"],
        blog_id=blog_data["blog_id"],
        blog_url=blog_data["blog_url"],
        access_token=blog_data["access_token"],
        status=blog_data["status"],
        default_category=blog_data["default_category"],
        timeout=blog_data["timeout"],
        max_retries=blog_data["max_retries"],
        retry_delay=blog_data["retry_delay"],
        proxy=blog_data.get("proxy"),
        ssl_verify=blog_data.get("ssl_verify", True),
    )

    # 验证并加载 Logging 配置
    if "logging" not in raw_config:
        raise ValueError("配置文件缺少 'logging' 配置节")
    logging_data = raw_config["logging"]
    _validate_required_config("logging", logging_data, ["level", "file", "format"])
    config.logging = LoggingConfig(
        level=logging_data["level"],
        file=logging_data["file"],
        format=logging_data["format"],
    )

    # 验证并加载 Agent 配置
    if "agent" not in raw_config:
        raise ValueError("配置文件缺少 'agent' 配置节")
    agent_data = raw_config["agent"]
    config.agent = AgentConfigData(
        dry_run=agent_data.get("dry_run", False),
    )

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
        "ai": asdict(config.ai),
        "content": asdict(config.content),
        "blog": asdict(config.blog),
        "logging": asdict(config.logging),
        "agent": asdict(config.agent),
    }

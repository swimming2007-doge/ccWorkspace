"""
Logger - 日志工具

功能：
- 统一的日志配置
- 控制台和文件输出
- 日志级别控制
"""

import os
import logging
import sys
from datetime import datetime
from typing import Optional


def setup_logger(
    name: str = "arxiv_blog_agent",
    level: str = "INFO",
    log_file: Optional[str] = None,
    format_string: Optional[str] = None,
) -> logging.Logger:
    """
    设置日志器

    Args:
        name: 日志器名称
        level: 日志级别 (DEBUG/INFO/WARNING/ERROR)
        log_file: 日志文件路径
        format_string: 日志格式

    Returns:
        配置好的 Logger
    """
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))

    # 清除已有处理器
    logger.handlers.clear()

    # 默认格式
    if format_string is None:
        format_string = "[%(asctime)s] %(levelname)s [%(name)s.%(funcName)s:%(lineno)d] %(message)s"

    formatter = logging.Formatter(format_string)

    # 控制台处理器
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # 文件处理器
    if log_file:
        # 确保日志目录存在
        log_dir = os.path.dirname(log_file)
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)

        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

    return logger


def get_logger(name: str = "arxiv_blog_agent") -> logging.Logger:
    """
    获取日志器

    Args:
        name: 日志器名称

    Returns:
        Logger 实例
    """
    return logging.getLogger(name)


class LoggerMixin:
    """日志混入类，为类提供日志功能"""

    @property
    def logger(self) -> logging.Logger:
        if not hasattr(self, "_logger"):
            self._logger = get_logger(self.__class__.__module__)
        return self._logger


# 默认日志配置
DEFAULT_LOG_FILE = "./logs/agent.log"


def init_default_logger():
    """初始化默认日志器"""
    return setup_logger(
        name="arxiv_blog_agent",
        level="INFO",
        log_file=DEFAULT_LOG_FILE,
    )

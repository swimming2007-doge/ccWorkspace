"""
ArXiv Blog Agent - 主 Agent 类

功能：
- 协调各 Skill 完成论文爬取、内容生成、博客发布
- 状态管理和错误处理
- 支持公网/内网环境

使用方法：
    agent = ArXivBlogAgent()
    result = agent.run()
"""

import os
import json
import logging
from dataclasses import dataclass, field, asdict
from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict, Any

import yaml

from skills.arxiv_scraper import ArXivScraperSkill, ArXivPaper, ScraperResult
from skills.content_generator import ContentGeneratorSkill, BlogContent, GeneratorResult
from skills.blog_poster import BlogPosterSkill, MockBlogPosterSkill, PostResult


class AgentState(Enum):
    """Agent 状态枚举"""
    IDLE = "idle"
    INITIALIZING = "initializing"
    SCRAPING = "scraping"
    GENERATING = "generating"
    POSTING = "posting"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class AgentStatus:
    """Agent 状态"""
    state: AgentState = AgentState.IDLE
    current_step: str = ""
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    error: Optional[str] = None
    papers_count: int = 0
    post_url: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "state": self.state.value,
            "current_step": self.current_step,
            "start_time": self.start_time.isoformat() if self.start_time else None,
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "error": self.error,
            "papers_count": self.papers_count,
            "post_url": self.post_url,
        }


@dataclass
class AgentConfig:
    """Agent 配置"""
    arxiv_query: str = "large model training inference"
    arxiv_max_results: int = 10
    content_style: str = "professional"
    content_language: str = "zh"
    title_prefix: str = "ArXiv 大模型训推进展 - "
    blog_status: str = "publish"
    dry_run: bool = False
    log_level: str = "INFO"


@dataclass
class AgentResult:
    """Agent 执行结果"""
    success: bool
    papers: List[ArXivPaper] = field(default_factory=list)
    blog_content: Optional[BlogContent] = None
    post_url: str = ""
    duration: float = 0.0
    error_message: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "success": self.success,
            "papers_count": len(self.papers),
            "post_url": self.post_url,
            "duration": self.duration,
            "error_message": self.error_message,
        }


class ArXivBlogAgent:
    """
    ArXiv Blog Agent

    自动化工作流：
    1. 爬取 ArXiv 论文
    2. 生成博客文案
    3. 发布到 WordPress
    """

    DEFAULT_CONFIG_PATH = "configs/config.yaml"

    def __init__(self, config_path: str = None, config: Dict = None,
                 dry_run: bool = False):
        """
        初始化 Agent

        Args:
            config_path: 配置文件路径
            config: 配置字典（优先级高于配置文件）
            dry_run: 干运行模式（不实际发布）
        """
        self.config = self._load_config(config_path, config)
        self.config.dry_run = dry_run

        self.status = AgentStatus()
        self.skills: Dict[str, Any] = {}

        self._setup_logger()
        self._register_skills()

    def _load_config(self, config_path: str = None,
                     config_dict: Dict = None) -> AgentConfig:
        """加载配置"""
        # 从配置文件加载
        config_data = {}

        path = config_path or self.DEFAULT_CONFIG_PATH
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    config_data = yaml.safe_load(f) or {}
            except Exception:
                pass

        # 从字典覆盖
        if config_dict:
            config_data.update(config_dict)

        # 提取 Agent 配置
        agent_config = config_data.get("agent", {})

        return AgentConfig(
            arxiv_query=agent_config.get("arxiv_query", "large model training inference"),
            arxiv_max_results=agent_config.get("arxiv_max_results", 10),
            content_style=agent_config.get("content_style", "professional"),
            content_language=agent_config.get("content_language", "zh"),
            title_prefix=agent_config.get("title_prefix", "ArXiv 大模型训推进展 - "),
            blog_status=agent_config.get("blog_status", "publish"),
            dry_run=agent_config.get("dry_run", False),
            log_level=agent_config.get("log_level", "INFO"),
        )

    def _setup_logger(self):
        """设置日志"""
        self.logger = logging.getLogger("arxiv_blog_agent")
        self.logger.setLevel(getattr(logging, self.config.log_level, logging.INFO))

        if not self.logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                "[%(asctime)s] %(levelname)s [%(name)s] %(message)s"
            )
            handler.setFormatter(formatter)
            self.logger.addHandler(handler)

    def _register_skills(self):
        """注册技能"""
        self.skills["arxiv_scraper"] = ArXivScraperSkill()
        self.skills["content_generator"] = ContentGeneratorSkill()
        self.skills["blog_poster"] = BlogPosterSkill()
        self.skills["mock_blog_poster"] = MockBlogPosterSkill()

    def _step_scrape(self) -> ScraperResult:
        """Step 1: 爬取论文"""
        self.status.state = AgentState.SCRAPING
        self.status.current_step = "scrape"
        self.logger.info("=" * 50)
        self.logger.info("Step 1: 开始爬取 ArXiv 论文...")

        result = self.skills["arxiv_scraper"].execute(
            query=self.config.arxiv_query,
            max_results=self.config.arxiv_max_results,
        )

        if result.success:
            self.status.papers_count = len(result.papers)
            self.logger.info(f"爬取完成，获取 {len(result.papers)} 篇论文")
        else:
            self.logger.error(f"爬取失败: {result.error_message}")

        return result

    def _step_generate(self, papers: List[ArXivPaper]) -> GeneratorResult:
        """Step 2: 生成文案"""
        self.status.state = AgentState.GENERATING
        self.status.current_step = "generate"
        self.logger.info("-" * 50)
        self.logger.info("Step 2: 开始生成博客文案...")

        if not papers:
            return GeneratorResult(success=False, error_message="论文列表为空")

        result = self.skills["content_generator"].execute(
            papers=papers,
            style=self.config.content_style,
            language=self.config.content_language,
            title_prefix=self.config.title_prefix,
        )

        if result.success:
            self.logger.info("文案生成完成")
        else:
            self.logger.error(f"生成失败: {result.error_message}")

        return result

    def _step_post(self, blog_content: BlogContent) -> PostResult:
        """Step 3: 发布博客"""
        self.status.state = AgentState.POSTING
        self.status.current_step = "post"
        self.logger.info("-" * 50)
        self.logger.info("Step 3: 开始发布博客...")

        if self.config.dry_run:
            self.logger.info("干运行模式，使用模拟发布")
            result = self.skills["mock_blog_poster"].execute(blog_content)
        else:
            result = self.skills["blog_poster"].execute(
                blog_content=blog_content,
                status=self.config.blog_status,
            )

        if result.success:
            self.status.post_url = result.post_url
            self.logger.info(f"发布成功: {result.post_url}")
        else:
            self.logger.error(f"发布失败: {result.error_message}")

        return result

    def run(self) -> AgentResult:
        """
        执行完整工作流

        Returns:
            AgentResult: 执行结果
        """
        self.status.start_time = datetime.now()
        self.status.state = AgentState.INITIALIZING

        self.logger.info("=" * 50)
        self.logger.info("ArXiv Blog Agent 启动")
        self.logger.info(f"搜索关键词: {self.config.arxiv_query}")
        self.logger.info(f"最大结果数: {self.config.arxiv_max_results}")
        self.logger.info(f"干运行模式: {self.config.dry_run}")
        self.logger.info("=" * 50)

        try:
            # Stage 1: 爬取
            scrape_result = self._step_scrape()
            if not scrape_result.success:
                self.status.state = AgentState.FAILED
                self.status.end_time = datetime.now()
                return AgentResult(
                    success=False,
                    error_message=f"爬取失败: {scrape_result.error_message}",
                    duration=(self.status.end_time - self.status.start_time).total_seconds(),
                )

            # Stage 2: 生成
            generate_result = self._step_generate(scrape_result.papers)
            if not generate_result.success:
                self.status.state = AgentState.FAILED
                self.status.end_time = datetime.now()
                return AgentResult(
                    success=False,
                    papers=scrape_result.papers,
                    error_message=f"生成失败: {generate_result.error_message}",
                    duration=(self.status.end_time - self.status.start_time).total_seconds(),
                )

            # Stage 3: 发布
            post_result = self._step_post(generate_result.blog_content)
            if not post_result.success:
                self.status.state = AgentState.FAILED
                self.status.end_time = datetime.now()
                return AgentResult(
                    success=False,
                    papers=scrape_result.papers,
                    blog_content=generate_result.blog_content,
                    error_message=f"发布失败: {post_result.error_message}",
                    duration=(self.status.end_time - self.status.start_time).total_seconds(),
                )

            # 成功完成
            self.status.state = AgentState.COMPLETED
            self.status.end_time = datetime.now()

            self.logger.info("=" * 50)
            self.logger.info("工作流执行成功!")
            self.logger.info(f"处理论文数: {len(scrape_result.papers)}")
            self.logger.info(f"发布地址: {post_result.post_url}")
            self.logger.info(f"执行时间: {(self.status.end_time - self.status.start_time).total_seconds():.2f}s")
            self.logger.info("=" * 50)

            return AgentResult(
                success=True,
                papers=scrape_result.papers,
                blog_content=generate_result.blog_content,
                post_url=post_result.post_url,
                duration=(self.status.end_time - self.status.start_time).total_seconds(),
            )

        except Exception as e:
            self.status.state = AgentState.FAILED
            self.status.end_time = datetime.now()
            self.logger.exception("工作流执行异常")
            return AgentResult(
                success=False,
                error_message=str(e),
                duration=(self.status.end_time - self.status.start_time).total_seconds(),
            )

    def get_status(self) -> Dict[str, Any]:
        """获取当前状态"""
        return self.status.to_dict()

    def close(self):
        """清理资源"""
        for skill in self.skills.values():
            if hasattr(skill, "close"):
                skill.close()


def main():
    """主函数"""
    import argparse

    parser = argparse.ArgumentParser(description="ArXiv Blog Agent")
    parser.add_argument("--config", "-c", help="配置文件路径")
    parser.add_argument("--dry-run", "-d", action="store_true", help="干运行模式")
    parser.add_argument("--query", "-q", help="搜索关键词")
    parser.add_argument("--max-results", "-m", type=int, help="最大结果数")

    args = parser.parse_args()

    config_override = {}
    if args.query:
        config_override["arxiv_query"] = args.query
    if args.max_results:
        config_override["arxiv_max_results"] = args.max_results

    agent = ArXivBlogAgent(
        config_path=args.config,
        config=config_override if config_override else None,
        dry_run=args.dry_run,
    )

    result = agent.run()
    agent.close()

    print("\n" + "=" * 50)
    print("执行结果:")
    print(json.dumps(result.to_dict(), indent=2, ensure_ascii=False))

    return 0 if result.success else 1


if __name__ == "__main__":
    exit(main())

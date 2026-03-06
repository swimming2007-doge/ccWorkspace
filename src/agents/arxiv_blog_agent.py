"""
ArXiv Blog Agent - 主 Agent 类

使用集中式配置文件 (config.yaml)
"""

import os
import json
import logging
from dataclasses import dataclass, field, asdict
from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict, Any

from utils.config_loader import load_config, Config, get_config_dict
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

    使用集中式配置文件 (config.yaml)
    """

    DEFAULT_CONFIG_PATH = "config.yaml"

    def __init__(self, config_path: str = None, dry_run: bool = False):
        """
        初始化 Agent

        Args:
            config_path: 配置文件路径（默认 config.yaml）
            dry_run: 干运行模式（覆盖配置文件设置）
        """
        # 加载配置
        self.config_path = config_path or self.DEFAULT_CONFIG_PATH
        self.config: Config = load_config(self.config_path)

        # 覆盖干运行模式
        if dry_run:
            self.config.agent.dry_run = True

        self.status = AgentStatus()
        self.skills: Dict[str, Any] = {}

        self._setup_logger()
        self._register_skills()

    def _setup_logger(self):
        """设置日志"""
        self.logger = logging.getLogger("arxiv_blog_agent")
        self.logger.setLevel(getattr(logging, self.config.logging.level, logging.INFO))

        if not self.logger.handlers:
            # 控制台处理器
            handler = logging.StreamHandler()
            formatter = logging.Formatter(self.config.logging.format)
            handler.setFormatter(formatter)
            self.logger.addHandler(handler)

    def _register_skills(self):
        """注册技能"""
        # 获取配置字典
        config_dict = get_config_dict(self.config)

        # 注册各 Skill
        self.skills["arxiv_scraper"] = ArXivScraperSkill(config_dict["arxiv"])
        self.skills["content_generator"] = ContentGeneratorSkill(config_dict["content"])
        self.skills["blog_poster"] = BlogPosterSkill(config_dict["blog"])
        self.skills["mock_blog_poster"] = MockBlogPosterSkill(config_dict["blog"])

    def _step_scrape(self) -> ScraperResult:
        """Step 1: 爬取论文"""
        self.status.state = AgentState.SCRAPING
        self.status.current_step = "scrape"
        self.logger.info("=" * 50)
        self.logger.info("Step 1: Crawling ArXiv papers...")

        result = self.skills["arxiv_scraper"].execute(
            query=self.config.arxiv.query,
            max_results=self.config.arxiv.max_results,
        )

        if result.success:
            self.status.papers_count = len(result.papers)
            self.logger.info(f"Crawled {len(result.papers)} papers")
        else:
            self.logger.error(f"Crawl failed: {result.error_message}")

        return result

    def _step_generate(self, papers: List[ArXivPaper]) -> GeneratorResult:
        """Step 2: 生成文案"""
        self.status.state = AgentState.GENERATING
        self.status.current_step = "generate"
        self.logger.info("-" * 50)
        self.logger.info("Step 2: Generating blog content...")

        if not papers:
            return GeneratorResult(success=False, error_message="No papers to generate")

        result = self.skills["content_generator"].execute(
            papers=papers,
            style=self.config.content.style,
            language=self.config.content.language,
            title_prefix=self.config.content.title_prefix,
        )

        if result.success:
            self.logger.info("Content generated")
        else:
            self.logger.error(f"Generation failed: {result.error_message}")

        return result

    def _step_post(self, blog_content: BlogContent) -> PostResult:
        """Step 3: 发布博客"""
        self.status.state = AgentState.POSTING
        self.status.current_step = "post"
        self.logger.info("-" * 50)
        self.logger.info("Step 3: Posting blog...")

        if self.config.agent.dry_run:
            self.logger.info("Dry run mode, using mock poster")
            result = self.skills["mock_blog_poster"].execute(blog_content)
        else:
            result = self.skills["blog_poster"].execute(
                blog_content=blog_content,
                status=self.config.blog.status,
            )

        if result.success:
            self.status.post_url = result.post_url
            self.logger.info(f"Posted: {result.post_url}")
        else:
            self.logger.error(f"Post failed: {result.error_message}")

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
        self.logger.info("ArXiv Blog Agent Started")
        self.logger.info(f"Query: {self.config.arxiv.query}")
        self.logger.info(f"Max results: {self.config.arxiv.max_results}")
        self.logger.info(f"Dry run: {self.config.agent.dry_run}")
        self.logger.info(f"Style: {self.config.content.style}")
        self.logger.info("=" * 50)

        try:
            # Stage 1: 爬取
            scrape_result = self._step_scrape()
            if not scrape_result.success:
                self.status.state = AgentState.FAILED
                self.status.end_time = datetime.now()
                return AgentResult(
                    success=False,
                    error_message=f"Crawl failed: {scrape_result.error_message}",
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
                    error_message=f"Generation failed: {generate_result.error_message}",
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
                    error_message=f"Post failed: {post_result.error_message}",
                    duration=(self.status.end_time - self.status.start_time).total_seconds(),
                )

            # 成功完成
            self.status.state = AgentState.COMPLETED
            self.status.end_time = datetime.now()

            self.logger.info("=" * 50)
            self.logger.info("Workflow completed!")
            self.logger.info(f"Papers: {len(scrape_result.papers)}")
            self.logger.info(f"Post URL: {post_result.post_url}")
            self.logger.info(f"Duration: {(self.status.end_time - self.status.start_time).total_seconds():.2f}s")
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
            self.logger.exception("Workflow exception")
            return AgentResult(
                success=False,
                error_message=str(e),
                duration=(self.status.end_time - self.status.start_time).total_seconds(),
            )

    def get_status(self) -> Dict[str, Any]:
        """获取当前状态"""
        return self.status.to_dict()

    def get_config(self) -> Dict[str, Any]:
        """获取当前配置"""
        return get_config_dict(self.config)

    def close(self):
        """清理资源"""
        for skill in self.skills.values():
            if hasattr(skill, "close"):
                skill.close()


def main():
    """主函数"""
    import argparse

    parser = argparse.ArgumentParser(description="ArXiv Blog Agent")
    parser.add_argument("--config", "-c", default="config.yaml", help="Config file path")
    parser.add_argument("--dry-run", "-d", action="store_true", help="Dry run mode")
    parser.add_argument("--query", "-q", help="Search query")
    parser.add_argument("--max-results", "-m", type=int, help="Max results")

    args = parser.parse_args()

    agent = ArXivBlogAgent(
        config_path=args.config,
        dry_run=args.dry_run,
    )

    # 命令行参数覆盖
    if args.query:
        agent.config.arxiv.query = args.query
    if args.max_results:
        agent.config.arxiv.max_results = args.max_results

    result = agent.run()
    agent.close()

    print("\n" + "=" * 50)
    print("Result:")
    print(json.dumps(result.to_dict(), indent=2, ensure_ascii=False))

    return 0 if result.success else 1


if __name__ == "__main__":
    exit(main())

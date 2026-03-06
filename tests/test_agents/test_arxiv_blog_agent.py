"""
ArXiv Blog Agent 测试
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime

from agents.arxiv_blog_agent import (
    ArXivBlogAgent,
    AgentState,
    AgentStatus,
    AgentResult,
)
from skills.arxiv_scraper import ArXivPaper, ScraperResult
from skills.content_generator import BlogContent, GeneratorResult
from skills.blog_poster import PostResult


class TestAgentState:
    """AgentState 枚举测试"""

    def test_state_values(self):
        """测试状态值"""
        assert AgentState.IDLE.value == "idle"
        assert AgentState.SCRAPING.value == "scraping"
        assert AgentState.COMPLETED.value == "completed"
        assert AgentState.FAILED.value == "failed"


class TestAgentStatus:
    """AgentStatus 状态类测试"""

    def test_default_values(self):
        """测试默认值"""
        status = AgentStatus()
        assert status.state == AgentState.IDLE
        assert status.papers_count == 0

    def test_to_dict(self):
        """测试字典转换"""
        status = AgentStatus(
            state=AgentState.COMPLETED,
            papers_count=5,
            post_url="https://example.com/post",
        )
        result = status.to_dict()

        assert result["state"] == "completed"
        assert result["papers_count"] == 5
        assert result["post_url"] == "https://example.com/post"


class TestAgentResult:
    """AgentResult 结果类测试"""

    def test_success_result(self):
        """测试成功结果"""
        result = AgentResult(
            success=True,
            papers=[],
            post_url="https://example.com/post",
            duration=10.5,
        )
        assert result.success is True
        assert result.duration == 10.5

    def test_error_result(self):
        """测试错误结果"""
        result = AgentResult(
            success=False,
            error_message="Network error",
        )
        assert result.success is False
        assert result.error_message == "Network error"

    def test_to_dict(self):
        """测试字典转换"""
        result = AgentResult(
            success=True,
            papers=[Mock()],
            post_url="https://example.com/post",
            duration=10.0,
        )
        result_dict = result.to_dict()

        assert result_dict["success"] is True
        assert result_dict["papers_count"] == 1


class TestArXivBlogAgent:
    """ArXivBlogAgent 主类测试"""

    def test_init_default(self):
        """测试默认初始化"""
        agent = ArXivBlogAgent()
        assert agent.config is not None
        assert len(agent.skills) == 4

    def test_init_dry_run(self):
        """测试干运行模式初始化"""
        agent = ArXivBlogAgent(dry_run=True)
        assert agent.config.agent.dry_run is True

    def test_register_skills(self):
        """测试技能注册"""
        agent = ArXivBlogAgent()

        assert "arxiv_scraper" in agent.skills
        assert "content_generator" in agent.skills
        assert "blog_poster" in agent.skills
        assert "mock_blog_poster" in agent.skills

    @patch.object(ArXivBlogAgent, '_step_scrape')
    @patch.object(ArXivBlogAgent, '_step_generate')
    @patch.object(ArXivBlogAgent, '_step_post')
    def test_run_success(self, mock_post, mock_generate, mock_scrape):
        """测试成功运行"""
        # 模拟爬取结果
        mock_paper = ArXivPaper(
            title="Test Paper",
            authors=["Author"],
            abstract="Abstract",
            arxiv_id="1234.5678",
            url="https://arxiv.org/abs/1234.5678",
            pdf_url="https://arxiv.org/pdf/1234.5678",
            submitted_date="01 Jan 2024",
            categories=["cs.CL"],
        )
        mock_scrape.return_value = ScraperResult(
            success=True,
            papers=[mock_paper],
        )

        # 模拟生成结果
        mock_blog = BlogContent(
            title="Test Blog",
            summary="Summary",
            content="Content",
        )
        mock_generate.return_value = GeneratorResult(
            success=True,
            blog_content=mock_blog,
        )

        # 模拟发布结果
        mock_post.return_value = PostResult(
            success=True,
            post_id="12345",
            post_url="https://example.com/post",
        )

        agent = ArXivBlogAgent(dry_run=True)
        result = agent.run()

        assert result.success is True
        assert result.post_url == "https://example.com/post"
        assert agent.status.state == AgentState.COMPLETED

    @patch.object(ArXivBlogAgent, '_step_scrape')
    def test_run_scrape_failure(self, mock_scrape):
        """测试爬取失败"""
        mock_scrape.return_value = ScraperResult(
            success=False,
            error_message="Network error",
        )

        agent = ArXivBlogAgent()
        result = agent.run()

        assert result.success is False
        assert "Crawl failed" in result.error_message
        assert agent.status.state == AgentState.FAILED

    @patch.object(ArXivBlogAgent, '_step_scrape')
    @patch.object(ArXivBlogAgent, '_step_generate')
    def test_run_generate_failure(self, mock_generate, mock_scrape):
        """测试生成失败"""
        mock_scrape.return_value = ScraperResult(
            success=True,
            papers=[],
        )
        mock_generate.return_value = GeneratorResult(
            success=False,
            error_message="Empty papers",
        )

        agent = ArXivBlogAgent()
        result = agent.run()

        assert result.success is False
        assert "Generation failed" in result.error_message

    def test_get_status(self):
        """测试获取状态"""
        agent = ArXivBlogAgent()
        status = agent.get_status()

        assert "state" in status
        assert status["state"] == "idle"

    def test_close(self):
        """测试资源释放"""
        agent = ArXivBlogAgent()
        agent.close()
        # 应该不抛出异常


class TestAgentWorkflow:
    """Agent 工作流测试"""

    def test_step_scrape(self):
        """测试爬取步骤"""
        agent = ArXivBlogAgent()
        # 这里只测试方法存在且返回正确类型
        # 实际网络请求在集成测试中验证
        assert hasattr(agent, '_step_scrape')

    def test_step_generate(self, sample_papers):
        """测试生成步骤"""
        agent = ArXivBlogAgent()
        result = agent._step_generate(sample_papers)

        assert result.success is True
        assert result.blog_content is not None

    def test_step_post_dry_run(self, sample_blog_content):
        """测试发布步骤（干运行）"""
        agent = ArXivBlogAgent(dry_run=True)
        result = agent._step_post(sample_blog_content)

        # 干运行模式应该使用 MockPoster
        assert result.success is True

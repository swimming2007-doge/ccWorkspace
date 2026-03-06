"""
Blog Poster Skill 测试
"""

import pytest
from unittest.mock import Mock, patch
import json

from skills.blog_poster import (
    BlogPosterSkill,
    MockBlogPosterSkill,
    PostResult,
    BlogContent,
)


class TestPostResult:
    """PostResult 结果类测试"""

    def test_success_result(self):
        """测试成功结果"""
        result = PostResult(
            success=True,
            post_id="12345",
            post_url="https://example.com/post",
        )
        assert result.success is True
        assert result.post_id == "12345"

    def test_error_result(self):
        """测试错误结果"""
        result = PostResult(
            success=False,
            error_message="Authentication failed",
        )
        assert result.success is False
        assert result.error_message == "Authentication failed"


class TestBlogPosterSkill:
    """BlogPosterSkill 测试"""

    @pytest.fixture
    def mock_config(self):
        """模拟配置"""
        return {
            "api_base": "https://public-api.wordpress.com/rest/v1.1",
            "blog_id": "253145378",
            "blog_url": "https://swimming2007.wordpress.com/",
            "access_token": "test_token",
            "status": "publish",
            "default_category": "AI/大模型",
            "timeout": 20,
            "max_retries": 3,
            "retry_delay": 2,
        }

    def test_init_config(self, mock_config):
        """测试配置初始化"""
        poster = BlogPosterSkill(mock_config)
        assert poster.blog_id == "253145378"
        assert poster.status == "publish"

    def test_build_post_url(self, mock_config):
        """测试 URL 构建"""
        poster = BlogPosterSkill(mock_config)
        url = poster._build_post_url()

        assert "wordpress.com" in url
        assert "253145378" in url
        assert "posts/new" in url

    def test_prepare_post_data(self, mock_config, sample_blog_content):
        """测试数据准备"""
        poster = BlogPosterSkill(mock_config)
        data = poster._prepare_post_data(sample_blog_content)

        assert data["title"] == sample_blog_content.title
        assert data["content"] == sample_blog_content.content
        assert data["status"] == "publish"

    def test_execute_empty_content(self, mock_config):
        """测试空内容"""
        poster = BlogPosterSkill(mock_config)
        result = poster.execute(blog_content=None)

        assert result.success is False
        assert "无效" in result.error_message or "空" in result.error_message

    @patch("skills.blog_poster.requests.Session")
    def test_execute_success(self, mock_session, mock_config, sample_blog_content):
        """测试成功发布"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.headers = {"Content-Type": "application/json"}
        mock_response.json.return_value = {
            "ID": 12345,
            "URL": "https://example.com/post/12345",
        }

        mock_session_instance = Mock()
        mock_session_instance.headers = {}
        mock_session_instance.post.return_value = mock_response
        mock_session.return_value = mock_session_instance

        poster = BlogPosterSkill(mock_config)
        result = poster.execute(sample_blog_content)

        assert result.success is True
        assert result.post_id == "12345"

    @patch("skills.blog_poster.requests.Session")
    def test_execute_auth_error(self, mock_session, mock_config, sample_blog_content):
        """测试认证错误"""
        mock_response = Mock()
        mock_response.status_code = 401
        mock_response.headers = {"Content-Type": "application/json"}
        mock_response.json.return_value = {"error": "Unauthorized"}

        mock_session_instance = Mock()
        mock_session_instance.headers = {}
        mock_session_instance.post.return_value = mock_response
        mock_session.return_value = mock_session_instance

        poster = BlogPosterSkill(mock_config)
        result = poster.execute(sample_blog_content)

        assert result.success is False
        assert "认证失败" in result.error_message

    def test_close(self, mock_config):
        """测试资源释放"""
        poster = BlogPosterSkill(mock_config)
        poster._get_session()
        poster.close()
        assert poster._session is None


class TestMockBlogPosterSkill:
    """MockBlogPosterSkill 测试"""

    @pytest.fixture
    def mock_config(self):
        """模拟配置"""
        return {
            "api_base": "https://public-api.wordpress.com/rest/v1.1",
            "blog_id": "253145378",
            "blog_url": "https://swimming2007.wordpress.com/",
            "access_token": "test_token",
            "status": "publish",
            "default_category": "AI/大模型",
            "timeout": 20,
            "max_retries": 3,
            "retry_delay": 2,
        }

    def test_mock_always_success(self, mock_config, sample_blog_content):
        """测试模拟发布始终成功"""
        poster = MockBlogPosterSkill(mock_config)
        result = poster.execute(sample_blog_content)

        assert result.success is True
        assert result.post_id == "mock_post"

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
    post_to_wordpress,
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

    def test_init_default_config(self):
        """测试默认配置"""
        poster = BlogPosterSkill()
        assert poster.config["blog_id"] == "791025341"
        assert poster.config["default_status"] == "publish"

    def test_init_custom_config(self):
        """测试自定义配置"""
        poster = BlogPosterSkill({
            "blog_id": "custom_id",
            "timeout": 60,
        })
        assert poster.config["blog_id"] == "custom_id"
        assert poster.config["timeout"] == 60

    def test_build_post_url(self):
        """测试 URL 构建"""
        poster = BlogPosterSkill({"blog_id": "12345"})
        url = poster._build_post_url()

        assert "wordpress.com" in url
        assert "12345" in url
        assert "posts/new" in url

    def test_prepare_post_data(self, sample_blog_content):
        """测试数据准备"""
        poster = BlogPosterSkill()
        data = poster._prepare_post_data(sample_blog_content)

        assert data["title"] == sample_blog_content.title
        assert data["content"] == sample_blog_content.content
        assert data["status"] == "publish"

    def test_execute_empty_content(self):
        """测试空内容"""
        poster = BlogPosterSkill()
        result = poster.execute(blog_content=None)

        assert result.success is False
        assert "无效" in result.error_message or "空" in result.error_message

    @patch("skills.blog_poster.requests.Session")
    def test_execute_success(self, mock_session, sample_blog_content):
        """测试成功发布"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "ID": 12345,
            "URL": "https://example.com/post/12345",
        }

        mock_session_instance = Mock()
        mock_session_instance.post.return_value = mock_response
        mock_session.return_value = mock_session_instance

        poster = BlogPosterSkill()
        result = poster.execute(sample_blog_content)

        assert result.success is True
        assert result.post_id == "12345"

    @patch("skills.blog_poster.requests.Session")
    def test_execute_auth_error(self, mock_session, sample_blog_content):
        """测试认证错误"""
        mock_response = Mock()
        mock_response.status_code = 401

        mock_session_instance = Mock()
        mock_session_instance.post.return_value = mock_response
        mock_session.return_value = mock_session_instance

        poster = BlogPosterSkill()
        result = poster.execute(sample_blog_content)

        assert result.success is False
        assert "认证失败" in result.error_message

    @patch("skills.blog_poster.requests.Session")
    def test_test_connection_success(self, mock_session):
        """测试连接成功"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "name": "Test Blog",
            "URL": "https://test.wordpress.com",
        }

        mock_session_instance = Mock()
        mock_session_instance.get.return_value = mock_response
        mock_session.return_value = mock_session_instance

        poster = BlogPosterSkill()
        result = poster.test_connection()

        assert result["success"] is True

    def test_close(self):
        """测试资源释放"""
        poster = BlogPosterSkill()
        poster._get_session()
        poster.close()
        assert poster._session is None


class TestMockBlogPosterSkill:
    """MockBlogPosterSkill 测试"""

    def test_mock_always_success(self, sample_blog_content):
        """测试模拟发布始终成功"""
        poster = MockBlogPosterSkill()
        result = poster.execute(sample_blog_content)

        assert result.success is True
        assert result.post_id == "mock_post_12345"
        assert "mock-post" in result.post_url


class TestPostToWordpress:
    """便捷函数测试"""

    @patch("skills.blog_poster.BlogPosterSkill")
    def test_post_to_wordpress_function(self, mock_class, sample_blog_content):
        """测试便捷函数"""
        mock_instance = Mock()
        mock_result = PostResult(success=True)
        mock_instance.execute.return_value = mock_result
        mock_class.return_value = mock_instance

        result = post_to_wordpress(sample_blog_content)

        assert result.success is True
        mock_instance.close.assert_called_once()

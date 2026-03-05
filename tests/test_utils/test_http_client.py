"""
HTTP Client 测试
"""

import pytest
from unittest.mock import Mock, patch

from utils.http_client import HttpClient, HttpClientConfig, http_get, http_post


class TestHttpClientConfig:
    """HttpClientConfig 配置类测试"""

    def test_default_values(self):
        """测试默认值"""
        config = HttpClientConfig()
        assert config.timeout == 20
        assert config.max_retries == 3
        assert config.proxy is None
        assert config.ssl_verify is True

    def test_custom_values(self):
        """测试自定义值"""
        config = HttpClientConfig(
            timeout=60,
            proxy="http://proxy:8080",
            ssl_verify=False,
        )
        assert config.timeout == 60
        assert config.proxy == "http://proxy:8080"
        assert config.ssl_verify is False


class TestHttpClient:
    """HttpClient 测试"""

    def test_init_default_config(self):
        """测试默认配置初始化"""
        client = HttpClient()
        assert client.config.timeout == 20

    def test_init_dict_config(self):
        """测试字典配置初始化"""
        client = HttpClient({"timeout": 60})
        assert client.config.timeout == 60

    @patch("utils.http_client.requests.Session")
    def test_get(self, mock_session):
        """测试 GET 请求"""
        mock_response = Mock()
        mock_response.status_code = 200

        mock_session_instance = Mock()
        mock_session_instance.request.return_value = mock_response
        mock_session.return_value = mock_session_instance

        client = HttpClient()
        response = client.get("https://example.com")

        assert response.status_code == 200

    @patch("utils.http_client.requests.Session")
    def test_post(self, mock_session):
        """测试 POST 请求"""
        mock_response = Mock()
        mock_response.status_code = 201

        mock_session_instance = Mock()
        mock_session_instance.request.return_value = mock_response
        mock_session.return_value = mock_session_instance

        client = HttpClient()
        response = client.post("https://example.com", json={"key": "value"})

        assert response.status_code == 201

    def test_context_manager(self):
        """测试上下文管理器"""
        with HttpClient() as client:
            assert client._session is not None

        # 退出后 Session 应该关闭
        assert client._session is None

    def test_close(self):
        """测试资源释放"""
        client = HttpClient()
        client.session  # 创建 Session
        client.close()

        assert client._session is None


class TestConvenienceFunctions:
    """便捷函数测试"""

    @patch("utils.http_client.HttpClient")
    def test_http_get(self, mock_client):
        """测试 http_get 函数"""
        mock_instance = Mock()
        mock_response = Mock()
        mock_instance.get.return_value = mock_response
        mock_client.return_value.__enter__ = Mock(return_value=mock_instance)
        mock_client.return_value.__exit__ = Mock(return_value=False)

        response = http_get("https://example.com")

        mock_instance.get.assert_called_once()

    @patch("utils.http_client.HttpClient")
    def test_http_post(self, mock_client):
        """测试 http_post 函数"""
        mock_instance = Mock()
        mock_response = Mock()
        mock_instance.post.return_value = mock_response
        mock_client.return_value.__enter__ = Mock(return_value=mock_instance)
        mock_client.return_value.__exit__ = Mock(return_value=False)

        response = http_post("https://example.com", json={"key": "value"})

        mock_instance.post.assert_called_once()

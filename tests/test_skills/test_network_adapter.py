"""
Network Adapter Skill 测试
"""

import pytest
from unittest.mock import Mock, patch

from skills.network_adapter import (
    NetworkAdapter,
    NetworkConfig,
    get_default_adapter,
    set_default_adapter,
)


class TestNetworkConfig:
    """NetworkConfig 配置类测试"""

    def test_default_values(self):
        """测试默认值"""
        config = NetworkConfig()
        assert config.timeout == 20
        assert config.max_retries == 3
        assert config.proxy is None
        assert config.ssl_verify is True

    def test_custom_values(self):
        """测试自定义值"""
        config = NetworkConfig(
            timeout=60,
            proxy="http://proxy:8080",
            ssl_verify=False,
        )
        assert config.timeout == 60
        assert config.proxy == "http://proxy:8080"
        assert config.ssl_verify is False


class TestNetworkAdapter:
    """NetworkAdapter 测试"""

    def test_init_default_config(self):
        """测试默认配置初始化"""
        adapter = NetworkAdapter()
        assert adapter.config.timeout == 20
        assert adapter.config.proxy is None

    def test_init_dict_config(self):
        """测试字典配置初始化"""
        adapter = NetworkAdapter({
            "timeout": 60,
            "proxy": "http://proxy:8080",
        })
        assert adapter.config.timeout == 60
        assert adapter.config.proxy == "http://proxy:8080"

    def test_build_proxies_single(self):
        """测试单一代理配置"""
        adapter = NetworkAdapter({"proxy": "http://proxy:8080"})
        proxies = adapter._build_proxies()

        assert proxies["http"] == "http://proxy:8080"
        assert proxies["https"] == "http://proxy:8080"

    def test_build_proxies_separate(self):
        """测试分离代理配置"""
        adapter = NetworkAdapter({
            "proxy_http": "http://http-proxy:8080",
            "proxy_https": "http://https-proxy:8443",
        })
        proxies = adapter._build_proxies()

        assert proxies["http"] == "http://http-proxy:8080"
        assert proxies["https"] == "http://https-proxy:8443"

    @patch("skills.network_adapter.requests.Session")
    def test_get(self, mock_session):
        """测试 GET 请求"""
        mock_response = Mock()
        mock_response.status_code = 200

        mock_session_instance = Mock()
        mock_session_instance.request.return_value = mock_response
        mock_session.return_value = mock_session_instance

        adapter = NetworkAdapter()
        response = adapter.get("https://example.com")

        assert response.status_code == 200

    @patch("skills.network_adapter.requests.Session")
    def test_post(self, mock_session):
        """测试 POST 请求"""
        mock_response = Mock()
        mock_response.status_code = 201

        mock_session_instance = Mock()
        mock_session_instance.request.return_value = mock_response
        mock_session.return_value = mock_session_instance

        adapter = NetworkAdapter()
        response = adapter.post("https://example.com", json={"key": "value"})

        assert response.status_code == 201

    @patch("skills.network_adapter.requests.Session")
    def test_test_connectivity_success(self, mock_session):
        """测试连通性成功"""
        mock_response = Mock()
        mock_response.status_code = 200

        mock_session_instance = Mock()
        mock_session_instance.request.return_value = mock_response
        mock_session.return_value = mock_session_instance

        adapter = NetworkAdapter()
        result = adapter.test_connectivity()

        assert result["success"] is True
        assert result["status_code"] == 200

    @patch("skills.network_adapter.requests.Session")
    def test_test_connectivity_failure(self, mock_session):
        """测试连通性失败"""
        mock_session_instance = Mock()
        mock_session_instance.request.side_effect = Exception("Connection failed")
        mock_session.return_value = mock_session_instance

        adapter = NetworkAdapter()
        result = adapter.test_connectivity()

        assert result["success"] is False
        assert result["error"] == "Connection failed"

    def test_context_manager(self):
        """测试上下文管理器"""
        with NetworkAdapter() as adapter:
            # Session is created lazily, so _session is None until accessed
            assert adapter._session is None
            # Access session property to create it
            _ = adapter.session
            assert adapter._session is not None

        # 退出后 Session 应该关闭
        assert adapter._session is None

    def test_close(self):
        """测试资源释放"""
        adapter = NetworkAdapter()
        adapter.session  # 创建 Session
        adapter.close()

        assert adapter._session is None


class TestGlobalAdapter:
    """全局适配器测试"""

    def test_get_default_adapter(self):
        """测试获取默认适配器"""
        adapter1 = get_default_adapter()
        adapter2 = get_default_adapter()

        # 应该是同一个实例
        assert adapter1 is adapter2

    def test_set_default_adapter(self):
        """测试设置默认适配器"""
        custom_adapter = NetworkAdapter({"timeout": 100})
        set_default_adapter(custom_adapter)

        adapter = get_default_adapter()
        assert adapter.config.timeout == 100

        # 重置
        set_default_adapter(None)

"""
ArXiv Scraper Skill 测试
"""

import pytest
from unittest.mock import Mock, patch
import xml.etree.ElementTree as ET

from skills.arxiv_scraper import (
    ArXivScraperSkill,
    ArXivPaper,
    ScraperResult,
    scrape_arxiv,
)


class TestArXivPaper:
    """ArXivPaper 数据类测试"""

    def test_create_paper(self):
        """测试创建论文对象"""
        paper = ArXivPaper(
            title="Test Paper",
            authors=["Author 1", "Author 2"],
            abstract="Test abstract",
            arxiv_id="1234.5678",
            url="https://arxiv.org/abs/1234.5678",
            pdf_url="https://arxiv.org/pdf/1234.5678",
            submitted_date="01 Jan 2024",
            categories=["cs.CL"],
        )

        assert paper.title == "Test Paper"
        assert len(paper.authors) == 2
        assert paper.arxiv_id == "1234.5678"


class TestScraperResult:
    """ScraperResult 结果类测试"""

    def test_success_result(self):
        """测试成功结果"""
        result = ScraperResult(
            success=True,
            papers=[],
            total_count=0,
        )
        assert result.success is True
        assert result.papers == []

    def test_error_result(self):
        """测试错误结果"""
        result = ScraperResult(
            success=False,
            error_message="Network error",
        )
        assert result.success is False
        assert result.error_message == "Network error"


# Sample ArXiv API XML response
MOCK_ARXIV_XML = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:arxiv="http://arxiv.org/schemas/atom">
  <entry>
    <id>http://arxiv.org/abs/1234.5678v1</id>
    <title>Test Paper Title</title>
    <author>
      <name>Author 1</name>
    </author>
    <author>
      <name>Author 2</name>
    </author>
    <summary>This is a test abstract for the paper.</summary>
    <published>2024-01-01T00:00:00Z</published>
    <category term="cs.CL"/>
    <category term="cs.AI"/>
  </entry>
</feed>
"""


class TestArXivScraperSkill:
    """ArXivScraperSkill 测试"""

    def test_init_default_config(self):
        """测试默认配置初始化"""
        scraper = ArXivScraperSkill()
        assert scraper.config["timeout"] == 30
        assert scraper.config["max_retries"] == 3
        assert scraper.config["proxy"] is None

    def test_init_custom_config(self):
        """测试自定义配置初始化"""
        scraper = ArXivScraperSkill({
            "timeout": 60,
            "proxy": "http://proxy:8080",
        })
        assert scraper.config["timeout"] == 60
        assert scraper.config["proxy"] == "http://proxy:8080"

    def test_build_api_url(self):
        """测试 API URL 构建"""
        scraper = ArXivScraperSkill()
        url = scraper._build_api_url(
            query="transformer",
            max_results=10,
        )

        assert "arxiv.org/api" in url
        assert "transformer" in url
        assert "max_results=10" in url

    @patch("skills.arxiv_scraper.requests.Session")
    def test_execute_success(self, mock_session):
        """测试成功爬取"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = MOCK_ARXIV_XML.encode('utf-8')
        mock_response.raise_for_status = Mock()

        mock_session_instance = Mock()
        mock_session_instance.get.return_value = mock_response
        mock_session.return_value = mock_session_instance

        scraper = ArXivScraperSkill()
        result = scraper.execute()

        assert result.success is True
        assert len(result.papers) == 1
        assert result.papers[0].title == "Test Paper Title"

    @patch("skills.arxiv_scraper.requests.Session")
    def test_execute_network_error(self, mock_session):
        """测试网络错误"""
        import requests

        mock_session_instance = Mock()
        mock_session_instance.get.side_effect = requests.exceptions.ConnectionError("Network error")
        mock_session.return_value = mock_session_instance

        scraper = ArXivScraperSkill({"max_retries": 1})
        result = scraper.execute()

        assert result.success is False
        assert "Request failed" in result.error_message

    def test_parse_entry(self):
        """测试 XML entry 解析"""
        scraper = ArXivScraperSkill()

        # Parse the mock XML
        root = ET.fromstring(MOCK_ARXIV_XML)
        ns = "{http://www.w3.org/2005/Atom}"
        entry = root.find(f"{ns}entry")

        paper = scraper._parse_entry(entry)

        assert paper is not None
        assert paper.title == "Test Paper Title"
        assert len(paper.authors) == 2
        # arxiv_id may include version suffix like "1234.5678v1"
        assert paper.arxiv_id.startswith("1234.5678")

    def test_close(self):
        """测试资源释放"""
        scraper = ArXivScraperSkill()
        scraper._get_session()  # 创建会话
        scraper.close()
        assert scraper._session is None


class TestScrapeArxiv:
    """便捷函数测试"""

    @patch("skills.arxiv_scraper.ArXivScraperSkill")
    def test_scrape_arxiv_function(self, mock_class):
        """测试便捷函数"""
        mock_instance = Mock()
        mock_result = ScraperResult(success=True)
        mock_instance.execute.return_value = mock_result
        mock_class.return_value = mock_instance

        result = scrape_arxiv(query="test")

        assert result.success is True
        mock_instance.close.assert_called_once()

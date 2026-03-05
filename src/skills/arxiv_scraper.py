"""
ArXiv Scraper Skill - 使用 ArXiv API 爬取论文

默认配置：
- API 地址: https://export.arxiv.org/api/query
- 超时时间: 30秒
- 重试次数: 3次
"""

import re
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional
from urllib.parse import urlencode, quote

import requests


@dataclass
class ArXivPaper:
    """ArXiv 论文数据结构"""
    title: str
    authors: List[str]
    abstract: str
    arxiv_id: str
    url: str
    pdf_url: str
    submitted_date: str
    categories: List[str] = field(default_factory=list)


@dataclass
class ScraperResult:
    """爬取结果数据结构"""
    success: bool
    papers: List[ArXivPaper] = field(default_factory=list)
    total_count: int = 0
    error_message: str = ""
    scraped_at: str = ""


class ArXivScraperSkill:
    """
    ArXiv 论文爬取技能 (使用官方 API)

    功能：通过 ArXiv API 搜索论文
    API 文档：https://arxiv.org/help/api/user-manual
    """

    DEFAULT_CONFIG = {
        "api_url": "https://export.arxiv.org/api/query",
        "timeout": 30,
        "max_retries": 3,
        "retry_delay": 3,
        "user_agent": "ArXiv-Blog-Agent/1.0",
        "proxy": None,
        "ssl_verify": True,
        "default_query": "large model training inference",
        "default_max_results": 10,
    }

    # ArXiv API 命名空间
    ATOM_NS = "{http://www.w3.org/2005/Atom}"
    ARXIV_NS = "{http://arxiv.org/schemas/atom}"

    def __init__(self, config: Optional[dict] = None):
        self.config = {**self.DEFAULT_CONFIG, **(config or {})}
        self._session = None

    def _get_session(self) -> requests.Session:
        if self._session is None:
            self._session = requests.Session()
            self._session.headers.update({
                "User-Agent": self.config["user_agent"],
            })
            if self.config.get("proxy"):
                self._session.proxies = {
                    "http": self.config["proxy"],
                    "https": self.config["proxy"],
                }
        return self._session

    def _build_api_url(self, query: str, max_results: int) -> str:
        """构建 ArXiv API URL"""
        # ArXiv API 搜索语法
        search_query = f"all:{query}"
        params = {
            "search_query": search_query,
            "start": 0,
            "max_results": max_results,
            "sortBy": "submittedDate",
            "sortOrder": "descending",
        }
        return f"{self.config['api_url']}?{urlencode(params)}"

    def _parse_entry(self, entry) -> Optional[ArXivPaper]:
        """解析单个 entry"""
        try:
            # 提取标题
            title_elem = entry.find(f"{self.ATOM_NS}title")
            title = title_elem.text.strip() if title_elem is not None and title_elem.text else ""

            # 提取作者
            authors = []
            for author in entry.findall(f"{self.ATOM_NS}author"):
                name_elem = author.find(f"{self.ATOM_NS}name")
                if name_elem is not None and name_elem.text:
                    authors.append(name_elem.text.strip())

            # 提取摘要
            summary_elem = entry.find(f"{self.ATOM_NS}summary")
            abstract = summary_elem.text.strip() if summary_elem is not None and summary_elem.text else ""

            # 提取 ID
            id_elem = entry.find(f"{self.ATOM_NS}id")
            full_url = id_elem.text.strip() if id_elem is not None and id_elem.text else ""

            # 从 URL 提取 arxiv_id
            arxiv_id = ""
            if full_url:
                match = re.search(r'(\d{4}\.\d{4,5}(v\d+)?)', full_url)
                if match:
                    arxiv_id = match.group(1)

            # 构建链接
            url = f"https://arxiv.org/abs/{arxiv_id}" if arxiv_id else full_url
            pdf_url = f"https://arxiv.org/pdf/{arxiv_id}" if arxiv_id else ""

            # 提取发布日期
            published_elem = entry.find(f"{self.ATOM_NS}published")
            submitted_date = ""
            if published_elem is not None and published_elem.text:
                try:
                    dt = datetime.fromisoformat(published_elem.text.replace("Z", "+00:00"))
                    submitted_date = dt.strftime("%d %b %Y")
                except:
                    submitted_date = published_elem.text[:10]

            # 提取分类
            categories = []
            for cat in entry.findall(f"{self.ATOM_NS}category"):
                term = cat.get("term")
                if term:
                    categories.append(term)

            return ArXivPaper(
                title=title[:500] if len(title) > 500 else title,
                authors=authors[:10],
                abstract=abstract[:500] + "..." if len(abstract) > 500 else abstract,
                arxiv_id=arxiv_id,
                url=url,
                pdf_url=pdf_url,
                submitted_date=submitted_date,
                categories=categories[:5],
            )
        except Exception as e:
            return None

    def execute(self, query: str = None, max_results: int = None,
                sort_by: str = "submitted_date", sort_order: str = "desc") -> ScraperResult:
        """
        执行爬取任务

        Args:
            query: 搜索关键词
            max_results: 最大结果数
            sort_by: 排序字段
            sort_order: 排序方向

        Returns:
            ScraperResult: 爬取结果
        """
        query = query or self.config["default_query"]
        max_results = max_results or self.config["default_max_results"]

        result = ScraperResult(
            success=False,
            scraped_at=datetime.now().isoformat(),
        )

        url = self._build_api_url(query, max_results)

        for attempt in range(self.config["max_retries"]):
            try:
                session = self._get_session()
                response = session.get(
                    url,
                    timeout=self.config["timeout"],
                    verify=self.config["ssl_verify"],
                )
                response.raise_for_status()

                # 解析 XML
                root = ET.fromstring(response.content)

                # 查找所有 entry
                entries = root.findall(f"{self.ATOM_NS}entry")

                papers = []
                for entry in entries:
                    paper = self._parse_entry(entry)
                    if paper and paper.title:
                        papers.append(paper)

                result.papers = papers
                result.total_count = len(papers)
                result.success = True
                return result

            except requests.exceptions.RequestException as e:
                result.error_message = f"Request failed (attempt {attempt + 1}/{self.config['max_retries']}): {str(e)}"
                if attempt < self.config["max_retries"] - 1:
                    time.sleep(self.config["retry_delay"])
            except ET.ParseError as e:
                result.error_message = f"XML parse error: {str(e)}"
                break
            except Exception as e:
                result.error_message = f"Parse error: {str(e)}"
                break

        return result

    def close(self):
        """关闭会话"""
        if self._session:
            self._session.close()
            self._session = None


def scrape_arxiv(query: str = None, max_results: int = 10,
                 config: dict = None) -> ScraperResult:
    """
    便捷函数：爬取 ArXiv 论文

    Args:
        query: 搜索关键词
        max_results: 最大结果数
        config: 额外配置

    Returns:
        ScraperResult: 爬取结果
    """
    scraper = ArXivScraperSkill(config)
    try:
        return scraper.execute(query=query, max_results=max_results)
    finally:
        scraper.close()

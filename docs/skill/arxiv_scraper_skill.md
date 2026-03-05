# ArXiv Scraper Skill

## 1. Skill 定义

### 1.1 功能描述
从 ArXiv 爬取大模型训练与推理相关的最新论文信息，包括标题、作者、摘要、链接等。

### 1.2 输入参数
| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|------|-------|------|
| query | str | 否 | "large model training inference" | 搜索关键词 |
| max_results | int | 否 | 10 | 最大返回结果数 |
| sort_by | str | 否 | "submitted_date" | 排序字段 |
| sort_order | str | 否 | "desc" | 排序方向 |

### 1.3 输出结构
```python
@dataclass
class ArXivPaper:
    title: str              # 论文标题
    authors: List[str]      # 作者列表
    abstract: str           # 摘要
    arxiv_id: str           # ArXiv ID
    url: str                # 论文链接
    pdf_url: str            # PDF 链接
    submitted_date: str     # 提交日期
    categories: List[str]   # 分类标签

@dataclass
class ScraperResult:
    success: bool           # 是否成功
    papers: List[ArXivPaper]  # 论文列表
    total_count: int        # 总数
    error_message: str      # 错误信息（如有）
    scraped_at: str         # 爬取时间戳
```

## 2. 实现代码

```python
"""
ArXiv Scraper Skill - 爬取 ArXiv 大模型训练推理相关论文

默认配置：
- 请求地址: https://arxiv.org/search/
- 超时时间: 30秒
- 重试次数: 3次
- User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
"""

import re
import time
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional
from urllib.parse import urlencode, quote

import requests
from bs4 import BeautifulSoup


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
    ArXiv 论文爬取技能

    功能：从 ArXiv 搜索并提取大模型训练推理相关论文信息
    支持：公网直接访问 / 内网代理配置
    """

    # 默认配置（硬编码，确保无需配置即可运行）
    DEFAULT_CONFIG = {
        "base_url": "https://arxiv.org/search/",
        "timeout": 30,
        "max_retries": 3,
        "retry_delay": 2,
        "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "proxy": None,
        "ssl_verify": True,
        "default_query": "large model training inference",
        "default_max_results": 10,
    }

    def __init__(self, config: Optional[dict] = None):
        """
        初始化爬虫技能

        Args:
            config: 配置字典，覆盖默认配置
        """
        self.config = {**self.DEFAULT_CONFIG, **(config or {})}
        self._session = None

    def _get_session(self) -> requests.Session:
        """获取或创建 HTTP 会话"""
        if self._session is None:
            self._session = requests.Session()
            self._session.headers.update({
                "User-Agent": self.config["user_agent"],
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.5",
            })
            if self.config.get("proxy"):
                self._session.proxies = {
                    "http": self.config["proxy"],
                    "https": self.config["proxy"],
                }
        return self._session

    def _build_search_url(self, query: str, max_results: int,
                          sort_by: str, sort_order: str) -> str:
        """构建搜索 URL"""
        params = {
            "query": query,
            "searchtype": "all",
            "sort": sort_by,
            "order": sort_order,
            "size": min(max_results, 50),  # ArXiv 单页最大 50
        }
        return f"{self.config['base_url']}?{urlencode(params)}"

    def _parse_paper_from_li(self, li_element) -> Optional[ArXivPaper]:
        """从列表项解析论文信息"""
        try:
            # 提取标题和链接
            title_tag = li_element.select_one("p.title")
            if not title_tag:
                return None
            title = title_tag.get_text(strip=True)

            # 提取 ArXiv ID 和 URL
            link_tag = li_element.select_one("p.list-title a")
            if not link_tag:
                return None

            href = link_tag.get("href", "")
            arxiv_id_match = re.search(r'(\d{4}\.\d{4,5}(v\d+)?)', href)
            arxiv_id = arxiv_id_match.group(1) if arxiv_id_match else ""

            # 构建完整 URL
            url = f"https://arxiv.org/abs/{arxiv_id}" if arxiv_id else ""
            pdf_url = f"https://arxiv.org/pdf/{arxiv_id}" if arxiv_id else ""

            # 提取作者
            authors_tag = li_element.select_one("p.authors")
            authors = []
            if authors_tag:
                author_links = authors_tag.select("a")
                authors = [a.get_text(strip=True) for a in author_links[:5]]  # 最多5位作者

            # 提取摘要
            abstract_tag = li_element.select_one("span.abstract-full")
            if not abstract_tag:
                abstract_tag = li_element.select_one("p.abstract")
            abstract = abstract_tag.get_text(strip=True) if abstract_tag else ""
            # 清理摘要中的多余空白
            abstract = re.sub(r'\s+', ' ', abstract)

            # 提取提交日期
            date_tag = li_element.select_one("p.is-size-7")
            submitted_date = ""
            if date_tag:
                date_text = date_tag.get_text()
                date_match = re.search(r'(\d{1,2}\s+\w+\s+\d{4})', date_text)
                if date_match:
                    submitted_date = date_match.group(1)

            # 提取分类
            categories = []
            tags_container = li_element.select_one("div.tags")
            if tags_container:
                cat_links = tags_container.select("a")
                categories = [c.get_text(strip=True) for c in cat_links]

            return ArXivPaper(
                title=title,
                authors=authors,
                abstract=abstract[:500] + "..." if len(abstract) > 500 else abstract,
                arxiv_id=arxiv_id,
                url=url,
                pdf_url=pdf_url,
                submitted_date=submitted_date,
                categories=categories,
            )
        except Exception as e:
            return None

    def execute(self, query: str = None, max_results: int = None,
                sort_by: str = "submitted_date", sort_order: str = "desc") -> ScraperResult:
        """
        执行爬取任务

        Args:
            query: 搜索关键词，默认使用配置中的默认值
            max_results: 最大结果数，默认 10
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

        url = self._build_search_url(query, max_results, sort_by, sort_order)

        for attempt in range(self.config["max_retries"]):
            try:
                session = self._get_session()
                response = session.get(
                    url,
                    timeout=self.config["timeout"],
                    verify=self.config["ssl_verify"],
                )
                response.raise_for_status()

                soup = BeautifulSoup(response.text, "lxml")
                paper_list = soup.select("li.arxiv-result")

                papers = []
                for li in paper_list[:max_results]:
                    paper = self._parse_paper_from_li(li)
                    if paper:
                        papers.append(paper)

                result.papers = papers
                result.total_count = len(papers)
                result.success = True
                return result

            except requests.exceptions.RequestException as e:
                result.error_message = f"请求失败 (尝试 {attempt + 1}/{self.config['max_retries']}): {str(e)}"
                if attempt < self.config["max_retries"] - 1:
                    time.sleep(self.config["retry_delay"])
            except Exception as e:
                result.error_message = f"解析失败: {str(e)}"
                break

        return result

    def close(self):
        """关闭会话"""
        if self._session:
            self._session.close()
            self._session = None


# 便捷函数
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
```

## 3. 使用示例

### 3.1 基础用法（无需配置）
```python
from skills.arxiv_scraper import ArXivScraperSkill

# 使用默认配置直接运行
scraper = ArXivScraperSkill()
result = scraper.execute()

if result.success:
    for paper in result.papers:
        print(f"标题: {paper.title}")
        print(f"链接: {paper.url}")
        print(f"摘要: {paper.abstract[:100]}...")
        print("-" * 50)
```

### 3.2 自定义查询
```python
# 自定义搜索关键词
result = scraper.execute(
    query="transformer attention mechanism",
    max_results=5,
    sort_by="relevance"
)
```

### 3.3 内网代理配置
```python
# 内网环境配置
internal_config = {
    "proxy": "http://internal-proxy:8080",
    "ssl_verify": False,
    "timeout": 60,
}
scraper = ArXivScraperSkill(internal_config)
result = scraper.execute()
```

## 4. 异常处理

| 异常场景 | 处理方式 |
|---------|---------|
| 网络超时 | 自动重试 3 次，间隔 2 秒 |
| HTTP 错误 | 记录错误信息，返回 success=False |
| 解析失败 | 跳过该条目，继续解析其他 |
| 代理不可用 | 使用直连或返回错误 |

## 5. 配置说明

### 5.1 配置文件覆盖
```yaml
# configs/config.yaml
arxiv_scraper:
  base_url: "https://arxiv.org/search/"
  timeout: 30
  max_retries: 3
  retry_delay: 2
  proxy: null              # 内网时配置代理
  ssl_verify: true         # 内网可设为 false
  default_query: "large model training inference"
  default_max_results: 10
```

### 5.2 内网配置示例
```yaml
# configs/prod_config.yaml
arxiv_scraper:
  base_url: "https://internal-arxiv-mirror.internal.corp/search/"
  proxy: "http://proxy.internal.corp:8080"
  ssl_verify: false
  timeout: 60
```

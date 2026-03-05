"""
测试配置文件
"""

import os
import sys

# 添加 src 目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

import pytest


@pytest.fixture
def sample_paper():
    """示例论文数据"""
    from skills.arxiv_scraper import ArXivPaper
    return ArXivPaper(
        title="Attention Is All You Need",
        authors=["Ashish Vaswani", "Noam Shazeer", "Niki Parmar"],
        abstract="The dominant sequence transduction models are based on complex recurrent or convolutional neural networks...",
        arxiv_id="1706.03762",
        url="https://arxiv.org/abs/1706.03762",
        pdf_url="https://arxiv.org/pdf/1706.03762",
        submitted_date="12 Jun 2017",
        categories=["cs.CL", "cs.LG"],
    )


@pytest.fixture
def sample_papers(sample_paper):
    """示例论文列表"""
    from skills.arxiv_scraper import ArXivPaper
    return [
        sample_paper,
        ArXivPaper(
            title="BERT: Pre-training of Deep Bidirectional Transformers",
            authors=["Jacob Devlin", "Ming-Wei Chang", "Kenton Lee"],
            abstract="We introduce a new language representation model called BERT...",
            arxiv_id="1810.04805",
            url="https://arxiv.org/abs/1810.04805",
            pdf_url="https://arxiv.org/pdf/1810.04805",
            submitted_date="11 Oct 2018",
            categories=["cs.CL"],
        ),
    ]


@pytest.fixture
def sample_blog_content():
    """示例博客内容"""
    from skills.content_generator import BlogContent
    return BlogContent(
        title="ArXiv 大模型训推进展 - 2024年01月15日",
        summary="本期收录 2 篇大模型训练与推理相关论文。",
        content="# 测试内容\n\n这是测试正文。",
        tags=["AI", "LLM", "TRANSFORMER"],
        category="AI/大模型",
        created_at="2024-01-15T10:00:00",
    )


@pytest.fixture
def mock_arxiv_html():
    """模拟 ArXiv 搜索结果 HTML"""
    return """
    <html>
    <body>
    <ol class="arxiv-result-list">
        <li class="arxiv-result">
            <p class="title">Attention Is All You Need</p>
            <p class="list-title">
                <a href="https://arxiv.org/abs/1706.03762">arXiv:1706.03762</a>
            </p>
            <p class="authors">
                <a href="#">Ashish Vaswani</a>,
                <a href="#">Noam Shazeer</a>
            </p>
            <p class="abstract">
                <span class="abstract-full">The dominant sequence transduction models are based on complex recurrent or convolutional neural networks.</span>
            </p>
            <p class="is-size-7">Submitted: 12 Jun 2017</p>
            <div class="tags">
                <a href="#">cs.CL</a>
                <a href="#">cs.LG</a>
            </div>
        </li>
    </ol>
    </body>
    </html>
    """

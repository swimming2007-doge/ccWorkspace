"""
Skills 包初始化
"""

from .arxiv_scraper import ArXivScraperSkill, ArXivPaper, ScraperResult, scrape_arxiv
from .content_generator import ContentGeneratorSkill, BlogContent, GeneratorResult, generate_blog_content
from .blog_poster import BlogPosterSkill, MockBlogPosterSkill, PostResult, post_to_wordpress
from .network_adapter import NetworkAdapter, NetworkConfig, get_default_adapter

__all__ = [
    # ArXiv Scraper
    "ArXivScraperSkill",
    "ArXivPaper",
    "ScraperResult",
    "scrape_arxiv",

    # Content Generator
    "ContentGeneratorSkill",
    "BlogContent",
    "GeneratorResult",
    "generate_blog_content",

    # Blog Poster
    "BlogPosterSkill",
    "MockBlogPosterSkill",
    "PostResult",
    "post_to_wordpress",

    # Network Adapter
    "NetworkAdapter",
    "NetworkConfig",
    "get_default_adapter",
]

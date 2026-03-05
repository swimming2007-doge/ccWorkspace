"""
Content Generator Skill 测试
"""

import pytest
from datetime import datetime

from skills.content_generator import (
    ContentGeneratorSkill,
    BlogContent,
    GeneratorResult,
    generate_blog_content,
)
from skills.arxiv_scraper import ArXivPaper


class TestBlogContent:
    """BlogContent 数据类测试"""

    def test_create_blog_content(self):
        """测试创建博客内容"""
        content = BlogContent(
            title="Test Title",
            summary="Test summary",
            content="# Test Content",
            tags=["AI", "ML"],
            category="AI/大模型",
        )

        assert content.title == "Test Title"
        assert content.tags == ["AI", "ML"]

    def test_default_values(self):
        """测试默认值"""
        content = BlogContent(
            title="Test",
            summary="Summary",
            content="Content",
        )

        assert content.tags == []
        assert content.category == "AI/大模型"


class TestGeneratorResult:
    """GeneratorResult 结果类测试"""

    def test_success_result(self):
        """测试成功结果"""
        result = GeneratorResult(
            success=True,
            blog_content=BlogContent(
                title="Test",
                summary="Summary",
                content="Content",
            ),
        )
        assert result.success is True
        assert result.blog_content is not None

    def test_error_result(self):
        """测试错误结果"""
        result = GeneratorResult(
            success=False,
            error_message="No papers provided",
        )
        assert result.success is False
        assert result.blog_content is None


class TestContentGeneratorSkill:
    """ContentGeneratorSkill 测试"""

    def test_init_default_config(self):
        """测试默认配置"""
        generator = ContentGeneratorSkill()
        assert generator.config["title_prefix"] == "ArXiv 大模型训推进展 - "
        assert generator.config["default_style"] == "professional"

    def test_init_custom_config(self):
        """测试自定义配置"""
        generator = ContentGeneratorSkill({
            "title_prefix": "Custom Prefix - ",
            "default_style": "casual",
        })
        assert generator.config["title_prefix"] == "Custom Prefix - "

    def test_execute_with_papers(self, sample_papers):
        """测试有论文时生成"""
        generator = ContentGeneratorSkill()
        result = generator.execute(papers=sample_papers)

        assert result.success is True
        assert result.blog_content is not None
        assert "ArXiv" in result.blog_content.title
        assert len(result.blog_content.content) > 0

    def test_execute_empty_papers(self):
        """测试空论文列表"""
        generator = ContentGeneratorSkill()
        result = generator.execute(papers=[])

        assert result.success is False
        assert "为空" in result.error_message

    def test_different_styles(self, sample_papers):
        """测试不同写作风格"""
        generator = ContentGeneratorSkill()

        # Professional 风格
        result1 = generator.execute(papers=sample_papers, style="professional")
        assert result1.success is True
        assert "**作者**" in result1.blog_content.content

        # Casual 风格
        result2 = generator.execute(papers=sample_papers, style="casual")
        assert result2.success is True
        assert "👋" in result2.blog_content.content or "📝" in result2.blog_content.content

        # Academic 风格
        result3 = generator.execute(papers=sample_papers, style="academic")
        assert result3.success is True
        assert "Authors:" in result3.blog_content.content

    def test_format_authors(self):
        """测试作者格式化"""
        generator = ContentGeneratorSkill()

        # 少于3位作者
        assert generator._format_authors(["A", "B"]) == "A, B"

        # 超过3位作者
        result = generator._format_authors(["A", "B", "C", "D"])
        assert "等" in result

        # 空列表
        assert generator._format_authors([]) == "未知"

    def test_truncate_abstract(self):
        """测试摘要截断"""
        generator = ContentGeneratorSkill({"max_abstract_length": 50})

        short_abstract = "This is a short abstract."
        assert generator._truncate_abstract(short_abstract) == short_abstract

        long_abstract = "A" * 100
        truncated = generator._truncate_abstract(long_abstract)
        assert len(truncated) <= 53  # 50 + "..."
        assert truncated.endswith("...")

    def test_extract_tags(self, sample_papers):
        """测试标签提取"""
        generator = ContentGeneratorSkill()
        tags = generator._extract_tags(sample_papers)

        assert len(tags) > 0
        assert len(tags) <= 10

    def test_generate_summary(self, sample_papers):
        """测试摘要生成"""
        generator = ContentGeneratorSkill()
        summary = generator._generate_summary(sample_papers)

        assert "篇" in summary
        assert "论文" in summary


class TestGenerateBlogContent:
    """便捷函数测试"""

    def test_generate_blog_content_function(self, sample_papers):
        """测试便捷函数"""
        result = generate_blog_content(papers=sample_papers, style="professional")

        assert result.success is True
        assert result.blog_content is not None

"""
Content Generator Skill - 基于 AI 的学术内容生成器

核心原则：专业严谨、逻辑清晰、重点突出、简洁务实
输出格式：中英文简介（必备）+ 核心创新点 + 实验分析

依赖：
- 智谱AI (glm-4-flash) 用于内容生成
"""

import os
import json
import logging
import requests
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional

logger = logging.getLogger("content_generator")


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
class BlogContent:
    """博客内容数据结构"""
    title: str
    summary: str
    content: str
    tags: List[str] = field(default_factory=list)
    category: str = "AI/大模型"
    created_at: str = ""


@dataclass
class GeneratorResult:
    """生成结果数据结构"""
    success: bool
    blog_content: Optional[BlogContent] = None
    error_message: str = ""


# AI 生成提示词模板
SYSTEM_PROMPT = """你是一位专注于大模型训练与推理领域的学术分析专家。
你的任务是分析 ArXiv 论文并生成专业、严谨、逻辑清晰的学术分析内容。

核心原则：
1. 学术严谨性：使用标准术语，数据准确，逻辑闭环
2. 简洁务实：聚焦重点，避免冗余
3. 客观中立：先客观描述，再合理分析

输出格式要求：
- 中文简介：150-250字，结构：背景→核心目标→创新方法→实验验证→核心结论
- 英文简介：100-180词，与中文完全对应，被动语态
- 核心创新点：分点阐述，说明"创新是什么+解决了什么问题"
- 实验分析：简洁呈现实验设置、对比对象、关键指标"""

PAPER_ANALYSIS_PROMPT = """请分析以下 ArXiv 论文，生成符合学术规范的深度分析内容。

## 论文信息

**标题**: {title}

**作者**: {authors}

**ArXiv ID**: {arxiv_id}

**分类**: {categories}

**摘要**:
{abstract}

---

## 输出要求

请严格按照以下 JSON 格式输出，不要输出其他内容：

```json
{{
  "cn_abstract": "中文简介（150-250字，结构：背景→核心目标→创新方法→实验验证→核心结论）",
  "en_abstract": "英文简介（100-180词，与中文完全对应，被动语态）",
  "innovations": [
    "创新点1：具体创新内容 + 解决了什么问题",
    "创新点2：具体创新内容 + 解决了什么问题"
  ],
  "experiments": "实验分析：模型、数据集、硬件环境、关键指标对比、实验结论",
  "conclusion": "结论与局限：核心贡献总结 + 潜在不足分析"
}}
```

注意：
1. 聚焦大模型训练与推理相关技术（预训练、微调、量化、推理加速、显存优化等）
2. 使用领域标准术语，避免口语化表述
3. 如摘要信息不足，可标注"信息不足，待补充"
4. 确保中英文信息完全对应"""


class AIContentGenerator:
    """AI 内容生成器"""

    def __init__(self, config: dict):
        self.config = config
        self.provider = config.get("provider", "zhipu")
        self.api_key = os.getenv("ZHIPU_API_KEY") or config.get("api_key", "")
        self.model = config.get("model", "glm-4-flash")
        self.temperature = config.get("temperature", 0.7)
        self.max_tokens = config.get("max_tokens", 4000)
        self.timeout = config.get("timeout", 60)

    def _call_zhipu_api(self, system_prompt: str, user_prompt: str) -> dict:
        """调用智谱AI API"""
        url = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "temperature": self.temperature,
            "max_tokens": self.max_tokens
        }

        response = requests.post(url, headers=headers, json=payload, timeout=self.timeout)
        response.raise_for_status()
        result = response.json()

        return result

    def analyze_paper(self, paper: ArXivPaper) -> dict:
        """分析单篇论文，返回结构化分析结果"""
        prompt = PAPER_ANALYSIS_PROMPT.format(
            title=paper.title,
            authors=", ".join(paper.authors[:5]) + (" 等" if len(paper.authors) > 5 else ""),
            arxiv_id=paper.arxiv_id,
            categories=", ".join(paper.categories),
            abstract=paper.abstract
        )

        try:
            result = self._call_zhipu_api(SYSTEM_PROMPT, prompt)
            content = result["choices"][0]["message"]["content"]

            # 提取 JSON 内容
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]

            analysis = json.loads(content.strip())
            return analysis

        except Exception as e:
            logger.error(f"AI analysis failed: {e}")
            return {
                "cn_abstract": f"分析失败：{str(e)}",
                "en_abstract": f"Analysis failed: {str(e)}",
                "innovations": ["AI 分析失败，请检查日志"],
                "experiments": "AI 分析失败",
                "conclusion": "分析失败，请检查配置"
            }

    def is_configured(self) -> bool:
        """检查 AI 是否已配置"""
        return bool(self.api_key)


class ContentGeneratorSkill:
    """
    内容生成技能

    功能：将 ArXiv 论文数据转化为符合学术规范的博客文案
    支持：AI 深度分析、中英文双语、结构化输出
    """

    DEFAULT_CONFIG = {
        "title_prefix": "ArXiv 大模型训推进展 - ",
        "default_category": "AI/大模型",
        "default_style": "academic",
        "max_abstract_length": 500,
        "include_pdf_link": True,
    }

    def __init__(self, config: Optional[dict] = None, ai_config: Optional[dict] = None):
        """初始化内容生成器"""
        self.config = {**self.DEFAULT_CONFIG, **(config or {})}
        self.ai_generator = None
        if ai_config:
            self.ai_generator = AIContentGenerator(ai_config)

    def _format_authors(self, authors: List[str]) -> str:
        """格式化作者列表"""
        if not authors:
            return "未知"
        if len(authors) <= 3:
            return ", ".join(authors)
        return f"{', '.join(authors[:3])} 等"

    def _format_categories(self, categories: List[str]) -> str:
        """格式化分类标签"""
        if not categories:
            return "未分类"
        return ", ".join(categories[:5])

    def _extract_tags(self, papers: List[ArXivPaper]) -> List[str]:
        """从论文中提取标签"""
        tags = set()
        for paper in papers:
            tags.update(paper.categories[:3])
            title_lower = paper.title.lower()
            keywords = ["transformer", "attention", "llm", "gpt", "bert",
                       "diffusion", "training", "inference", "optimization",
                       "quantization", "distillation", "parallel", "lora"]
            for kw in keywords:
                if kw in title_lower or kw in paper.abstract.lower():
                    tags.add(kw.upper())

        return list(tags)[:10]

    def _generate_summary(self, papers: List[ArXivPaper]) -> str:
        """生成文章摘要"""
        count = len(papers)
        if count == 0:
            return "暂无论文数据。"

        categories = set()
        for paper in papers:
            categories.update(paper.categories[:2])

        return (
            f"本期收录 {count} 篇大模型训练与推理相关论文，"
            f"涵盖 {', '.join(list(categories)[:3])} 等领域。"
        )

    def _generate_paper_section(self, paper: ArXivPaper, index: int,
                                analysis: Optional[dict] = None) -> str:
        """生成单篇论文的分析内容"""
        section = f"## 📄 {index}. {paper.title}\n\n"

        # 基本信息
        section += f"**作者 (Authors)**: {self._format_authors(paper.authors)}\n\n"
        if paper.submitted_date:
            section += f"**发布日期 (Date)**: {paper.submitted_date}\n\n"
        section += f"**ArXiv ID**: [{paper.arxiv_id}]({paper.url})\n\n"

        if self.config.get("include_pdf_link") and paper.pdf_url:
            section += f"**PDF**: [{paper.pdf_url}]({paper.pdf_url})\n\n"

        section += f"**分类 (Categories)**: {self._format_categories(paper.categories)}\n\n"

        section += "---\n\n"

        # AI 分析内容（如果有）
        if analysis:
            # 中英文简介
            section += "### 📋 中英文简介 (Abstract)\n\n"
            section += f"**中文简介**:\n\n{analysis.get('cn_abstract', '暂无')}\n\n"
            section += f"**Abstract**:\n\n{analysis.get('en_abstract', 'N/A')}\n\n"

            # 核心创新点
            innovations = analysis.get('innovations', [])
            if innovations:
                section += "### 💡 核心创新点 (Key Innovations)\n\n"
                for i, inn in enumerate(innovations, 1):
                    section += f"{i}. {inn}\n"
                section += "\n"

            # 实验分析
            experiments = analysis.get('experiments', '')
            if experiments:
                section += "### 🔬 实验分析 (Experiments)\n\n"
                section += f"{experiments}\n\n"

            # 结论与局限
            conclusion = analysis.get('conclusion', '')
            if conclusion:
                section += "### 📝 结论与局限 (Conclusion & Limitations)\n\n"
                section += f"{conclusion}\n\n"
        else:
            # 无 AI 分析时，使用原始摘要
            section += "### 📋 摘要 (Abstract)\n\n"
            abstract = paper.abstract
            max_len = self.config.get("max_abstract_length", 500)
            if len(abstract) > max_len:
                abstract = abstract[:max_len].rsplit(" ", 1)[0] + "..."
            section += f"{abstract}\n\n"

        return section

    def execute(self, papers: List[ArXivPaper], style: str = None,
                title_prefix: str = None) -> GeneratorResult:
        """
        执行内容生成任务

        Args:
            papers: 论文列表
            style: 写作风格（当前统一使用 academic）
            title_prefix: 标题前缀

        Returns:
            GeneratorResult: 生成结果
        """
        if not papers:
            return GeneratorResult(
                success=False,
                error_message="论文列表为空，无法生成内容"
            )

        title_prefix = title_prefix or self.config["title_prefix"]

        try:
            content_parts = []

            # 引言
            content_parts.append(
                "# 大模型训练与推理研究进展\n\n"
                "以下为 ArXiv 最新收录的相关论文深度分析。\n\n"
                "---\n\n"
            )

            # 分析每篇论文
            use_ai = self.ai_generator and self.ai_generator.is_configured()

            if use_ai:
                logger.info(f"Using AI analysis for {len(papers)} papers")
            else:
                logger.info("AI not configured, using template mode")

            for idx, paper in enumerate(papers, 1):
                analysis = None
                if use_ai:
                    try:
                        analysis = self.ai_generator.analyze_paper(paper)
                        logger.info(f"AI analysis completed for paper {idx}")
                    except Exception as e:
                        logger.warning(f"AI analysis failed for paper {idx}: {e}")

                paper_section = self._generate_paper_section(paper, idx, analysis)
                content_parts.append(paper_section)

            # 结尾
            content_parts.append(
                "---\n\n"
                "*本文由 ArXiv Blog Agent 基于智谱AI分析生成，内容仅供参考。*\n"
            )

            today = datetime.now().strftime("%Y年%m月%d日")
            title = f"{title_prefix}{today}"

            summary = self._generate_summary(papers)
            tags = self._extract_tags(papers)

            blog_content = BlogContent(
                title=title,
                summary=summary,
                content="".join(content_parts),
                tags=tags,
                category=self.config["default_category"],
                created_at=datetime.now().isoformat(),
            )

            return GeneratorResult(success=True, blog_content=blog_content)

        except Exception as e:
            logger.exception("Content generation failed")
            return GeneratorResult(success=False, error_message=str(e))


def generate_blog_content(papers: List[ArXivPaper],
                          style: str = "academic",
                          config: dict = None,
                          ai_config: dict = None) -> GeneratorResult:
    """
    便捷函数：生成博客内容

    Args:
        papers: 论文列表
        style: 写作风格
        config: 内容配置
        ai_config: AI 配置

    Returns:
        GeneratorResult: 生成结果
    """
    generator = ContentGeneratorSkill(config, ai_config)
    return generator.execute(papers=papers, style=style)

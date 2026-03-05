# Skill Registry

## 1. 概述

Skill Registry（技能注册表）是 ArXiv Blog Agent 的技能管理中心，负责：
- **技能发现**：自动发现可用技能
- **技能注册**：管理技能元数据
- **技能调用**：统一调度接口
- **生命周期管理**：初始化、执行、清理

## 2. 已注册技能列表

| Skill ID | 名称 | 功能 | 状态 |
|----------|------|------|------|
| `arxiv_scraper` | ArXiv 爬取技能 | 爬取 ArXiv 论文数据 | ✅ 可用 |
| `content_generator` | 内容生成技能 | 生成博客文案 | ✅ 可用 |
| `blog_poster` | 博客发布技能 | 发布到 WordPress | ✅ 可用 |
| `network_adapter` | 网络适配技能 | HTTP 客户端封装 | ✅ 可用 |

## 3. 技能元数据

### 3.1 arxiv_scraper

```yaml
skill_id: arxiv_scraper
name: ArXiv 论文爬取技能
version: 1.0.0
description: 从 ArXiv 搜索并提取大模型训练推理相关论文信息
author: ArXiv Blog Agent Team
tags:
  - crawler
  - arxiv
  - paper

inputs:
  query:
    type: string
    required: false
    default: "large model training inference"
    description: 搜索关键词
  max_results:
    type: integer
    required: false
    default: 10
    description: 最大返回结果数
  sort_by:
    type: string
    required: false
    default: "submitted_date"
    description: 排序字段
  sort_order:
    type: string
    required: false
    default: "desc"
    description: 排序方向

outputs:
  success:
    type: boolean
    description: 是否成功
  papers:
    type: list[ArXivPaper]
    description: 论文列表
  error_message:
    type: string
    description: 错误信息

config:
  base_url: "https://arxiv.org/search/"
  timeout: 30
  max_retries: 3
  proxy: null
  ssl_verify: true

dependencies:
  - requests>=2.28.0
  - beautifulsoup4>=4.12.0
  - lxml>=4.9.0
```

### 3.2 content_generator

```yaml
skill_id: content_generator
name: 内容生成技能
version: 1.0.0
description: 将 ArXiv 论文数据转化为博客文案格式
author: ArXiv Blog Agent Team
tags:
  - generator
  - blog
  - content

inputs:
  papers:
    type: list[ArXivPaper]
    required: true
    description: 论文列表
  style:
    type: string
    required: false
    default: "professional"
    description: 写作风格 (professional/casual/academic)
  language:
    type: string
    required: false
    default: "zh"
    description: 输出语言
  title_prefix:
    type: string
    required: false
    default: "ArXiv 大模型训推进展 - "
    description: 标题前缀

outputs:
  success:
    type: boolean
    description: 是否成功
  blog_content:
    type: BlogContent
    description: 博客内容
  error_message:
    type: string
    description: 错误信息

config:
  title_prefix: "ArXiv 大模型训推进展 - "
  default_category: "AI/大模型"
  max_abstract_length: 300

dependencies:
  - python>=3.8
```

### 3.3 blog_poster

```yaml
skill_id: blog_poster
name: 博客发布技能
version: 1.0.0
description: 将博客内容发布到 WordPress.com
author: ArXiv Blog Agent Team
tags:
  - publisher
  - wordpress
  - blog

inputs:
  blog_content:
    type: BlogContent
    required: true
    description: 博客内容
  status:
    type: string
    required: false
    default: "publish"
    description: 发布状态 (publish/draft/private)

outputs:
  success:
    type: boolean
    description: 是否成功
  post_id:
    type: string
    description: 文章 ID
  post_url:
    type: string
    description: 文章链接
  error_message:
    type: string
    description: 错误信息

config:
  api_base: "https://public-api.wordpress.com/rest/v1.1"
  blog_id: "791025341"
  access_token: "${WORDPRESS_ACCESS_TOKEN}"
  default_status: "publish"
  timeout: 20

dependencies:
  - requests>=2.28.0

notes:
  - 默认 access_token 仅供测试，实际使用需替换为真实令牌
  - 支持 WordPress.com REST API
  - 预留内网博客平台扩展接口
```

### 3.4 network_adapter

```yaml
skill_id: network_adapter
name: 网络适配技能
version: 1.0.0
description: 统一 HTTP 客户端接口，支持代理和 SSL 配置
author: ArXiv Blog Agent Team
tags:
  - network
  - http
  - adapter

inputs:
  method:
    type: string
    required: true
    description: HTTP 方法
  url:
    type: string
    required: true
    description: 请求 URL
  kwargs:
    type: dict
    required: false
    description: 额外参数

outputs:
  response:
    type: requests.Response
    description: HTTP 响应对象

config:
  timeout: 20
  max_retries: 3
  proxy: null
  ssl_verify: true
  pool_connections: 10

dependencies:
  - requests>=2.28.0
  - urllib3>=1.26.0
```

## 4. 调用方式

### 4.1 直接调用
```python
from skills.arxiv_scraper import ArXivScraperSkill
from skills.content_generator import ContentGeneratorSkill
from skills.blog_poster import BlogPosterSkill

# 创建技能实例
scraper = ArXivScraperSkill()
generator = ContentGeneratorSkill()
poster = BlogPosterSkill()

# 执行
result1 = scraper.execute()
if result1.success:
    result2 = generator.execute(result1.papers)
    if result2.success:
        result3 = poster.execute(result2.blog_content)
```

### 4.2 通过注册表调用
```python
from skills.registry import SkillRegistry

# 获取技能
scraper = SkillRegistry.get_skill("arxiv_scraper")
result = scraper.execute(query="transformer")
```

## 5. 技能依赖关系

```
arxiv_scraper
    └── network_adapter (可选，内网时使用)

content_generator
    └── arxiv_scraper.output (数据依赖)

blog_poster
    ├── content_generator.output (数据依赖)
    └── network_adapter (隐式依赖)
```

## 6. 扩展新技能

### 6.1 技能模板
```python
from dataclasses import dataclass
from typing import Optional

@dataclass
class MySkillResult:
    success: bool
    data: Optional[dict] = None
    error_message: str = ""

class MySkill:
    """自定义技能"""

    DEFAULT_CONFIG = {
        "param1": "default_value",
    }

    def __init__(self, config: dict = None):
        self.config = {**self.DEFAULT_CONFIG, **(config or {})}

    def execute(self, **kwargs) -> MySkillResult:
        """执行技能"""
        try:
            # 实现逻辑
            return MySkillResult(success=True, data={})
        except Exception as e:
            return MySkillResult(success=False, error_message=str(e))
```

### 6.2 注册新技能
```python
# 在 skills/__init__.py 中注册
from skills.my_skill import MySkill

SkillRegistry.register("my_skill", MySkill)
```

## 7. 版本兼容性

| Skill | 最低版本 | 当前版本 | 兼容变更 |
|-------|---------|---------|---------|
| arxiv_scraper | 1.0.0 | 1.0.0 | - |
| content_generator | 1.0.0 | 1.0.0 | - |
| blog_poster | 1.0.0 | 1.0.0 | - |
| network_adapter | 1.0.0 | 1.0.0 | - |

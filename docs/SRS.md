# Software Requirements Specification (SRS)

## ArXiv Blog Agent

**版本**: 1.0.0
**日期**: 2026-03-06
**标准**: ISO/IEC/IEEE 29148

---

## 1. 引言

### 1.1 目的

ArXiv Blog Agent 是一个自动化内容生产系统，用于：
- 从 ArXiv 爬取大模型训练与推理相关的最新论文
- 将论文信息转化为博客格式文案
- 自动发布到 WordPress.com 博客平台

### 1.2 范围

本系统支持：
- 公网环境直接运行
- 内网环境扩展部署
- 多种写作风格输出
- 干运行测试模式

### 1.3 定义

| 术语 | 定义 |
|-----|------|
| Agent | 协调多个 Skill 完成复杂任务的编排器 |
| Skill | 独立的功能模块，完成特定任务 |
| 干运行 | 测试模式，不实际发送网络请求 |

---

## 2. 总体描述

### 2.1 产品视角

```
┌─────────────────────────────────────────────────────────────┐
│                   ArXiv Blog Agent                          │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Agent 层    │  │ Skill 层    │  │ 工具层      │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
│  输入: 搜索关键词、配置参数                                 │
│  输出: 发布的博客文章 URL                                   │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 用户特征

| 用户类型 | 描述 |
|---------|------|
| 开发者 | 运行 Agent 进行论文爬取和博客发布 |
| 运维人员 | 部署到内网环境，配置代理和认证 |

### 2.3 约束

- Python 3.10+ 运行环境
- 网络访问 ArXiv API 或内部镜像
- WordPress.com 访问令牌（实际发布时）

---

## 3. 功能需求

### 3.1 FR-001: ArXiv 论文爬取

**描述**: 通过 ArXiv API 搜索并获取论文信息

**输入**:
- 搜索关键词 (query)
- 最大结果数 (max_results)

**输出**:
- 论文列表 (ArXivPaper[])
- 包含: 标题、作者、摘要、ArXiv ID、URL、PDF URL、提交日期、分类

**验收标准**:
- [ ] 能够成功调用 ArXiv API
- [ ] 返回符合搜索条件的论文列表
- [ ] 支持重试机制（默认 3 次）
- [ ] 支持代理配置

### 3.2 FR-002: 博客内容生成

**描述**: 将论文数据转化为博客格式文案

**输入**:
- 论文列表 (ArXivPaper[])
- 写作风格 (professional/casual/academic)

**输出**:
- 博客标题
- 文章摘要
- Markdown 格式正文
- 标签列表

**验收标准**:
- [ ] 支持三种写作风格
- [ ] 生成的 Markdown 格式正确
- [ ] 自动提取标签
- [ ] 包含论文链接和 PDF 链接

### 3.3 FR-003: 博客发布

**描述**: 发布博客内容到 WordPress.com

**输入**:
- 博客内容 (BlogContent)
- 发布状态 (publish/draft)

**输出**:
- 发布成功/失败状态
- 文章 ID
- 文章 URL

**验收标准**:
- [ ] 支持 WordPress.com REST API
- [ ] 支持干运行模式（Mock 发布）
- [ ] 处理认证错误和网络错误
- [ ] 返回明确的错误信息

### 3.4 FR-004: 网络适配

**描述**: 提供统一的 HTTP 客户端接口

**功能**:
- 代理支持 (HTTP/HTTPS/SOCKS)
- SSL 证书配置
- 连接池管理
- 重试机制

**验收标准**:
- [ ] 支持配置代理
- [ ] 支持跳过 SSL 验证
- [ ] 连接池正常工作

### 3.5 FR-005: 工作流编排

**描述**: Agent 协调各 Skill 完成完整工作流

**工作流**:
1. 爬取 ArXiv 论文
2. 生成博客文案
3. 发布到博客平台

**验收标准**:
- [ ] 状态管理正确
- [ ] 错误处理完善
- [ ] 支持干运行模式
- [ ] 日志记录完整

### 3.6 FR-006: 配置管理

**描述**: 集中式配置管理

**功能**:
- 单一配置文件
- 环境变量覆盖
- 默认值机制

**验收标准**:
- [ ] 所有配置项集中在一个 YAML 文件
- [ ] 支持环境变量覆盖
- [ ] 默认值确保无需配置即可运行

---

## 4. 非功能需求

### 4.1 NFR-001: 性能

- 单次工作流执行时间 < 30 秒（爬取 10 篇论文）
- 支持并发请求（连接池）

### 4.2 NFR-002: 可靠性

- 网络请求重试机制
- 错误日志记录
- 异常状态恢复

### 4.3 NFR-003: 可维护性

- 模块化设计（Skill 解耦）
- 完整的测试覆盖
- 清晰的文档

### 4.4 NFR-004: 可扩展性

- 支持内网环境扩展
- Skill 可替换
- 配置驱动行为

---

## 5. 接口需求

### 5.1 命令行接口

```bash
python src/main.py [OPTIONS]

OPTIONS:
  --config, -c FILE     配置文件路径
  --dry-run, -d         干运行模式
  --query, -q TEXT      搜索关键词
  --max-results, -m N   最大结果数
  --style, -s STYLE     写作风格
  --output, -o FILE     输出结果到文件
  --verbose, -v         详细日志
```

### 5.2 编程接口

```python
from agents.arxiv_blog_agent import ArXivBlogAgent

agent = ArXivBlogAgent(config_path="config.yaml", dry_run=True)
result = agent.run()

if result.success:
    print(f"发布成功: {result.post_url}")
```

---

## 6. 配置需求

### 6.1 集中配置文件 (config.yaml)

所有配置项集中在一个 YAML 文件中，包括：

| 配置项 | 说明 | 默认值 |
|-------|------|--------|
| arxiv.query | 搜索关键词 | "large model training inference" |
| arxiv.max_results | 最大结果数 | 10 |
| arxiv.timeout | 请求超时 | 30 |
| arxiv.proxy | 代理地址 | null |
| content.style | 写作风格 | "professional" |
| content.title_prefix | 标题前缀 | "ArXiv 大模型训推进展 - " |
| blog.api_base | WordPress API 地址 | "https://public-api.wordpress.com/rest/v1.1" |
| blog.blog_id | 博客 ID | "253145378" |
| blog.access_token | 访问令牌 | (测试令牌) |
| blog.status | 发布状态 | "publish" |
| network.timeout | 网络超时 | 20 |
| network.proxy | 全局代理 | null |
| network.ssl_verify | SSL 验证 | true |
| logging.level | 日志级别 | "INFO" |
| logging.file | 日志文件 | "./logs/agent.log" |

---

## 7. 验收标准

### 7.1 功能验收

- [ ] 成功爬取 ArXiv 论文
- [ ] 生成格式正确的博客内容
- [ ] 支持干运行模式
- [ ] 配置文件正确加载

### 7.2 质量验收

- [ ] 测试覆盖率 > 80%
- [ ] 所有测试通过
- [ ] 无 Pylint 警告

---

## 8. 附录

### 8.1 参考文献

- ArXiv API: https://arxiv.org/help/api/
- WordPress.com REST API: https://developer.wordpress.com/docs/api/

### 8.2 术语表

| 术语 | 英文 | 说明 |
|-----|------|------|
| 软件 | Software | 计算机程序和相关文档 |
| 需求 | Requirement | 系统必须满足的条件或能力 |

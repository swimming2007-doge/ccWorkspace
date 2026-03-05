# Agent 工作流

## 1. 工作流概述

ArXiv Blog Agent 执行一个三阶段的线性工作流：

```
┌─────────────────────────────────────────────────────────────────┐
│                        完整工作流                               │
│                                                                 │
│  ┌───────────┐     ┌───────────┐     ┌───────────┐            │
│  │  Stage 1  │────▶│  Stage 2  │────▶│  Stage 3  │            │
│  │  爬取论文  │     │  生成文案  │     │  发布博客  │            │
│  └───────────┘     └───────────┘     └───────────┘            │
│       │                 │                 │                    │
│       ▼                 ▼                 ▼                    │
│  ArXivPaper[]      BlogContent       PostResult              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 2. 详细流程

### 2.1 初始化阶段

```python
def initialize(self):
    """初始化 Agent"""
    # 1. 加载配置
    self.config = self._load_config()

    # 2. 初始化日志
    self.logger = self._setup_logger()

    # 3. 注册技能
    self._register_skills()

    # 4. 验证配置
    self._validate_config()

    # 5. 更新状态
    self.status.state = AgentState.IDLE
```

### 2.2 Stage 1: 爬取论文

```python
def _step_scrape(self) -> ScraperResult:
    """
    Step 1: 爬取 ArXiv 论文

    输入: 搜索关键词配置
    处理:
        1. 构建 ArXiv 搜索 URL
        2. 发送 HTTP 请求
        3. 解析 HTML 响应
        4. 提取论文信息
    输出: List[ArXivPaper]
    """
    self.status.state = AgentState.SCRAPING
    self.status.current_step = "scrape"
    self.logger.info("开始爬取 ArXiv 论文...")

    try:
        result = self.skills["arxiv_scraper"].execute(
            query=self.config.arxiv_query,
            max_results=self.config.arxiv_max_results,
        )

        if result.success:
            self.status.papers_count = len(result.papers)
            self.logger.info(f"爬取完成，获取 {len(result.papers)} 篇论文")
        else:
            self.logger.error(f"爬取失败: {result.error_message}")

        return result

    except Exception as e:
        self.logger.exception("爬取异常")
        return ScraperResult(success=False, error_message=str(e))
```

### 2.3 Stage 2: 生成文案

```python
def _step_generate(self, papers: List[ArXivPaper]) -> GeneratorResult:
    """
    Step 2: 生成博客文案

    输入: List[ArXivPaper]
    处理:
        1. 格式化论文信息
        2. 生成标题和摘要
        3. 组装 Markdown 正文
        4. 提取标签
    输出: BlogContent
    """
    self.status.state = AgentState.GENERATING
    self.status.current_step = "generate"
    self.logger.info("开始生成博客文案...")

    if not papers:
        return GeneratorResult(
            success=False,
            error_message="论文列表为空"
        )

    try:
        result = self.skills["content_generator"].execute(
            papers=papers,
            style=self.config.content_style,
            language=self.config.content_language,
            title_prefix=self.config.title_prefix,
        )

        if result.success:
            self.logger.info("文案生成完成")
        else:
            self.logger.error(f"生成失败: {result.error_message}")

        return result

    except Exception as e:
        self.logger.exception("生成异常")
        return GeneratorResult(success=False, error_message=str(e))
```

### 2.4 Stage 3: 发布博客

```python
def _step_post(self, blog_content: BlogContent) -> PostResult:
    """
    Step 3: 发布到博客平台

    输入: BlogContent
    处理:
        1. 构建 WordPress API 请求
        2. 发送发布请求
        3. 解析响应结果
    输出: PostResult
    """
    self.status.state = AgentState.POSTING
    self.status.current_step = "post"
    self.logger.info("开始发布博客...")

    # 干运行模式检查
    if self.config.dry_run:
        self.logger.info("干运行模式，跳过实际发布")
        return PostResult(
            success=True,
            post_id="dry_run",
            post_url="https://example.com/dry-run",
        )

    try:
        result = self.skills["blog_poster"].execute(
            blog_content=blog_content,
            status=self.config.blog_status,
        )

        if result.success:
            self.status.post_url = result.post_url
            self.logger.info(f"发布成功: {result.post_url}")
        else:
            self.logger.error(f"发布失败: {result.error_message}")

        return result

    except Exception as e:
        self.logger.exception("发布异常")
        return PostResult(success=False, error_message=str(e))
```

## 3. 完整工作流执行

```python
def run(self) -> AgentResult:
    """
    执行完整工作流

    Returns:
        AgentResult: 执行结果
    """
    self.status.start_time = datetime.now()
    self.status.state = AgentState.INITIALIZING

    self.logger.info("=" * 50)
    self.logger.info("ArXiv Blog Agent 启动")
    self.logger.info("=" * 50)

    try:
        # Stage 1: 爬取
        scrape_result = self._step_scrape()
        if not scrape_result.success:
            return self._create_error_result(scrape_result.error_message)

        # Stage 2: 生成
        generate_result = self._step_generate(scrape_result.papers)
        if not generate_result.success:
            return self._create_error_result(generate_result.error_message)

        # Stage 3: 发布
        post_result = self._step_post(generate_result.blog_content)
        if not post_result.success:
            return self._create_error_result(post_result.error_message)

        # 成功完成
        self.status.state = AgentState.COMPLETED
        self.status.end_time = datetime.now()

        return AgentResult(
            success=True,
            papers=scrape_result.papers,
            blog_content=generate_result.blog_content,
            post_url=post_result.post_url,
            duration=(self.status.end_time - self.status.start_time).total_seconds(),
        )

    except Exception as e:
        self.status.state = AgentState.FAILED
        self.status.end_time = datetime.now()
        self.logger.exception("工作流执行失败")
        return AgentResult(success=False, error_message=str(e))
```

## 4. 异常处理流程

```
┌───────────────────────────────────────────────────────────────┐
│                        异常处理流程                            │
│                                                               │
│  ┌─────────────┐                                             │
│  │  执行步骤   │                                             │
│  └──────┬──────┘                                             │
│         │                                                     │
│         ▼                                                     │
│  ┌─────────────┐     Yes    ┌─────────────┐                  │
│  │  是否成功？ │───────────▶│  继续下一步  │                  │
│  └──────┬──────┘             └─────────────┘                  │
│         │ No                                                  │
│         ▼                                                     │
│  ┌─────────────┐     Yes    ┌─────────────┐                  │
│  │  可重试？   │───────────▶│   重试执行   │                  │
│  └──────┬──────┘             └─────────────┘                  │
│         │ No                                                  │
│         ▼                                                     │
│  ┌─────────────┐     Yes    ┌─────────────┐                  │
│  │  可降级？   │───────────▶│   降级处理   │                  │
│  └──────┬──────┘             └─────────────┘                  │
│         │ No                                                  │
│         ▼                                                     │
│  ┌─────────────┐                                             │
│  │  标记失败   │                                             │
│  └─────────────┘                                             │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## 5. 状态检查点

```python
def _save_checkpoint(self):
    """保存状态检查点"""
    checkpoint = {
        "status": self.status.to_dict(),
        "config": asdict(self.config),
        "timestamp": datetime.now().isoformat(),
    }

    # 保存到文件
    checkpoint_path = "./logs/checkpoint.json"
    with open(checkpoint_path, "w") as f:
        json.dump(checkpoint, f, indent=2)

def _load_checkpoint(self) -> Optional[dict]:
    """加载状态检查点"""
    checkpoint_path = "./logs/checkpoint.json"
    if os.path.exists(checkpoint_path):
        with open(checkpoint_path, "r") as f:
            return json.load(f)
    return None

def _resume_from_checkpoint(self, checkpoint: dict):
    """从检查点恢复"""
    # 恢复状态
    self.status = AgentStatus(**checkpoint["status"])

    # 根据中断点继续执行
    if self.status.current_step == "scrape":
        # 从爬取继续
        pass
    elif self.status.current_step == "generate":
        # 从生成继续
        pass
    elif self.status.current_step == "post":
        # 从发布继续
        pass
```

## 6. 并行执行（扩展）

```python
async def run_parallel(self, queries: List[str]) -> List[AgentResult]:
    """
    并行执行多个查询任务

    Args:
        queries: 查询关键词列表

    Returns:
        List[AgentResult]: 每个查询的执行结果
    """
    import asyncio

    tasks = [self._run_single_query(q) for q in queries]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    return [
        r if isinstance(r, AgentResult) else AgentResult(success=False, error_message=str(r))
        for r in results
    ]
```

## 7. 工作流监控

```python
def get_workflow_metrics(self) -> dict:
    """获取工作流指标"""
    return {
        "state": self.status.state.value,
        "papers_processed": self.status.papers_count,
        "duration": (
            (self.status.end_time - self.status.start_time).total_seconds()
            if self.status.end_time else None
        ),
        "success_rate": self._calculate_success_rate(),
    }
```

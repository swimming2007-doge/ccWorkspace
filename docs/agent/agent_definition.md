# Agent 定义

## 1. Agent 概述

### 1.1 角色定义
**ArXiv Blog Agent** 是一个自动化内容生产 Agent，负责：
- 从 ArXiv 爬取大模型训练与推理相关的最新论文
- 将论文信息转化为博客格式文案
- 自动发布到 WordPress.com 博客平台

### 1.2 核心能力
| 能力 | 描述 | 对应 Skill |
|-----|------|-----------|
| 数据采集 | 从 ArXiv 搜索论文 | `arxiv_scraper` |
| 内容生成 | 生成博客文案 | `content_generator` |
| 内容发布 | 发布到博客平台 | `blog_poster` |
| 网络适配 | 支持公网/内网环境 | `network_adapter` |

### 1.3 设计原则
- **技能解耦**：每个 Skill 独立封装，可单独测试和替换
- **配置驱动**：所有参数通过配置文件控制
- **容错设计**：单个 Skill 失败不影响整体流程
- **可观测性**：完整的日志和状态追踪

## 2. Agent 架构

```
┌─────────────────────────────────────────────────────────────┐
│                   ArXiv Blog Agent                          │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  状态管理   │  │  配置管理   │  │  日志管理   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                   工作流引擎                          │ │
│  │  ┌─────────┐    ┌─────────┐    ┌─────────┐          │ │
│  │  │ Step 1  │───▶│ Step 2  │───▶│ Step 3  │          │ │
│  │  │ 爬取    │    │ 生成    │    │ 发布    │          │ │
│  │  └─────────┘    └─────────┘    └─────────┘          │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                   Skill Registry                      │ │
│  │  arxiv_scraper | content_generator | blog_poster      │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 3. 状态管理

### 3.1 状态定义
```python
from enum import Enum
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, Dict, Any

class AgentState(Enum):
    """Agent 状态枚举"""
    IDLE = "idle"                 # 空闲
    INITIALIZING = "initializing" # 初始化中
    SCRAPING = "scraping"         # 爬取中
    GENERATING = "generating"     # 生成中
    POSTING = "posting"           # 发布中
    COMPLETED = "completed"       # 完成
    FAILED = "failed"             # 失败

@dataclass
class AgentStatus:
    """Agent 状态数据结构"""
    state: AgentState = AgentState.IDLE
    current_step: str = ""
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    error: Optional[str] = None
    papers_count: int = 0
    post_url: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "state": self.state.value,
            "current_step": self.current_step,
            "start_time": self.start_time.isoformat() if self.start_time else None,
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "error": self.error,
            "papers_count": self.papers_count,
            "post_url": self.post_url,
        }
```

### 3.2 状态转换
```
IDLE ──▶ INITIALIZING ──▶ SCRAPING ──▶ GENERATING ──▶ POSTING ──▶ COMPLETED
  │           │              │             │            │
  │           │              │             │            │
  └───────────┴──────────────┴─────────────┴────────────┴──▶ FAILED
```

## 4. 配置管理

### 4.1 配置加载优先级
1. 环境变量（最高优先级）
2. 命令行参数
3. 配置文件（config.yaml）
4. 默认值（最低优先级）

### 4.2 配置结构
```python
@dataclass
class AgentConfig:
    """Agent 配置数据结构"""
    # ArXiv 爬取配置
    arxiv_query: str = "large model training inference"
    arxiv_max_results: int = 10

    # 内容生成配置
    content_style: str = "professional"
    content_language: str = "zh"
    title_prefix: str = "ArXiv 大模型训推进展 - "

    # 博客发布配置
    blog_status: str = "publish"  # publish/draft
    blog_id: str = "253145378"

    # 网络配置
    timeout: int = 30
    proxy: Optional[str] = None
    ssl_verify: bool = True

    # 运行配置
    dry_run: bool = False  # 干运行模式（不实际发布）
```

## 5. 日志管理

### 5.1 日志级别
- `DEBUG`: 详细调试信息
- `INFO`: 关键步骤信息
- `WARNING`: 警告信息
- `ERROR`: 错误信息

### 5.2 日志格式
```
[%(asctime)s] %(levelname)s [%(name)s.%(funcName)s:%(lineno)d] %(message)s
```

### 5.3 日志输出
- 控制台输出（INFO 及以上）
- 文件输出（DEBUG 及以上，保存到 `./logs/agent.log`）

## 6. 错误处理策略

### 6.1 重试策略
| 阶段 | 重试次数 | 重试间隔 | 超时时间 |
|-----|---------|---------|---------|
| 爬取 | 3 | 2s | 30s |
| 生成 | 1 | 0s | 10s |
| 发布 | 3 | 5s | 20s |

### 6.2 降级策略
- 爬取失败：使用缓存数据或返回错误
- 生成失败：跳过当前论文，继续处理其他
- 发布失败：保存到本地文件，稍后重试

### 6.3 错误恢复
```python
def handle_error(self, error: Exception, context: dict):
    """统一错误处理"""
    self.logger.error(f"Error in {context['step']}: {error}")
    self.status.error = str(error)

    # 保存现场状态
    self._save_checkpoint()

    # 根据错误类型决定是否重试
    if isinstance(error, NetworkError):
        return self._retry_with_backoff()
    elif isinstance(error, ValidationError):
        return self._skip_and_continue()
    else:
        raise error
```

## 7. 扩展接口

### 7.1 自定义 Skill 集成
```python
class CustomAgent(ArXivBlogAgent):
    """自定义 Agent 示例"""

    def _register_skills(self):
        super()._register_skills()
        # 注册自定义 Skill
        self.skills["custom_skill"] = CustomSkill(self.config.custom)
```

### 7.2 工作流扩展
```python
def custom_workflow(self):
    """自定义工作流"""
    # 前置处理
    self._pre_process()

    # 执行标准流程
    result = self._execute_workflow()

    # 后置处理
    self._post_process(result)

    return result
```

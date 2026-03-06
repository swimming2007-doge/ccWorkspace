# ArXiv Blog Agent

自动从 ArXiv 爬取大模型训练与推理相关论文，生成博客文案并发布到 WordPress。

## 快速开始

```bash
# 安装依赖
pip install -r requirements.txt

# 干运行模式（测试）
python src/main.py --dry-run

# 实际发布
python src/main.py
```

## 配置文件

**所有配置集中在一个文件：`config.yaml`**

```bash
# 查看当前配置
python src/main.py --show-config

# 使用自定义配置文件
python src/main.py -c config.internal.yaml
```

### 配置结构

```yaml
# ArXiv 爬取配置
arxiv:
  query: "large model training inference"
  max_results: 10
  timeout: 30
  proxy: null           # 内网时配置
  ssl_verify: true

# 内容生成配置
content:
  style: "professional"  # professional / casual / academic
  title_prefix: "ArXiv 大模型训推进展 - "

# 博客发布配置
blog:
  blog_id: "791025341"
  access_token: "${WORDPRESS_TOKEN}"  # 环境变量
  status: "publish"

# 网络配置
network:
  timeout: 20
  proxy: null
  ssl_verify: true

# 日志配置
logging:
  level: "INFO"
  file: "./logs/agent.log"

# Agent 配置
agent:
  dry_run: false
```

## 命令行参数

```bash
python src/main.py [OPTIONS]

Options:
  -c, --config FILE      配置文件路径 (默认: config.yaml)
  -d, --dry-run          干运行模式
  -q, --query TEXT       搜索关键词
  -m, --max-results N    最大结果数
  -s, --style STYLE      写作风格
  -o, --output FILE      输出结果到文件
  --show-config          显示当前配置
  -v, --verbose          详细日志
```

## 内网部署

1. 复制配置文件：
```bash
cp config.yaml config.internal.yaml
```

2. 修改配置：
```yaml
arxiv:
  proxy: "http://internal-proxy:8080"
  ssl_verify: false

blog:
  api_base: "https://internal-blog/api/v1"
  access_token: "${INTERNAL_BLOG_TOKEN}"
  proxy: "http://internal-proxy:8080"
  ssl_verify: false

network:
  proxy: "http://internal-proxy:8080"
  ssl_verify: false
```

3. 设置环境变量：
```bash
export INTERNAL_BLOG_TOKEN="your_token"
```

4. 运行：
```bash
python src/main.py -c config.internal.yaml
```

## 项目结构

```
arxiv_blog_agent/
├── config.yaml              # 集中式配置文件 ★
├── docs/                    # 文档
│   ├── SRS.md              # 需求规格说明
│   ├── DESIGN.md           # 设计文档
│   └── ...                 # 其他文档
├── src/                    # 源代码
│   ├── agents/             # Agent 层
│   ├── skills/             # Skill 层
│   ├── utils/              # 工具层
│   └── main.py             # 入口
├── tests/                   # 测试
├── logs/                    # 日志
├── feature-list.json        # 功能列表
├── requirements.txt         # 依赖
└── README.md               # 说明
```

## 需要配置的项目

| 配置项 | 说明 | 默认值 | 是否需要修改 |
|-------|------|--------|-------------|
| `arxiv.query` | 搜索关键词 | "large model training inference" | 可选 |
| `arxiv.max_results` | 最大结果数 | 10 | 可选 |
| `arxiv.proxy` | 代理地址 | null | 内网必须 |
| `arxiv.ssl_verify` | SSL验证 | true | 内网可能需要 |
| `content.style` | 写作风格 | professional | 可选 |
| `blog.blog_id` | 博客ID | 791025341 | 实际发布时 |
| `blog.access_token` | 访问令牌 | 测试令牌 | **实际发布必须** |
| `blog.status` | 发布状态 | publish | 可选 |
| `network.proxy` | 全局代理 | null | 内网必须 |
| `network.ssl_verify` | SSL验证 | true | 内网可能需要 |
| `agent.dry_run` | 干运行 | false | 可选 |

## License

MIT License

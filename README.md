# ArXiv Blog Agent

自动从 ArXiv 爬取大模型训练与推理相关论文，生成博客文案并发布到 WordPress。

## 功能特性

- **自动化工作流**：一键完成爬取→生成→发布全流程
- **技能模块化**：每个功能独立封装，易于扩展和替换
- **配置驱动**：通过配置文件控制所有行为
- **内网支持**：预留内网扩展接口，支持代理和自定义证书

## 快速开始

### 1. 安装依赖

```bash
pip install -r requirements.txt
```

### 2. 运行（干运行模式，不实际发布）

```bash
python src/main.py --dry-run
```

### 3. 实际发布

```bash
# 修改 configs/config.yaml 中的 access_token 为真实令牌
python src/main.py
```

## 使用方法

### 命令行参数

```bash
# 使用默认配置
python src/main.py

# 干运行模式（测试用）
python src/main.py --dry-run

# 自定义搜索关键词
python src/main.py -q "transformer attention"

# 限制最大结果数
python src/main.py -m 5

# 使用指定配置文件
python src/main.py -c configs/prod_config.yaml

# 显示详细日志
python src/main.py -v

# 输出结果到文件
python src/main.py -o result.json
```

### 作为库使用

```python
from src.agents.arxiv_blog_agent import ArXivBlogAgent

# 创建 Agent
agent = ArXivBlogAgent(dry_run=True)

# 执行工作流
result = agent.run()

if result.success:
    print(f"发布成功: {result.post_url}")
else:
    print(f"执行失败: {result.error_message}")

agent.close()
```

## 配置说明

### 配置文件优先级

1. 命令行参数（最高）
2. 环境变量
3. 配置文件
4. 默认值（最低）

### 主要配置项

```yaml
# configs/config.yaml
agent:
  arxiv_query: "large model training inference"  # 搜索关键词
  arxiv_max_results: 10                           # 最大结果数
  content_style: "professional"                   # 写作风格
  blog_status: "publish"                          # 发布状态

blog_poster:
  blog_id: "791025341"                           # 博客 ID
  access_token: "YOUR_TOKEN"                     # 访问令牌
```

### 获取 WordPress 访问令牌

1. 访问 [WordPress.com Developer](https://developer.wordpress.com/apps/)
2. 创建新应用
3. 使用 OAuth2 流程获取访问令牌

## 项目结构

```
arxiv_blog_agent/
├── docs/                    # 文档
│   ├── plan/               # 规划文档
│   ├── skill/              # Skill 定义文档
│   └── agent/              # Agent 文档
├── src/                    # 源代码
│   ├── agents/             # Agent 实现
│   ├── skills/             # Skill 实现
│   ├── utils/              # 工具类
│   └── main.py             # 入口文件
├── tests/                  # 测试用例
├── configs/                # 配置文件
├── logs/                   # 日志目录
├── requirements.txt        # 依赖清单
└── README.md               # 说明文档
```

## 内网部署

### 1. 修改配置文件

```bash
# 复制生产配置模板
cp configs/prod_config.yaml configs/internal.yaml

# 编辑配置
vim configs/internal.yaml
```

### 2. 配置代理

```yaml
network:
  proxy: "http://internal-proxy:8080"
  ssl_verify: false
```

### 3. 配置内网博客平台

```yaml
blog_poster:
  api_base: "https://internal-blog/api/v1"
  access_token: "${INTERNAL_BLOG_TOKEN}"
```

### 4. 运行

```bash
python src/main.py -c configs/internal.yaml
```

## 测试

```bash
# 运行所有测试
pytest tests/

# 运行指定测试
pytest tests/test_skills/test_arxiv_scraper.py

# 生成覆盖率报告
pytest --cov=src tests/
```

## 注意事项

1. **默认令牌仅供测试**：实际发布前需替换为真实令牌
2. **内网部署**：修改 `prod_config.yaml` 中的网络和认证配置
3. **日志位置**：默认保存在 `./logs/agent.log`

## License

MIT License

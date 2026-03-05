# 技术栈选型

## 1. 核心语言与版本
- **Python 3.10+**：现代异步特性、类型注解支持
- **兼容性**：支持 Python 3.8+ 以适配内网旧环境

## 2. 依赖库选型

### 2.1 HTTP 客户端
| 库 | 用途 | 选型理由 |
|---|------|---------|
| `requests` | 同步 HTTP 请求 | 简单可靠，内网兼容性好 |
| `urllib3` | 底层连接池 | requests 的依赖，支持代理配置 |

### 2.2 HTML 解析
| 库 | 用途 | 选型理由 |
|---|------|---------|
| `beautifulsoup4` | HTML 解析 | 容错性强，易于使用 |
| `lxml` | XML/HTML 解析 | 性能优异，bs4 后端可选 |

### 2.3 配置管理
| 库 | 用途 | 选型理由 |
|---|------|---------|
| `pyyaml` | YAML 配置解析 | 配置文件标准格式 |
| `python-dotenv` | 环境变量管理 | 支持 .env 文件覆盖配置 |

### 2.4 日志系统
| 库 | 用途 | 选型理由 |
|---|------|---------|
| `logging` | 标准日志库 | Python 内置，无需额外依赖 |
| `loguru` | 可选增强日志 | 更友好的 API（可选） |

### 2.5 测试框架
| 库 | 用途 | 选型理由 |
|---|------|---------|
| `pytest` | 单元测试框架 | 生态丰富，插件完善 |
| `pytest-cov` | 测试覆盖率 | CI/CD 集成必需 |
| `responses` | HTTP Mock | 模拟网络请求 |
| `freezegun` | 时间 Mock | 测试时间相关逻辑 |

## 3. 项目结构技术决策

### 3.1 模块化设计
```
src/
├── agents/          # Agent 编排层
├── skills/          # 技能实现层（核心解耦点）
├── utils/           # 工具层（可复用）
└── main.py          # 入口
```

### 3.2 配置分层
```
configs/
├── config.yaml          # 默认配置（公网）
├── dev_config.yaml      # 开发配置
├── prod_config.yaml     # 生产配置（内网模板）
└── logging_config.yaml  # 日志配置
```

## 4. 内网适配技术考量

### 4.1 网络层
- **代理支持**：通过 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量或配置文件
- **SSL 跳过**：支持 `ssl_verify: false` 配置（内网自签名证书）
- **超时调优**：内网延迟可能更高，默认 60s 超时

### 4.2 认证层
- **OAuth2 支持**：预留 OAuth2 客户端配置
- **API Key 支持**：简单的 Header 认证
- **内网 SSO**：可扩展自定义认证模块

### 4.3 部署层
- **Docker 支持**：提供 Dockerfile
- **依赖隔离**：requirements.txt 明确版本锁定
- **离线部署**：支持 wheel 包离线安装

## 5. 完整依赖清单

```txt
# requirements.txt
requests>=2.28.0
beautifulsoup4>=4.12.0
lxml>=4.9.0
PyYAML>=6.0
python-dotenv>=1.0.0

# 测试依赖
pytest>=7.0.0
pytest-cov>=4.0.0
responses>=0.23.0
freezegun>=1.2.0

# 可选依赖（内网扩展）
# pywin32>=305        # Windows 内网集成
# pykerberos>=1.2     # Kerberos 认证
```

## 6. 版本兼容性矩阵

| 组件 | 最低版本 | 推荐版本 | 说明 |
|-----|---------|---------|------|
| Python | 3.8 | 3.10+ | 类型注解需要 3.9+ |
| requests | 2.28.0 | 2.31.0 | 安全更新 |
| beautifulsoup4 | 4.11.0 | 4.12.0 | 性能优化 |
| pytest | 7.0.0 | 7.4.0 | 插件兼容 |

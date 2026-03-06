# RideRecord - 开发指南

本文档为 RideRecord 项目的开发者指南，提供开发规范、工作流程和技术决策参考。

---

## 1. 项目概述

RideRecord 是一款面向骑行爱好者的智能数据记录应用，运行于鸿蒙生态系统。

### 核心特性

- **智能动作检测** - 通过手表传感器检测上车/下车动作，自动启停记录
- **探险导航模式** - 支持公路/探险/混合三种导航模式
- **冒险指数提示** - 实时评估路线风险程度
- **本地优先架构** - 数据存储在本地SQLite，云端仅作备份同步

### 目标平台

| 平台 | 设备 | 技术栈 |
|------|------|--------|
| 手机 | 华为 Mate 70 | HarmonyOS NEXT + ArkTS |
| 手表 | Huawei Watch 3 Pro | Watch OS + ArkTS |
| Web | 浏览器 | Vue 3 + TypeScript |
| 服务端 | 华为云HECS | Node.js + Express + SQLite |

---

## 2. 项目结构

```
rideRecord/
├── phone/                    # 手机应用 (HarmonyOS)
│   ├── entry/
│   ├── features/
│   │   ├── home/
│   │   ├── record/
│   │   ├── navigation/
│   │   ├── profile/
│   │   └── settings/
│   └── shared/
├── watch/                    # 手表应用 (Watch OS)
│   ├── entry/
│   └── shared/
├── server/                   # 服务端 (Node.js)
│   ├── src/
│   │   ├── routes/
│   │   ├── services/
│   │   ├── db/
│   │   └── middleware/
│   └── data/
├── web/                      # Web应用 (Vue 3)
│   ├── src/
│   │   ├── views/
│   │   ├── components/
│   │   ├── stores/
│   │   └── services/
│   └── public/
├── shared/                   # 共享代码
│   ├── types/
│   ├── utils/
│   └── constants/
├── docs/                     # 文档
│   └── plans/
├── scripts/                  # 构建脚本
├── feature-list.json         # 功能清单
├── task-progress.md          # 进度追踪
├── RELEASE_NOTES.md          # 发布说明
└── long-task-guide.md        # 本文档
```

---

## 3. 技术规范

### 3.1 代码风格

- **语言**: TypeScript (服务端/Web), ArkTS (手机/手表)
- **命名规范**:
  - 文件名: kebab-case (如 `ride-service.ts`)
  - 类名: PascalCase (如 `RideService`)
  - 变量/函数: camelCase (如 `getRideRecords`)
  - 常量: UPPER_SNAKE_CASE (如 `MAX_RETRY_COUNT`)
- **注释**: 关键逻辑必须添加注释，复杂算法添加详细说明

### 3.2 Git 提交规范

```
<type>(<scope>): <subject>

<body>

<footer>
```

**类型**:
- `feat`: 新功能
- `fix`: Bug修复
- `docs`: 文档更新
- `style`: 代码格式
- `refactor`: 重构
- `test`: 测试
- `chore`: 构建/工具

**示例**:
```
feat(watch): 实现动作检测核心算法

- 添加加速度计数据采集
- 实现特征提取算法
- 实现骑行状态机

Closes #4
```

### 3.3 分支策略

- `main`: 主分支，稳定版本
- `develop`: 开发分支
- `feature/*`: 功能分支
- `bugfix/*`: Bug修复分支
- `release/*`: 发布分支

---

## 4. 开发工作流

### 4.1 开始新功能

1. 从 `develop` 创建功能分支
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/F004-action-detection
   ```

2. 参考 feature-list.json 中的任务列表

3. 遵循 TDD 流程:
   - 先写测试
   - 实现功能
   - 重构优化

4. 提交代码并通过 CI

5. 创建 Pull Request

### 4.2 质量门禁

每个功能必须通过:

1. **单元测试**: 覆盖率 > 80%
2. **集成测试**: API测试通过
3. **代码审查**: 至少一人 Approve
4. **性能验证**: 无性能退化

### 4.3 功能验收标准

参考 feature-list.json 中每个功能的 `acceptance_criteria` 字段。

---

## 5. 关键技术决策

### 5.1 为什么选择 SQLite?

- **本地优先架构**: 数据主要存储在本地
- **零配置**: 无需服务端数据库配置
- **高性能**: 适合单机场景
- **成本低**: 无数据库服务费用

### 5.2 为什么选择轻量化架构?

- **月成本 < 100元**: 适合个人开发者
- **简单可靠**: 无微服务复杂度
- **易于维护**: 单体应用便于调试

### 5.3 动作检测算法选择

| 方案 | 优点 | 缺点 | 选择 |
|------|------|------|------|
| 决策树 | CPU友好，解释性强 | 精度较低 | ✅ MVP首选 |
| 随机森林 | 精度较高 | 计算量较大 | 备选 |
| 神经网络 | 精度最高 | 需要训练数据 | 未来优化 |

---

## 6. 测试策略

### 6.1 单元测试

- 覆盖核心业务逻辑
- 使用 Jest/Vitest
- Mock 外部依赖

### 6.2 集成测试

- API 端到端测试
- 数据库操作测试
- 第三方服务 Mock

### 6.3 性能测试

- 启动时间 < 3秒
- 内存占用 < 200MB
- 动作检测延迟 < 3秒

### 6.4 真机测试

- Huawei Watch 3 Pro 真实骑行测试
- 收集传感器数据用于算法训练

---

## 7. 部署指南

### 7.1 服务端部署

```bash
# 安装依赖
cd server
npm install

# 配置环境变量
cp .env.example .env
# 编辑 .env 填入实际配置

# 数据库初始化
npx prisma migrate deploy

# 启动服务
npm run start:prod
```

### 7.2 华为云配置

1. 创建 OBS Bucket
2. 配置 AccessKey
3. 设置 CORS 规则

### 7.3 应用发布

参考设计文档第8节「手表应用安装与发布指南」

---

## 8. 常见问题

### Q: 动作检测误触发怎么办?

A: 调整检测灵敏度阈值，确保置信度 > 0.8 才触发状态变化。

### Q: GPS信号丢失如何处理?

A: 实现轨迹插值补全，使用网络定位作为备选。

### Q: 如何减少电池消耗?

A:
- 降低传感器采样频率 (非骑行时可降低到 10Hz)
- 使用低功耗蓝牙模式
- 优化地图渲染

---

## 9. 联系方式

- **Issues**: [GitHub Issues]
- **讨论**: [GitHub Discussions]

---

*最后更新: 2026-03-06*

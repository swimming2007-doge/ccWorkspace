# RideRecord 🚴

<p align="center">
  <strong>智能骑行记录应用 - 动作检测自动启停，探险导航模式</strong>
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#技术架构">技术架构</a> •
  <a href="#快速开始">快速开始</a> •
  <a href="#开发指南">开发指南</a> •
  <a href="#贡献指南">贡献指南</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-HarmonyOS%20NEXT-blue" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/version-0.1.0-orange" alt="Version">
</p>

---

## 简介

RideRecord 是一款面向骑行爱好者的智能数据记录应用，运行于鸿蒙生态系统（华为 Mate 70 手机 + Huawei Watch 3 Pro 手表）。

### 核心亮点

- 🎯 **智能动作检测自动启停** - 通过检测用户骑行动作自动开始/暂停/结束记录，解决忘记手动操作的痛点
- 🗺️ **探险导航模式** - 支持公路/探险/混合三种导航模式，满足探索需求
- 📊 **冒险指数提示** - 实时评估路线风险程度（地形、交通、信号覆盖等）
- 🔄 **全方位数据同步** - 支持云端存储、Web端查看、第三方平台同步

---

## 功能特性

### 🚴 智能启停

| 功能 | 描述 |
|------|------|
| 动作检测 | 通过传感器数据识别上车、下车、踩踏等动作 |
| 自动启停 | 检测到骑行动作自动开始/暂停/结束记录 |
| 状态机管理 | IDLE → RIDING → PAUSED → ENDING |

### 📱 多端协同

| 平台 | 功能 |
|------|------|
| 手机 (HarmonyOS) | 主控制中心，导航，数据分析，设置管理 |
| 手表 (Watch OS) | 实时数据展示，动作检测，心率监测 |
| Web | 数据看板，历史记录查看，路线规划 |
| 服务端 | 数据同步，用户认证，第三方集成 |

### 🗺️ 导航系统

| 模式 | 描述 |
|------|------|
| 公路导航 | 标准公路路线规划，实时语音提示 |
| 探险导航 | 支持土路、村道、山地车道、小径导航 |
| 混合导航 | 自动组合公路与小路的最优路线 |

### 📊 数据展示

- **实时看板**: 速度、距离、时间、心率、海拔
- **统计分析**: 日/周/月/年统计，趋势分析
- **骑行详情**: 轨迹地图，速度/心率/海拔图表
- **心率区间**: Z1-Z5 区间分布可视化

### 🔄 同步与分享

- **云端同步**: 华为云 OBS 存储，断点续传
- **微信分享**: 好友/朋友圈分享，多种模板
- **Strava 同步**: OAuth 2.0，自动同步骑行数据

### 📥 离线地图

- 按区域下载地图瓦片
- 存储空间管理
- 自动清理策略

---

## 技术架构

```
┌─────────────────────────────────────────────────────────┐
│                    RideRecord 架构                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   ┌─────────────┐    BLE     ┌─────────────┐           │
│   │   手机应用   │◄──────────►│   手表应用   │           │
│   │ (HarmonyOS) │            │ (Watch OS)  │           │
│   │   ArkTS     │            │   ArkTS     │           │
│   └──────┬──────┘            └─────────────┘           │
│          │                                               │
│          │ HTTPS                                         │
│          ▼                                               │
│   ┌─────────────┐    ┌─────────────┐                    │
│   │   服务端    │    │   Web 端    │                    │
│   │  Node.js    │    │  Vue 3 + TS │                    │
│   │   Express   │    │   Vite      │                    │
│   └─────────────┘    └─────────────┘                    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### 技术栈

| 平台 | 语言 | 框架 | 存储 |
|------|------|------|------|
| 手机 | ArkTS | ArkUI | SQLite |
| 手表 | ArkTS | ArkUI (Watch) | Preferences |
| 服务端 | TypeScript | Express | SQLite + OBS |
| Web | TypeScript | Vue 3 | - |

---

## 快速开始

### 环境要求

- Node.js 20 LTS
- DevEco Studio 5.0+
- HarmonyOS NEXT SDK

### 克隆仓库

```bash
git clone https://github.com/your-org/riderecord.git
cd riderecord
```

### 服务端启动

```bash
cd server
npm install
npm run dev
```

### Web 端启动

```bash
cd web
npm install
npm run dev
```

### 手机端开发

1. 使用 DevEco Studio 打开 `phone` 目录
2. 配置签名证书
3. 连接真机或模拟器
4. 点击运行

---

## 项目结构

```
rideRecord/
├── phone/                 # 手机端应用
│   └── entry/src/main/ets/
│       ├── pages/         # 页面
│       ├── components/    # 组件
│       └── services/      # 服务
├── watch/                 # 手表端应用
│   └── entry/src/main/ets/
├── server/                # 服务端
│   └── src/
│       ├── routes/        # 路由
│       └── services/      # 服务
├── web/                   # Web 端
│   └── src/
│       ├── views/         # 页面
│       └── stores/        # 状态管理
├── shared/                # 共享代码
│   ├── types/             # 类型定义
│   └── utils/             # 工具函数
└── docs/                  # 文档
    └── plans/             # 设计文档
```

---

## 开发指南

### 代码规范

- 使用 TypeScript/ArkTS 强类型
- 遵循 ESLint 规则
- 组件使用声明式 UI
- 服务使用单例模式

### 提交规范

```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式
refactor: 重构
test: 测试
chore: 构建/工具
```

### 分支管理

- `main` - 主分支
- `develop` - 开发分支
- `feature/*` - 功能分支
- `hotfix/*` - 热修复分支

---

## 贡献指南

欢迎贡献代码！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

### 贡献步骤

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'feat: add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

---

## 安全策略

如果您发现安全漏洞，请查看 [SECURITY.md](SECURITY.md) 了解如何报告。

---

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

---

## 致谢

感谢以下开源项目：

- [HarmonyOS](https://www.harmonyos.com/)
- [Vue.js](https://vuejs.org/)
- [Express](https://expressjs.com/)
- [TailwindCSS](https://tailwindcss.com/)

---

<p align="center">
  Made with ❤️ by RideRecord Team
</p>

# RideRecord - 系统架构设计文档

**文档版本**: 1.1
**创建日期**: 2026-03-06
**项目代号**: RideRecord
**关联文档**: ride-record-srs.md, ride-record-ucd.md
**架构风格**: 轻量化单体架构（高性价比）

---

## 1. 架构概述

### 1.1 设计理念

本系统采用**轻量化架构**，核心原则：

- **本地优先**：数据存储在本地SQLite，云端仅作备份同步
- **按需上云**：轻量服务器 + 对象存储，成本可控
- **极简后端**：单体服务，无微服务复杂度
- **高性价比**：预估月成本 < 100元

### 1.2 系统架构图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         RideRecord 轻量化架构                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                        客户端层 (本地优先)                               │    │
│  │                                                                          │    │
│  │   ┌─────────────────────────────┐     ┌─────────────────────────────┐  │    │
│  │   │      手机应用               │     │      手表应用               │  │    │
│  │   │      (HarmonyOS)           │     │      (Watch OS)            │  │    │
│  │   │                             │     │                             │  │    │
│  │   │  ┌───────────────────────┐  │     │  ┌───────────────────────┐  │  │    │
│  │   │  │  本地 SQLite 数据库   │  │     │  │  本地数据存储         │  │  │    │
│  │   │  │  - 骑行记录           │  │     │  │  - 传感器缓存         │  │  │    │
│  │   │  │  - 轨迹数据           │  │     │  │  - 离线数据           │  │  │    │
│  │   │  │  - 用户设置           │  │     │  └───────────────────────┘  │  │    │
│  │   │  │  - 统计缓存           │  │     │                             │  │    │
│  │   │  └───────────────────────┘  │     │  BLE 同步 ◄─────────────►  │  │    │
│  │   │                             │     │                             │  │    │
│  │   │  核心功能:                  │     │  核心功能:                  │  │    │
│  │   │  - 主界面/导航              │     │  - 骑行数据展示            │  │    │
│  │   │  - 数据分析/统计            │     │  - 圆弧按钮控制            │  │    │
│  │   │  - 动作检测引擎             │     │  - 动作检测采集            │  │    │
│  │   │  - 离线地图                 │     │  - 心率实时显示            │  │    │
│  │   └───────────┬─────────────────┘     └───────────┬─────────────────┘  │    │
│  │              │                                    │                    │    │
│  └──────────────┼────────────────────────────────────┼────────────────────┘    │
│                 │                                    │                          │
│                 │ BLE (蓝牙同步)                      │                          │
│                 └────────────────────────────────────┘                          │
│                                                                                  │
│                 │ HTTPS (仅同步时使用)                                        │
│                 ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                        云端服务层 (按需使用)                             │  │
│  │                                                                          │  │
│  │   ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │   │                    轻量应用服务器 (2核4G)                         │  │  │
│  │   │                                                                  │  │  │
│  │   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │  │  │
│  │   │   │ API 服务    │  │ 同步服务    │  │ 定时任务    │            │  │  │
│  │   │   │ (Node.js)   │  │ (数据同步)  │  │ (清理/统计) │            │  │  │
│  │   │   └──────┬──────┘  └──────┬──────┘  └─────────────┘            │  │  │
│  │   │          │                │                                    │  │  │
│  │   │          └────────────────┼────────────────────────────────────┘  │  │
│  │   │                           │                                       │  │
│  │   │                           ▼                                       │  │
│  │   │   ┌─────────────────────────────────────────────────────────┐    │  │
│  │   │   │              本地 SQLite (服务端)                        │    │  │
│  │   │   │              - 用户账号 (仅登录态)                       │    │  │
│  │   │   │              - 同步元数据                                │    │  │
│  │   │   │              - 文件索引                                  │    │  │
│  │   │   └─────────────────────────────────────────────────────────┘    │  │
│  │   │                                                                   │  │
│  │   └───────────────────────────────────────────────────────────────────┘  │
│  │                                                                          │  │
│  │   ┌─────────────────────────────┐     ┌─────────────────────────────┐  │  │
│  │   │     对象存储 (华为云OBS)    │     │      Web 应用 (静态托管)    │  │  │
│  │   │                             │     │                             │  │  │
│  │   │  - 骑行轨迹文件 (GPX)       │     │  - 数据看板                 │  │  │
│  │   │  - 照片文件                 │     │  - 路线管理                 │  │  │
│  │   │  - 离线地图包               │     │  - 账号设置                 │  │  │
│  │   │                             │     │                             │  │  │
│  │   │  费用: 按量计费，约20元/月  │     │  费用: 免费额度内           │  │  │
│  │   └─────────────────────────────┘     └─────────────────────────────┘  │  │
│  │                                                                          │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                         外部服务层                                       │  │
│  │                                                                          │  │
│  │   ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌────────────┐ │  │
│  │   │ 华为运动健康  │ │ 地图服务      │ │ 微信开放平台  │ │ Strava API │ │  │
│  │   │ API           │ │ (高德地图)    │ │ API           │ │            │ │  │
│  │   └───────────────┘ └───────────────┘ └───────────────┘ └────────────┘ │  │
│  │                                                                          │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 架构分层说明

| 层级 | 职责 | 技术选型 | 成本 |
|------|------|----------|------|
| 客户端层 | 本地数据存储、业务逻辑、UI展示 | ArkTS + SQLite | 0 |
| 云端服务层 | 数据同步、文件存储、Web托管 | 轻量服务器 + OBS | ~60元/月 |
| 外部服务层 | 第三方API集成 | 华为/高德/微信/Strava | 免费额度 |

### 1.4 成本估算

```
┌─────────────────────────────────────────────────────────────────┐
│                        月度成本估算                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   轻量应用服务器 (华为云 HECS)                                   │
│   - 规格: 2核4G                                                 │
│   - 带宽: 3Mbps                                                 │
│   - 费用: 约 40-50 元/月                                        │
│                                                                  │
│   对象存储 (华为云 OBS)                                          │
│   - 存储: 10GB                                                  │
│   - 流量: 10GB/月                                               │
│   - 费用: 约 15-20 元/月                                        │
│                                                                  │
│   域名 + SSL证书                                                 │
│   - 费用: 约 10 元/月 (年付分摊)                                │
│                                                                  │
│   ─────────────────────────────────────────                     │
│   合计: 约 65-80 元/月                                          │
│                                                                  │
│   节省方案:                                                      │
│   - 使用华为云新用户优惠: 首年可能免费                          │
│   - Web静态托管使用Vercel/Netlify: 免费                         │
│   - 对象存储用阿里云OSS: 价格相近                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 技术栈

### 2.1 客户端技术栈

#### 2.1.1 手机应用 (HarmonyOS)

```
┌─────────────────────────────────────────────────────────────────┐
│                    手机应用技术栈                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   开发语言       ArkTS (TypeScript 扩展)                        │
│   UI框架         ArkUI (声明式UI)                               │
│   状态管理       @ohos/app.ability + PersistentStorage          │
│   网络请求       @ohos/axios (HTTP客户端)                       │
│   地图组件       华为地图服务 Kit / 高德地图 SDK                │
│   数据存储       @ohos.data.preferences + 关系型数据库          │
│   图表库         自定义 Canvas 组件                             │
│   传感器         @ohos.sensor (GPS、加速度计、陀螺仪)           │
│   蓝牙通信       @ohos.bluetooth (BLE 连接手表)                 │
│                                                                  │
│   项目结构                                                       │
│   ride-record-phone/                                            │
│   ├── entry/                    # 主入口                        │
│   │   └── src/main/ets/                                         │
│   │       ├── entryability/     # 应用入口                      │
│   │       └── pages/            # 页面                          │
│   ├── features/                 # 功能模块                      │
│   │   ├── home/                 # 首页                          │
│   │   ├── record/               # 骑行记录                      │
│   │   ├── navigation/           # 导航                          │
│   │   ├── profile/              # 个人中心                      │
│   │   └── settings/             # 设置                          │
│   ├── shared/                   # 共享模块                      │
│   │   ├── components/           # 公共组件                      │
│   │   ├── services/             # 服务层                        │
│   │   ├── utils/                # 工具函数                      │
│   │   └── constants/            # 常量定义                      │
│   └── oh_modules/               # 依赖包                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 2.1.2 手表应用 (Watch OS)

```
┌─────────────────────────────────────────────────────────────────┐
│                    手表应用技术栈                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   开发语言       ArkTS (TypeScript 扩展)                        │
│   UI框架         ArkUI (声明式UI - 手表优化版)                  │
│   传感器         @ohos.sensor                                   │
│   │              - 加速度计 (加速度数据)                         │
│   │              - 陀螺仪 (角速度数据)                           │
│   │              - 心率传感器 (实时心率)                         │
│   │              - GPS (位置数据)                                │
│   蓝牙通信       @ohos.bluetooth (与手机同步)                   │
│   振动反馈       @ohos.vibrator (触觉反馈)                      │
│   数据存储       @ohos.data.preferences (轻量级存储)            │
│                                                                  │
│   项目结构                                                       │
│   ride-record-watch/                                            │
│   ├── entry/                                                    │
│   │   └── src/main/ets/                                         │
│   │       ├── pages/            # 表盘页面                      │
│   │       │   ├── HomePage.ets  # 主表盘                        │
│   │       │   ├── RidingPage.ets # 骑行中                       │
│   │       │   └── SummaryPage.ets # 骑行总结                    │
│   │       ├── widgets/          # 小组件                        │
│   │       └── services/         # 后台服务                      │
│   │           ├── SensorService.ets    # 传感器服务             │
│   │           ├── ActionDetector.ets   # 动作检测              │
│   │           └── SyncService.ets       # 数据同步             │
│   └── shared/                   # 共享代码                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 2.1.3 Web 应用

```
┌─────────────────────────────────────────────────────────────────┐
│                      Web 应用技术栈                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   框架           Vue 3 + TypeScript                             │
│   构建工具       Vite                                           │
│   状态管理       Pinia                                          │
│   路由           Vue Router 4                                   │
│   UI组件库       自定义组件 + TailwindCSS                        │
│   地图组件       高德地图 JS API / Mapbox GL JS                 │
│   图表库         ECharts 5                                      │
│   HTTP客户端     Axios                                          │
│                                                                  │
│   项目结构                                                       │
│   ride-record-web/                                              │
│   ├── src/                                                      │
│   │   ├── views/                # 页面视图                      │
│   │   │   ├── Dashboard.vue     # 数据看板                      │
│   │   │   ├── Records.vue       # 记录列表                      │
│   │   │   ├── RecordDetail.vue  # 记录详情                      │
│   │   │   ├── Navigation.vue    # 路线规划                      │
│   │   │   └── Settings.vue      # 设置                         │
│   │   ├── components/           # 组件                          │
│   │   │   ├── map/              # 地图组件                      │
│   │   │   ├── chart/            # 图表组件                      │
│   │   │   └── common/           # 通用组件                      │
│   │   ├── stores/               # Pinia 状态                    │
│   │   ├── services/             # API 服务                      │
│   │   ├── utils/                # 工具函数                      │
│   │   └── assets/               # 静态资源                      │
│   └── public/                                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 服务端技术栈 (轻量化)

```
┌─────────────────────────────────────────────────────────────────┐
│                    服务端技术栈 (轻量化)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   运行时环境     Node.js 20 LTS                                 │
│   Web框架        Express / Fastify (轻量级)                     │
│   API规范        RESTful API                                    │
│   数据库         SQLite 3 (better-sqlite3)                      │
│   ORM            Prisma (支持SQLite)                            │
│   对象存储       华为云 OBS (SDK)                               │
│   认证           JWT (无需Redis)                                │
│   部署           PM2 + Nginx (单机部署)                         │
│   监控           简易日志 + 状态接口                             │
│                                                                  │
│   项目结构 (单体应用)                                            │
│   ride-record-server/                                           │
│   ├── src/                                                      │
│   │   ├── index.ts              # 入口                          │
│   │   ├── routes/               # 路由                          │
│   │   │   ├── auth.ts           # 认证                          │
│   │   │   ├── rides.ts          # 骑行记录                      │
│   │   │   ├── sync.ts           # 数据同步                      │
│   │   │   └── navigation.ts     # 导航代理                      │
│   │   ├── services/             # 业务逻辑                      │
│   │   │   ├── authService.ts                                    │
│   │   │   ├── rideService.ts                                    │
│   │   │   ├── syncService.ts                                    │
│   │   │   └── obsService.ts                                     │
│   │   ├── db/                   # 数据库                        │
│   │   │   ├── schema.prisma     # Prisma Schema                 │
│   │   │   └── migrations/       # 迁移文件                      │
│   │   ├── middleware/           # 中间件                        │
│   │   └── utils/                # 工具函数                      │
│   ├── data/                     # SQLite数据目录                │
│   │   └── ride-record.db                                        │
│   ├── uploads/                  # 临时上传目录                  │
│   ├── ecosystem.config.js       # PM2配置                       │
│   └── package.json                                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 本地数据存储 (SQLite)

```
┌─────────────────────────────────────────────────────────────────┐
│                    SQLite 本地存储架构                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   手机端 SQLite                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  使用 @ohos.data.relationalStore (鸿蒙关系型数据库)      │  │
│   │                                                         │  │
│   │  数据库文件: /data/app/el2/database/ride_record.db      │  │
│   │  预估大小: 100MB - 500MB (取决于记录数量)               │  │
│   │                                                         │  │
│   │  表结构:                                                 │  │
│   │  - users          用户信息                              │  │
│   │  - rides          骑行记录                              │  │
│   │  - track_points   轨迹点 (可能很大)                     │  │
│   │  - segments       路段信息                              │  │
│   │  - photos         照片元数据                            │  │
│   │  - settings       应用设置                              │  │
│   │  - sync_status    同步状态                              │  │
│   │                                                         │  │
│   │  优化策略:                                               │  │
│   │  - 轨迹点按月分表 (track_points_202403)                 │  │
│   │  - 建立空间索引 (RTree)                                 │  │
│   │  - 定期归档旧数据到云端                                 │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   手表端轻量存储                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  使用 @ohos.data.preferences (键值存储)                 │  │
│   │                                                         │  │
│   │  存储内容:                                               │  │
│   │  - 当前骑行会话数据 (实时)                              │  │
│   │  - 用户设置                                              │  │
│   │  - 最后同步时间                                          │  │
│   │                                                         │  │
│   │  不持久化历史记录，通过BLE同步到手机                     │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   服务端 SQLite                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  存储: 仅同步元数据，不存储实际轨迹                      │  │
│   │                                                         │  │
│   │  表结构:                                                 │  │
│   │  - users          用户账号 (华为ID绑定)                 │  │
│   │  - sync_records   同步记录索引                          │  │
│   │  - file_index     文件索引 (OBS文件对应关系)            │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.4 技术选型理由 (轻量化)

| 技术 | 选型理由 |
|------|----------|
| **ArkTS + ArkUI** | HarmonyOS 官方推荐，性能最优，生态完整 |
| **Vue 3** | 响应式设计友好，组件化开发效率高，生态成熟 |
| **Node.js + Express** | 开发效率高，社区资源丰富，部署简单 |
| **SQLite** | 零配置、无服务端、高性能，适合本地优先架构 |
| **华为云 OBS** | 对象存储成本低，国内访问速度有保障 |
| **Prisma** | 类型安全，支持SQLite，迁移管理方便 |
| **PM2** | 进程管理简单，支持自动重启和日志管理 |
| **无Redis** | 本地优先架构不需要分布式缓存，内存缓存足够 |

---

## 3. 核心模块设计

### 3.1 动作检测模块

#### 3.1.1 架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                      动作检测模块架构                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   数据采集层                                                     │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   ┌───────────┐  ┌───────────┐  ┌───────────┐          │  │
│   │   │ 加速度计   │  │  陀螺仪   │  │  GPS      │          │  │
│   │   │ 50Hz     │  │  50Hz    │  │  1Hz     │          │  │
│   │   └─────┬─────┘  └─────┬─────┘  └─────┬─────┘          │  │
│   │         │              │              │                 │  │
│   │         └──────────────┼──────────────┘                 │  │
│   │                        ▼                                │  │
│   │              ┌─────────────────┐                        │  │
│   │              │   数据缓冲队列   │                        │  │
│   │              │   (滑动窗口)     │                        │  │
│   │              │   5秒 = 250样本  │                        │  │
│   │              └────────┬────────┘                        │  │
│   │                       │                                 │  │
│   └───────────────────────┼─────────────────────────────────┘  │
│                           ▼                                    │
│   特征提取层                                                     │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   输入: 原始传感器数据 (acc_x, acc_y, acc_z, gyro_*)     │  │
│   │                                                         │  │
│   │   特征计算:                                              │  │
│   │   ┌─────────────────────────────────────────────────┐   │  │
│   │   │ 1. 合成加速度: a = √(ax² + ay² + az²)           │   │  │
│   │   │ 2. 合成角速度: ω = √(wx² + wy² + wz²)           │   │  │
│   │   │ 3. 标准差: σ(a), σ(ω)                           │   │  │
│   │   │ 4. 峰值计数: PeakCount(a)                       │   │  │
│   │   │ 5. 过零率: ZeroCrossingRate(a)                  │   │  │
│   │   │ 6. 频域特征: FFT 主频率                          │   │  │
│   │   │ 7. 相关性: Corr(acc, gyro)                      │   │  │
│   │   └─────────────────────────────────────────────────┘   │  │
│   │                                                         │  │
│   │   输出: 特征向量 [f1, f2, f3, ..., fn]                  │  │
│   │                                                         │  │
│   └───────────────────────────┬─────────────────────────────┘  │
│                               ▼                                │
│   分类识别层                                                     │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   ┌─────────────────────────────────────────────────┐   │  │
│   │   │              动作分类器 (轻量级模型)              │   │  │
│   │   │                                                 │   │  │
│   │   │   模型选择:                                      │   │  │
│   │   │   - 方案A: 决策树 (CPU友好，解释性强)            │   │  │
│   │   │   - 方案B: 随机森林 (精度较高)                   │   │  │
│   │   │   - 方案C: 轻量级神经网络 (TensorFlow Lite)      │   │  │
│   │   │                                                 │   │  │
│   │   │   动作类别:                                      │   │  │
│   │   │   - 上车 (MOUNT)                                │   │  │
│   │   │   - 下车 (DISMOUNT)                             │   │  │
│   │   │   - 踩踏 (PEDALING)                             │   │  │
│   │   │   - 滑行 (COASTING)                             │   │  │
│   │   │   - 停止 (STOPPED)                              │   │  │
│   │   │   - 其他 (OTHER)                                │   │  │
│   │   │                                                 │   │  │
│   │   └─────────────────────────────────────────────────┘   │  │
│   │                                                         │  │
│   └───────────────────────────┬─────────────────────────────┘  │
│                               ▼                                │
│   状态管理层                                                     │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   状态机:                                                │  │
│   │                                                         │  │
│   │   ┌─────────┐   检测到上车+踩踏   ┌─────────┐          │  │
│   │   │  空闲   │ ─────────────────► │ 骑行中  │          │  │
│   │   │ (IDLE)  │                     │(RIDING) │          │  │
│   │   └─────────┘   ◄───────────────  └─────────┘          │  │
│   │        ▲          检测到下车        │    │              │  │
│   │        │                           │    │ 检测到暂停   │  │
│   │        │                           ▼    ▼              │  │
│   │        │                       ┌─────────────┐         │  │
│   │        │                       │   暂停中    │         │  │
│   │        └────────────────────── │  (PAUSED)   │         │  │
│   │              确认结束           └─────────────┘         │  │
│   │                                                         │  │
│   │   触发事件:                                              │  │
│   │   - ON_RIDE_START    → 开始记录                         │  │
│   │   - ON_RIDE_PAUSE    → 暂停记录                         │  │
│   │   - ON_RIDE_RESUME   → 恢复记录                         │  │
│   │   - ON_RIDE_END      → 结束确认                         │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.1.2 核心算法

```typescript
// 动作检测服务核心逻辑
interface SensorData {
  timestamp: number;
  accX: number;
  accY: number;
  accZ: number;
  gyroX: number;
  gyroY: number;
  gyroZ: number;
  speed: number; // GPS速度
  heartRate: number;
}

interface FeatureVector {
  accMagnitude: number;      // 合成加速度
  gyroMagnitude: number;     // 合成角速度
  accStdDev: number;         // 加速度标准差
  gyroStdDev: number;        // 角速度标准差
  peakCount: number;         // 峰值计数
  zeroCrossingRate: number;  // 过零率
  dominantFreq: number;      // 主频率
  speed: number;             // GPS速度
}

enum ActionType {
  MOUNT = 'MOUNT',           // 上车
  DISMOUNT = 'DISMOUNT',     // 下车
  PEDALING = 'PEDALING',     // 踩踏
  COASTING = 'COASTING',     // 滑行
  STOPPED = 'STOPPED',       // 停止
  OTHER = 'OTHER'            // 其他
}

class ActionDetector {
  private windowSize = 250; // 5秒 * 50Hz
  private buffer: SensorData[] = [];
  private classifier: DecisionTreeClassifier;
  private stateMachine: StateMachine;

  // 添加传感器数据
  addSensorData(data: SensorData): void {
    this.buffer.push(data);
    if (this.buffer.length > this.windowSize) {
      this.buffer.shift();
    }

    if (this.buffer.length >= this.windowSize) {
      this.processWindow();
    }
  }

  // 处理数据窗口
  private processWindow(): void {
    const features = this.extractFeatures(this.buffer);
    const action = this.classifier.predict(features);
    const confidence = this.classifier.getConfidence();

    // 只有置信度超过阈值才触发状态变化
    if (confidence > 0.8) {
      this.stateMachine.transition(action);
    }
  }

  // 特征提取
  private extractFeatures(data: SensorData[]): FeatureVector {
    const accMagnitudes = data.map(d =>
      Math.sqrt(d.accX**2 + d.accY**2 + d.accZ**2)
    );

    const gyroMagnitudes = data.map(d =>
      Math.sqrt(d.gyroX**2 + d.gyroY**2 + d.gyroZ**2)
    );

    return {
      accMagnitude: this.mean(accMagnitudes),
      gyroMagnitude: this.mean(gyroMagnitudes),
      accStdDev: this.stdDev(accMagnitudes),
      gyroStdDev: this.stdDev(gyroMagnitudes),
      peakCount: this.countPeaks(accMagnitudes),
      zeroCrossingRate: this.zeroCrossingRate(accMagnitudes),
      dominantFreq: this.fftDominantFreq(accMagnitudes),
      speed: this.mean(data.map(d => d.speed))
    };
  }
}
```

#### 3.1.3 状态机实现

```typescript
// 骑行状态机
enum RideState {
  IDLE = 'IDLE',           // 空闲
  RIDING = 'RIDING',       // 骑行中
  PAUSED = 'PAUSED',       // 暂停
  ENDING = 'ENDING'        // 等待确认结束
}

interface StateTransition {
  from: RideState;
  to: RideState;
  condition: (actions: ActionType[], context: Context) => boolean;
  action: () => void;
}

class RideStateMachine {
  private currentState: RideState = RideState.IDLE;
  private actionHistory: ActionType[] = [];
  private pauseStartTime: number = 0;
  private readonly PAUSE_TIMEOUT = 30 * 60 * 1000; // 30分钟

  private transitions: StateTransition[] = [
    {
      from: RideState.IDLE,
      to: RideState.RIDING,
      condition: (actions) => this.containsSequence(actions,
        [ActionType.MOUNT, ActionType.PEDALING]),
      action: () => this.emit('RIDE_START')
    },
    {
      from: RideState.RIDING,
      to: RideState.PAUSED,
      condition: (actions, ctx) =>
        actions.every(a => a === ActionType.STOPPED) &&
        ctx.speed < 2 && ctx.noPedaling,
      action: () => {
        this.pauseStartTime = Date.now();
        this.emit('RIDE_PAUSE');
      }
    },
    {
      from: RideState.PAUSED,
      to: RideState.RIDING,
      condition: (actions) => actions.includes(ActionType.PEDALING),
      action: () => this.emit('RIDE_RESUME')
    },
    {
      from: RideState.PAUSED,
      to: RideState.ENDING,
      condition: () => Date.now() - this.pauseStartTime > this.PAUSE_TIMEOUT,
      action: () => this.emit('RIDE_END_REQUEST')
    },
    {
      from: RideState.RIDING,
      to: RideState.ENDING,
      condition: (actions) => actions.includes(ActionType.DISMOUNT),
      action: () => this.emit('RIDE_END_REQUEST')
    }
  ];

  transition(action: ActionType): void {
    this.actionHistory.push(action);
    if (this.actionHistory.length > 10) {
      this.actionHistory.shift();
    }

    for (const t of this.transitions) {
      if (t.from === this.currentState) {
        // 获取上下文
        const context = this.getContext();
        if (t.condition(this.actionHistory, context)) {
          this.currentState = t.to;
          t.action();
          break;
        }
      }
    }
  }

  confirmEnd(): void {
    if (this.currentState === RideState.ENDING) {
      this.emit('RIDE_END_CONFIRMED');
      this.currentState = RideState.IDLE;
      this.actionHistory = [];
    }
  }

  cancelEnd(): void {
    if (this.currentState === RideState.ENDING) {
      this.currentState = RideState.RIDING;
      this.emit('RIDE_CONTINUE');
    }
  }
}
```

### 3.2 导航模块

#### 3.2.1 架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                       导航模块架构                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                     路线规划引擎                          │  │
│   │                                                         │  │
│   │   输入:                                                  │  │
│   │   - 起点、终点坐标                                       │  │
│   │   - 导航模式 (公路/探险/混合)                            │  │
│   │   - 用户偏好 (探险比例、冒险指数上限)                    │  │
│   │                                                         │  │
│   │   处理流程:                                              │  │
│   │   ┌─────────┐    ┌─────────┐    ┌─────────┐            │  │
│   │   │ 路网    │───►│ 路线    │───►│ 路线    │            │  │
│   │   │ 查询    │    │ 计算    │    │ 优化    │            │  │
│   │   └─────────┘    └─────────┘    └─────────┘            │  │
│   │        │              │              │                  │  │
│   │        ▼              ▼              ▼                  │  │
│   │   ┌─────────┐    ┌─────────┐    ┌─────────┐            │  │
│   │   │公路数据 │    │A*算法   │    │冒险指数 │            │  │
│   │   │探险数据 │    │多目标   │    │评分     │            │  │
│   │   │地形数据 │    │优化     │    │筛选     │            │  │
│   │   └─────────┘    └─────────┘    └─────────┘            │  │
│   │                                                         │  │
│   │   输出:                                                  │  │
│   │   - 路线坐标序列                                         │  │
│   │   - 分段信息 (类型、距离、冒险指数)                      │  │
│   │   - 导航指令序列                                         │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                     冒险指数计算器                        │  │
│   │                                                         │  │
│   │   因素权重:                                               │  │
│   │   ┌───────────────────────────────────────────────────┐ │  │
│   │   │ 因素          │ 权重   │ 数据来源                  │ │  │
│   │   ├───────────────────────────────────────────────────┤ │  │
│   │   │ 路面状况      │ 0.25   │ 地图API + 用户标注        │ │  │
│   │   │ 坡度          │ 0.20   │ DEM高程数据               │ │  │
│   │   │ 交通流量      │ 0.15   │ 实时交通API               │ │  │
│   │   │ 信号覆盖      │ 0.15   │ 运营商覆盖地图            │ │  │
│   │   │ 补给距离      │ 0.15   │ POI数据                   │ │  │
│   │   │ 天气条件      │ 0.10   │ 天气API                   │ │  │
│   │   └───────────────────────────────────────────────────┘ │  │
│   │                                                         │  │
│   │   计算公式:                                               │  │
│   │   RiskIndex = Σ(Weight_i × Score_i) / Σ(Weight_i)      │  │
│   │                                                         │  │
│   │   输出: 1.0 ~ 5.0                                        │  │
│   │   - 1.0-1.5: 安全 (绿色)                                │  │
│   │   - 1.5-2.5: 低风险 (黄绿色)                            │  │
│   │   - 2.5-3.5: 中风险 (橙色)                              │  │
│   │   - 3.5-4.5: 高风险 (红色)                              │  │
│   │   - 4.5-5.0: 极高风险 (深红)                            │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                     离线地图管理                          │  │
│   │                                                         │  │
│   │   功能:                                                   │  │
│   │   - 矢量瓦片下载 (Mapbox Vector Tiles)                  │  │
│   │   - 高程数据下载 (DEM Tiles)                            │  │
│   │   - 存储空间管理 (LRU淘汰)                              │  │
│   │   - 增量更新                                            │  │
│   │                                                         │  │
│   │   存储结构:                                               │  │
│   │   /offline-maps/                                         │  │
│   │   ├── {region_id}/                                       │  │
│   │   │   ├── metadata.json        # 区域元信息              │  │
│   │   │   ├── vector/{z}/{x}/{y}.pbf  # 矢量瓦片            │  │
│   │   │   ├── dem/{z}/{x}/{y}.png   # 高程瓦片              │  │
│   │   │   └── route_network.json    # 路网数据              │  │
│   │   └── index.db                 # 索引数据库              │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.2.2 路线规划算法

```typescript
// 路线规划服务
interface RouteRequest {
  origin: Coordinate;
  destination: Coordinate;
  mode: NavigationMode;
  adventureRatio: number; // 探险比例 0-1
  maxRiskIndex: number;   // 最大冒险指数 1-5
  waypoints?: Coordinate[];
}

interface RouteSegment {
  coordinates: Coordinate[];
  type: 'road' | 'trail' | 'mixed';
  distance: number;
  duration: number;
  riskIndex: number;
  surfaceType: string;
  trafficLevel: 'low' | 'medium' | 'high';
}

interface Route {
  id: string;
  segments: RouteSegment[];
  totalDistance: number;
  totalDuration: number;
  avgRiskIndex: number;
  adventurePercentage: number;
  instructions: NavigationInstruction[];
}

class RoutePlanner {
  // 混合模式路线规划
  async planMixedRoute(request: RouteRequest): Promise<Route[]> {
    // 1. 获取区域内所有可行路径
    const roadNetwork = await this.getRoadNetwork(request);
    const trailNetwork = await this.getTrailNetwork(request);

    // 2. 合并路网
    const combinedNetwork = this.mergeNetworks(roadNetwork, trailNetwork);

    // 3. 多目标优化
    const routes = await this.multiObjectiveSearch(
      combinedNetwork,
      request.origin,
      request.destination,
      {
        adventureTarget: request.adventureRatio,
        maxRisk: request.maxRiskIndex,
        maxDistance: request.totalDistanceLimit
      }
    );

    // 4. 计算冒险指数
    for (const route of routes) {
      for (const segment of route.segments) {
        segment.riskIndex = await this.calculateRiskIndex(segment);
      }
    }

    // 5. 过滤和排序
    return routes
      .filter(r => r.avgRiskIndex <= request.maxRiskIndex)
      .sort((a, b) => this.scoreRoute(a) - this.scoreRoute(b));
  }

  // A* 多目标优化
  private async multiObjectiveSearch(
    network: RoadNetwork,
    start: Coordinate,
    end: Coordinate,
    constraints: SearchConstraints
  ): Promise<Route[]> {
    const openSet = new PriorityQueue<RouteNode>();
    const closedSet = new Set<string>();

    openSet.push({
      coordinate: start,
      gScore: 0,
      fScore: this.heuristic(start, end),
      path: [],
      adventureDistance: 0,
      totalRisk: 0
    });

    const routes: Route[] = [];

    while (!openSet.isEmpty() && routes.length < 5) {
      const current = openSet.pop();

      if (this.isNear(current.coordinate, end)) {
        routes.push(this.buildRoute(current.path));
        continue;
      }

      const key = this.coordinateKey(current.coordinate);
      if (closedSet.has(key)) continue;
      closedSet.add(key);

      for (const edge of network.getEdges(current.coordinate)) {
        const riskIndex = await this.calculateRiskIndex(edge);

        // 跳过高风险路段
        if (riskIndex > constraints.maxRisk) continue;

        const newAdventureDistance = current.adventureDistance +
          (edge.type === 'trail' ? edge.distance : 0);

        const gScore = current.gScore + edge.distance;
        const hScore = this.heuristic(edge.end, end);
        const fScore = gScore + hScore;

        openSet.push({
          coordinate: edge.end,
          gScore,
          fScore,
          path: [...current.path, edge],
          adventureDistance: newAdventureDistance,
          totalRisk: current.totalRisk + riskIndex * edge.distance
        });
      }
    }

    return routes;
  }
}
```

### 3.3 数据采集与同步模块

#### 3.3.1 架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                    数据采集与同步架构                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   手表端数据采集                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   传感器数据流                                           │  │
│   │   ┌─────────────────────────────────────────────────┐   │  │
│   │   │                                                 │   │  │
│   │   │   GPS (1Hz)      心率 (1Hz)      运动 (50Hz)    │   │  │
│   │   │      │              │               │           │   │  │
│   │   │      └──────────────┼───────────────┘           │   │  │
│   │   │                     ▼                            │   │  │
│   │   │           ┌─────────────────┐                   │   │  │
│   │   │           │  数据缓冲队列    │                   │   │  │
│   │   │           │  (内存 + 持久化) │                   │   │  │
│   │   │           └────────┬────────┘                   │   │  │
│   │   │                    │                            │   │  │
│   │   └────────────────────┼────────────────────────────┘   │  │
│   │                        │                                 │  │
│   │                        ▼                                 │  │
│   │           ┌─────────────────────────┐                   │  │
│   │           │  BLE 数据传输服务       │                   │  │
│   │           │  - 批量打包 (1秒间隔)   │                   │  │
│   │           │  - 断点续传             │                   │  │
│   │           │  - 数据压缩             │                   │  │
│   │           └────────────┬────────────┘                   │  │
│   │                        │                                 │  │
│   └────────────────────────┼─────────────────────────────────┘  │
│                            │ BLE                                │
│                            ▼                                    │
│   手机端数据处理                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   ┌─────────────────────────────────────────────────┐   │  │
│   │   │              BLE 接收服务                        │   │  │
│   │   │              - 数据解包                          │   │  │
│   │   │              - 数据校验                          │   │  │
│   │   │              - 合并去重                          │   │  │
│   │   └────────────────────┬────────────────────────────┘   │  │
│   │                        │                                 │  │
│   │                        ▼                                 │  │
│   │   ┌─────────────────────────────────────────────────┐   │  │
│   │   │              数据处理管道                        │   │  │
│   │   │                                                 │   │  │
│   │   │   原始数据 ──► 滤波 ──► 插值 ──► 聚合 ──► 存储   │   │  │
│   │   │              │        │        │        │        │   │  │
│   │   │           卡尔曼    GPS    1秒    本地    │   │  │
│   │   │           滤波     补充    聚合    数据库   │   │  │
│   │   │                                                 │   │  │
│   │   └────────────────────┬────────────────────────────┘   │  │
│   │                        │                                 │  │
│   │                        ▼                                 │  │
│   │   ┌─────────────────────────────────────────────────┐   │  │
│   │   │              实时数据展示                        │   │  │
│   │   │              - 速度/距离/时间                    │   │  │
│   │   │              - 心率/海拔                         │   │  │
│   │   │              - 轨迹绘制                          │   │  │
│   │   └─────────────────────────────────────────────────┘   │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   云端同步                                                       │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   同步策略:                                               │  │
│   │   - 骑行中: 仅缓存到本地                                 │  │
│   │   - 骑行结束: 立即上传                                   │  │
│   │   - 网络断开: 队列等待,恢复后自动续传                    │  │
│   │   - 冲突解决: 最新优先                                   │  │
│   │                                                         │  │
│   │   上传顺序:                                               │  │
│   │   1. 骑行元数据 (JSON) → 华为云OBS                       │  │
│   │   2. 轨迹数据 (GPX) → 华为云OBS                          │  │
│   │   3. 照片 (JPEG) → 华为云OBS                             │  │
│   │   4. 同步通知 → Web端                                    │  │
│   │   5. 第三方平台 → Strava等                               │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.3.2 数据格式

```typescript
// 骑行记录数据结构
interface RideRecord {
  id: string;
  userId: string;

  // 时间信息
  startTime: Date;
  endTime: Date;
  duration: number; // 秒
  movingTime: number; // 移动时间
  pausedTime: number; // 暂停时间

  // 基础统计
  distance: number; // 米
  avgSpeed: number; // 米/秒
  maxSpeed: number;
  avgHeartRate: number;
  maxHeartRate: number;
  calories: number;

  // 海拔数据
  elevationGain: number; // 爬升米
  elevationLoss: number; // 下降米
  minElevation: number;
  maxElevation: number;

  // 探险相关
  adventureDistance: number; // 探险路段距离
  adventurePercentage: number; // 探险路段占比
  avgRiskIndex: number; // 平均冒险指数

  // 元数据
  title: string;
  description: string;
  tags: string[];
  weather: WeatherCondition;

  // 状态
  status: 'recording' | 'paused' | 'completed' | 'discarded';
  syncStatus: SyncStatus;

  createdAt: Date;
  updatedAt: Date;
}

// GPS轨迹点
interface TrackPoint {
  timestamp: Date;
  latitude: number;
  longitude: number;
  elevation: number;
  speed: number;
  heartRate: number;
  cadence?: number;
  distance: number; // 累计距离
  segment: number; // 路段编号
  riskIndex?: number; // 冒险指数
}

// GPX导出格式
interface GPXExport {
  version: '1.1';
  creator: 'RideRecord';
  metadata: {
    name: string;
    time: Date;
  };
  trk: {
    name: string;
    trkseg: {
      trkpt: {
        lat: number;
        lon: number;
        ele: number;
        time: Date;
        extensions?: {
          hr: number;
          cad: number;
          speed: number;
        };
      }[];
    }[];
  };
}
```

---

## 4. 数据模型设计

### 4.1 数据库ER图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              数据模型 ER 图                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────┐              ┌─────────────────┐                      │
│   │     User        │              │    Device       │                      │
│   ├─────────────────┤              ├─────────────────┤                      │
│   │ id (PK)         │──────┐  ┌───│ id (PK)         │                      │
│   │ huawei_id       │      │  │   │ user_id (FK)    │──────┐               │
│   │ nickname        │      │  │   │ device_type     │      │               │
│   │ avatar_url      │      │  │   │ device_name     │      │               │
│   │ phone           │      │  │   │ device_id       │      │               │
│   │ email           │      │  │   │ last_sync       │      │               │
│   │ settings (JSON) │      │  │   │ status          │      │               │
│   │ created_at      │      │  │   └─────────────────┘      │               │
│   │ updated_at      │      │  │                            │               │
│   └─────────────────┘      │  │                            │               │
│          │                 │  │                            │               │
│          │ 1:N             │  │                            │               │
│          ▼                 │  │                            │               │
│   ┌─────────────────┐      │  │  ┌─────────────────┐       │               │
│   │   RideRecord    │◄─────┘  │  │   WatchSession  │◄──────┘               │
│   ├─────────────────┤         │  ├─────────────────┤                       │
│   │ id (PK)         │         │  │ id (PK)         │                       │
│   │ user_id (FK)    │         │  │ device_id (FK)  │                       │
│   │ start_time      │         │  │ ride_id (FK)    │──────┐                │
│   │ end_time        │         │  │ start_time      │      │                │
│   │ duration        │         │  │ end_time        │      │                │
│   │ distance        │         │  │ data_count      │      │                │
│   │ avg_speed       │         │  └─────────────────┘      │                │
│   │ max_speed       │         │                           │                │
│   │ avg_heart_rate  │         │                           │                │
│   │ max_heart_rate  │         │                           │                │
│   │ calories        │         │                           │                │
│   │ elevation_gain  │         │                           │                │
│   │ adventure_dist  │         │                           │                │
│   │ avg_risk_index  │         │                           │                │
│   │ title           │         │  ┌─────────────────┐      │                │
│   │ description     │         │  │   TrackPoint    │◄─────┘                │
│   │ status          │         │  ├─────────────────┤                       │
│   │ sync_status     │         │  │ id (PK)         │                       │
│   │ gpx_url         │─────────┼─►│ ride_id (FK)    │                       │
│   │ created_at      │         │  │ timestamp       │                       │
│   └─────────────────┘         │  │ latitude        │                       │
│          │                    │  │ longitude       │                       │
│          │ 1:N                │  │ elevation       │                       │
│          ▼                    │  │ speed           │                       │
│   ┌─────────────────┐         │  │ heart_rate      │                       │
│   │    Segment      │         │  │ distance        │                       │
│   ├─────────────────┤         │  │ risk_index      │                       │
│   │ id (PK)         │         │  │ segment_id      │                       │
│   │ ride_id (FK)    │◄────────┘  └─────────────────┘                       │
│   │ type            │                                                     │
│   │ distance        │         ┌─────────────────┐                          │
│   │ duration        │         │    Photo        │                          │
│   │ risk_index      │         ├─────────────────┤                          │
│   │ surface_type    │         │ id (PK)         │                          │
│   │ start_point     │         │ ride_id (FK)    │                          │
│   │ end_point       │         │ url             │                          │
│   └─────────────────┘         │ thumbnail_url   │                          │
│                               │ latitude        │                          │
│                               │ longitude       │                          │
│                               │ taken_at        │                          │
│                               └─────────────────┘                          │
│                                                                             │
│   ┌─────────────────┐         ┌─────────────────┐                          │
│   │    Route        │         │   ThirdParty    │                          │
│   ├─────────────────┤         ├─────────────────┤                          │
│   │ id (PK)         │         │ id (PK)         │                          │
│   │ user_id (FK)    │         │ user_id (FK)    │                          │
│   │ name            │         │ platform        │                          │
│   │ coordinates     │         │ access_token    │                          │
│   │ distance        │         │ refresh_token   │                          │
│   │ estimated_time  │         │ expires_at      │                          │
│   │ avg_risk_index  │         │ status          │                          │
│   │ is_official     │         └─────────────────┘                          │
│   │ created_at      │                                                      │
│   └─────────────────┘                                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 数据库 Schema (Prisma)

```prisma
// schema.prisma - SQLite 版本

datasource db {
  provider = "sqlite"
  url      = "file:./data/ride-record.db"
}

generator client {
  provider = "prisma-client-js"
}

// 用户表
model User {
  id          String   @id @default(cuid())
  huaweiId    String   @unique // 华为账号ID
  nickname    String
  avatarUrl   String?
  phone       String?
  email       String?

  // 用户设置 (SQLite用TEXT存储JSON)
  settings    String   @default("{}")

  // 身体数据 (用于热量计算)
  height      Int?     // cm
  weight      Float?   // kg
  maxHr       Int?     // 最大心率

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  // 关联
  devices     Device[]
  rides       RideRecord[]
  routes      Route[]
  thirdParty  ThirdParty[]

  @@map("users")
}

// 设备表
model Device {
  id          String   @id @default(cuid())
  userId      String
  deviceType  String   // phone, watch
  deviceName  String
  deviceId    String   // 设备唯一标识
  lastSync    DateTime?
  status      String   @default("active")

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  user        User     @relation(fields: [userId], references: [id])
  sessions    WatchSession[]

  @@index([userId])
  @@map("devices")
}

// 骑行记录表
model RideRecord {
  id              String   @id @default(cuid())
  userId          String

  // 时间
  startTime       DateTime
  endTime         DateTime?
  duration        Int      @default(0) // 秒
  movingTime      Int      @default(0)
  pausedTime      Int      @default(0)

  // 基础统计
  distance        Float    @default(0) // 米
  avgSpeed        Float    @default(0) // 米/秒
  maxSpeed        Float    @default(0)
  avgHeartRate    Int?
  maxHeartRate    Int?
  calories        Int      @default(0)

  // 海拔
  elevationGain   Float    @default(0)
  elevationLoss   Float    @default(0)
  minElevation    Float?
  maxElevation    Float?

  // 探险数据
  adventureDistance Float  @default(0)
  adventurePercentage Float @default(0)
  avgRiskIndex    Float    @default(0)

  // 元数据 (SQLite用TEXT存储JSON数组)
  title           String?
  description     String?
  tags            String   @default("[]") // JSON数组字符串
  weather         String?  // JSON字符串

  // 状态
  status          String   @default("recording") // recording, paused, completed, discarded
  syncStatus      String   @default("{}") // JSON字符串

  // 文件URL
  gpxUrl          String?
  gpxLocalPath    String?  // 本地GPX文件路径

  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt

  user            User     @relation(fields: [userId], references: [id])
  trackPoints     TrackPoint[]
  segments        Segment[]
  photos          Photo[]
  watchSessions   WatchSession[]

  @@index([userId, startTime])
  @@index([status])
  @@map("ride_records")
}

// 轨迹点表
model TrackPoint {
  id          String   @id @default(cuid())
  rideId      String
  timestamp   DateTime
  latitude    Float
  longitude   Float
  elevation   Float?
  speed       Float?
  heartRate   Int?
  cadence     Int?
  distance    Float    @default(0)
  segmentIdx  Int      @default(0)
  riskIndex   Float?

  ride        RideRecord @relation(fields: [rideId], references: [id], onDelete: Cascade)

  @@index([rideId, timestamp])
  @@index([rideId, segmentIdx])
  @@map("track_points")
}

// 路段表
model Segment {
  id          String   @id @default(cuid())
  rideId      String
  type        String   // road, trail, mixed
  distance    Float
  duration    Int
  riskIndex   Float
  surfaceType String?
  trafficLevel String?

  // 起止坐标
  startLat    Float
  startLng    Float
  endLat      Float
  endLng      Float

  ride        RideRecord @relation(fields: [rideId], references: [id], onDelete: Cascade)

  @@index([rideId])
  @@map("segments")
}

// 照片表
model Photo {
  id            String   @id @default(cuid())
  rideId        String
  url           String
  thumbnailUrl  String?
  latitude      Float?
  longitude     Float?
  takenAt       DateTime?

  ride          RideRecord @relation(fields: [rideId], references: [id], onDelete: Cascade)

  @@index([rideId])
  @@map("photos")
}

// 手表会话表
model WatchSession {
  id          String   @id @default(cuid())
  deviceId    String
  rideId      String?
  startTime   DateTime
  endTime     DateTime?
  dataCount   Int      @default(0)

  device      Device   @relation(fields: [deviceId], references: [id])
  ride        RideRecord? @relation(fields: [rideId], references: [id])

  @@index([deviceId])
  @@map("watch_sessions")
}

// 路线表
model Route {
  id              String   @id @default(cuid())
  userId          String?
  name            String
  description     String?
  coordinates     Json     // GeoJSON LineString
  distance        Float
  estimatedTime   Int?
  avgRiskIndex    Float?
  isOfficial      Boolean  @default(false)
  downloadCount   Int      @default(0)

  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt

  user            User?    @relation(fields: [userId], references: [id])

  @@index([isOfficial])
  @@map("routes")
}

// 第三方平台绑定表
model ThirdParty {
  id            String   @id @default(cuid())
  userId        String
  platform      String   // strava, wechat
  accessToken   String
  refreshToken  String?
  expiresAt     DateTime?
  status        String   @default("active")

  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  user          User     @relation(fields: [userId], references: [id])

  @@unique([userId, platform])
  @@map("third_party_bindings")
}
```

---

## 5. API 设计

### 5.1 API 概览

```
┌─────────────────────────────────────────────────────────────────┐
│                        API 设计概览                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   基础路径: https://api.riderecord.com/v1                       │
│   认证方式: Bearer Token (JWT)                                  │
│   数据格式: JSON                                                 │
│                                                                  │
│   API 分组:                                                      │
│                                                                  │
│   /auth          认证相关                                        │
│   ├── POST   /login              华为账号登录                   │
│   ├── POST   /logout             退出登录                       │
│   ├── POST   /refresh            刷新Token                      │
│   └── GET    /me                 获取当前用户信息               │
│                                                                  │
│   /users         用户管理                                        │
│   ├── GET    /:id                获取用户信息                   │
│   ├── PUT    /:id                更新用户信息                   │
│   ├── PUT    /:id/settings       更新用户设置                   │
│   └── DELETE /:id                删除用户                       │
│                                                                  │
│   /rides         骑行记录                                        │
│   ├── GET    /                   获取骑行列表                   │
│   ├── POST   /                   创建骑行记录                   │
│   ├── GET    /:id                获取骑行详情                   │
│   ├── PUT    /:id                更新骑行信息                   │
│   ├── DELETE /:id                删除骑行记录                   │
│   ├── GET    /:id/track          获取轨迹数据                   │
│   ├── POST   /:id/track          上传轨迹数据                   │
│   ├── GET    /:id/export         导出骑行数据                   │
│   └── POST   /:id/photos         上传照片                       │
│                                                                  │
│   /navigation    导航服务                                        │
│   ├── POST   /plan               规划路线                       │
│   ├── GET    /routes             获取推荐路线                   │
│   ├── GET    /routes/:id         获取路线详情                   │
│   ├── POST   /routes             保存自定义路线                 │
│   └── GET    /offline            获取离线地图列表               │
│                                                                  │
│   /sync          数据同步                                        │
│   ├── POST   /upload             上传骑行数据                   │
│   ├── GET    /status             获取同步状态                   │
│   ├── POST   /strava             同步到Strava                   │
│   └── POST   /wechat/share       微信分享                       │
│                                                                  │
│   /stats         统计分析                                        │
│   ├── GET    /summary            获取统计概览                   │
│   ├── GET    /weekly             周统计                         │
│   ├── GET    /monthly            月统计                         │
│   └── GET    /records            个人记录                       │
│                                                                  │
│   /devices       设备管理                                        │
│   ├── GET    /                   获取设备列表                   │
│   ├── POST   /bind               绑定设备                       │
│   ├── DELETE /:id                解绑设备                       │
│   └── POST   /:id/sync           触发同步                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 核心 API 详情

#### 5.2.1 骑行记录 API

```yaml
# 创建骑行记录
POST /rides
Request:
  {
    "startTime": "2024-03-06T08:00:00Z",
    "title": "清晨探险骑行",
    "deviceId": "watch_001"
  }
Response:
  {
    "id": "ride_abc123",
    "status": "recording",
    "createdAt": "2024-03-06T08:00:00Z"
  }

# 上传轨迹数据
POST /rides/{id}/track
Content-Type: multipart/form-data
Request:
  - file: track.gpx
  - format: "gpx"
Response:
  {
    "success": true,
    "pointsReceived": 3600,
    "distance": 42200
  }

# 获取骑行详情
GET /rides/{id}
Response:
  {
    "id": "ride_abc123",
    "userId": "user_001",
    "startTime": "2024-03-06T08:00:00Z",
    "endTime": "2024-03-06T10:15:00Z",
    "duration": 8100,
    "movingTime": 7800,
    "distance": 42200,
    "avgSpeed": 5.4,
    "maxSpeed": 12.5,
    "avgHeartRate": 145,
    "maxHeartRate": 178,
    "calories": 850,
    "elevationGain": 320,
    "adventurePercentage": 30,
    "avgRiskIndex": 2.3,
    "title": "清晨探险骑行",
    "status": "completed",
    "trackUrl": "https://obs.riderecord.com/tracks/ride_abc123.gpx",
    "segments": [
      {
        "type": "road",
        "distance": 29540,
        "riskIndex": 1.2
      },
      {
        "type": "trail",
        "distance": 12660,
        "riskIndex": 3.1
      }
    ]
  }

# 导出骑行数据
GET /rides/{id}/export?format=gpx
Response:
  Content-Type: application/gpx+xml
  Content-Disposition: attachment; filename="ride_abc123.gpx"
```

#### 5.2.2 导航规划 API

```yaml
# 路线规划
POST /navigation/plan
Request:
  {
    "origin": {
      "latitude": 39.9042,
      "longitude": 116.4074
    },
    "destination": {
      "latitude": 40.0563,
      "longitude": 116.2805
    },
    "mode": "mixed",
    "adventureRatio": 0.3,
    "maxRiskIndex": 3.0
  }
Response:
  {
    "routes": [
      {
        "id": "route_001",
        "distance": 42200,
        "duration": 8100,
        "avgRiskIndex": 2.3,
        "adventurePercentage": 30,
        "segments": [
          {
            "type": "road",
            "distance": 29540,
            "duration": 5600,
            "riskIndex": 1.2,
            "coordinates": [[...]]
          },
          {
            "type": "trail",
            "distance": 12660,
            "duration": 2500,
            "riskIndex": 3.1,
            "surfaceType": "gravel",
            "coordinates": [[...]]
          }
        ]
      }
    ]
  }
```

---

## 6. 安全设计

### 6.1 安全架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        安全架构设计                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   认证授权                                                       │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   认证方式:                                               │  │
│   │   - 华为账号OAuth 2.0登录                                │  │
│   │   - JWT Token认证                                        │  │
│   │   - 设备指纹验证                                          │  │
│   │                                                         │  │
│   │   Token结构:                                              │  │
│   │   - Access Token: 2小时有效期                            │  │
│   │   - Refresh Token: 30天有效期                            │  │
│   │                                                         │  │
│   │   权限控制:                                               │  │
│   │   - RBAC (基于角色的访问控制)                            │  │
│   │   - 资源级权限: 用户只能访问自己的数据                    │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   数据安全                                                       │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   传输加密:                                               │  │
│   │   - HTTPS (TLS 1.3)                                     │  │
│   │   - 证书固定 (Certificate Pinning)                       │  │
│   │                                                         │  │
│   │   存储加密:                                               │  │
│   │   - 数据库: AES-256加密敏感字段                          │  │
│   │   - 对象存储: 服务端加密 (SSE)                           │  │
│   │   - 本地存储: 鸿蒙安全存储API                            │  │
│   │                                                         │  │
│   │   敏感数据处理:                                           │  │
│   │   - 脱敏存储: 手机号、邮箱                               │  │
│   │   - 不记录: 密码、Token到日志                            │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   API安全                                                        │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   - 请求签名: HMAC-SHA256                               │  │
│   │   - 防重放: Timestamp + Nonce                           │  │
│   │   - 限流: 令牌桶算法 (100 req/min/user)                 │  │
│   │   - 输入验证: 参数校验 + SQL注入防护                    │  │
│   │   - XSS防护: 输出编码                                   │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   隐私保护                                                       │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   - GDPR合规: 数据可导出、可删除                        │  │
│   │   - 位置隐私: 分享时可隐藏具体位置                      │  │
│   │   - 用户授权: 明确告知数据用途                          │  │
│   │   - 数据保留: 用户可设置保留期限                        │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. 部署架构 (轻量化)

### 7.1 单机部署拓扑

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         轻量化部署架构                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   客户端 (本地优先)                                                          │
│   ┌────────────────────────────────────────────────────────────────────┐    │
│   │                                                                    │    │
│   │   用户设备                                                         │    │
│   │   ┌─────────────────┐    ┌─────────────────┐                     │    │
│   │   │ 华为 Mate 70    │◄──►│ Huawei Watch 3 Pro                    │    │
│   │   │ (本地SQLite)   │BLE │ (本地存储)       │                     │    │
│   │   └────────┬────────┘    └─────────────────┘                     │    │
│   │            │                                                      │    │
│   │            │ HTTPS (仅同步时)                                     │    │
│   │            ▼                                                      │    │
│   └────────────┼────────────────────────────────────────────────────────┘    │
│                │                                                              │
│   云端服务     │                                                              │
│   ┌────────────┴────────────────────────────────────────────────────────┐    │
│   │                                                                    │    │
│   │   ┌─────────────────────────────────────────────────────────────┐  │    │
│   │   │              轻量应用服务器 (华为云HECS)                      │  │    │
│   │   │              2核4G / 3Mbps带宽                               │  │    │
│   │   │                                                             │  │    │
│   │   │   ┌─────────────────────────────────────────────────────┐   │  │    │
│   │   │   │  Nginx (反向代理 + HTTPS)                           │   │  │    │
│   │   │   │  - SSL终止                                          │   │  │    │
│   │   │   │  - 静态文件服务                                      │   │  │    │
│   │   │   │  - 反向代理到Node.js                                 │   │  │    │
│   │   │   └─────────────────────────────────────────────────────┘   │  │    │
│   │   │                          │                                   │  │    │
│   │   │   ┌──────────────────────┴──────────────────────────────┐   │  │    │
│   │   │   │  Node.js 应用 (PM2管理)                             │   │  │    │
│   │   │   │                                                     │   │  │    │
│   │   │   │  - API服务                                          │   │  │    │
│   │   │   │  - 同步服务                                          │   │  │    │
│   │   │   │  - 定时任务                                          │   │  │    │
│   │   │   │                                                     │   │  │    │
│   │   │   │  端口: 3000                                         │   │  │    │
│   │   │   │  实例: 2 (PM2 cluster模式)                          │   │  │    │
│   │   │   └──────────────────────┬──────────────────────────────┘   │  │    │
│   │   │                          │                                   │  │    │
│   │   │   ┌──────────────────────┴──────────────────────────────┐   │  │    │
│   │   │   │  SQLite 数据库                                      │   │  │    │
│   │   │   │  /data/ride-record/ride-record.db                  │   │  │    │
│   │   │   │                                                     │   │  │    │
│   │   │   │  - 用户账号                                         │   │  │    │
│   │   │   │  - 同步索引                                         │   │  │    │
│   │   │   │  - 文件元数据                                       │   │  │    │
│   │   │   └─────────────────────────────────────────────────────┘   │  │    │
│   │   │                                                             │  │    │
│   │   └─────────────────────────────────────────────────────────────┘  │    │
│   │                                                                    │    │
│   │   ┌─────────────────────────────┐  ┌─────────────────────────────┐ │    │
│   │   │  华为云 OBS (对象存储)      │  │  Web静态托管 (可选)         │ │    │
│   │   │                             │  │                             │ │    │
│   │   │  Bucket: ride-record-data   │  │  - Vercel/Netlify (免费)    │ │    │
│   │   │                             │  │  - 或OBS静态网站            │ │    │
│   │   │  /tracks/  轨迹GPX文件      │  │                             │ │    │
│   │   │  /photos/ 骑行照片          │  │  Web端Vue3打包产物          │ │    │
│   │   │  /maps/   离线地图包        │  │                             │ │    │
│   │   │                             │  │                             │ │    │
│   │   └─────────────────────────────┘  └─────────────────────────────┘ │    │
│   │                                                                    │    │
│   └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│   域名与SSL                                                                  │
│   ┌────────────────────────────────────────────────────────────────────┐    │
│   │                                                                    │    │
│   │   域名: api.riderecord.com (或自定义)                             │    │
│   │   SSL: Let's Encrypt 免费证书 (certbot自动续期)                   │    │
│   │                                                                    │    │
│   └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 服务器配置清单

```
┌─────────────────────────────────────────────────────────────────┐
│                    服务器配置清单                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   硬件配置                                                       │
│   ─────────────────────────────────────────                    │
│   CPU:      2核                                                 │
│   内存:     4GB                                                 │
│   硬盘:     40GB SSD                                            │
│   带宽:     3Mbps                                               │
│                                                                  │
│   软件环境                                                       │
│   ─────────────────────────────────────────                    │
│   OS:       Ubuntu 22.04 LTS                                    │
│   Node.js:  20.x LTS                                            │
│   Nginx:    1.24+                                               │
│   PM2:      最新版                                              │
│   SQLite:   3.x                                                 │
│                                                                  │
│   华为云购买链接                                                 │
│   ─────────────────────────────────────────                    │
│   https://www.huaweicloud.com/product/hecs.html                 │
│                                                                  │
│   预估月费用: 40-50元                                            │
│   新用户优惠: 首年可能免费或大幅折扣                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 Docker 容器化部署

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker 容器化部署方案                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   架构概览                                                       │
│   ─────────────────────────────────────────────────────────    │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                    Docker Host                          │  │
│   │                                                         │  │
│   │   ┌─────────────────────────────────────────────────┐  │  │
│   │   │              nginx容器 (反向代理)               │  │  │
│   │   │              端口: 80, 443                      │  │  │
│   │   │              - SSL终止                          │  │  │
│   │   │              - 静态文件服务                      │  │  │
│   │   │              - 反向代理到API                     │  │  │
│   │   └──────────────────────┬──────────────────────────┘  │  │
│   │                          │                              │  │
│   │                          ▼                              │  │
│   │   ┌─────────────────────────────────────────────────┐  │  │
│   │   │              ride-record-api 容器               │  │  │
│   │   │              Node.js 20 LTS                     │  │  │
│   │   │              端口: 3000                         │  │  │
│   │   │                                                 │  │  │
│   │   │   /app                                          │  │  │
│   │   │   ├── /src          应用源码                   │  │  │
│   │   │   ├── /data         SQLite数据库 (Volume)      │  │  │
│   │   │   ├── /uploads      上传临时目录 (Volume)      │  │  │
│   │   │   └── /logs         日志目录 (Volume)          │  │  │
│   │   │                                                 │  │  │
│   │   └─────────────────────────────────────────────────┘  │  │
│   │                                                         │  │
│   │   Volumes (数据持久化)                                  │  │
│   │   ┌─────────────────────────────────────────────────┐  │  │
│   │   │  ride-record-data  → /app/data                  │  │  │
│   │   │  ride-record-logs  → /app/logs                  │  │  │
│   │   │  ride-record-uploads → /app/uploads             │  │  │
│   │   └─────────────────────────────────────────────────┘  │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 7.3.1 Dockerfile 设计

```dockerfile
# ===========================================
# 多阶段构建 - RideRecord API Server
# ===========================================

# 阶段1: 构建阶段
FROM node:20-alpine AS builder

WORKDIR /app

# 安装构建依赖
COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci --only=production

# 复制源码并构建
COPY . .
RUN npx prisma generate
RUN npm run build

# 阶段2: 生产镜像
FROM node:20-alpine AS runner

WORKDIR /app

# 安全: 使用非root用户
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 riderecord

# 复制构建产物
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/prisma ./prisma

# 创建数据目录
RUN mkdir -p /app/data /app/uploads /app/logs
RUN chown -R riderecord:nodejs /app

# 切换用户
USER riderecord

# 环境变量
ENV NODE_ENV=production
ENV PORT=3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# 暴露端口
EXPOSE 3000

# 启动命令
CMD ["node", "dist/index.js"]
```

#### 7.3.2 Docker Compose 配置

```yaml
# docker-compose.yml
version: '3.8'

services:
  # API 服务
  api:
    build:
      context: ./server
      dockerfile: Dockerfile
    image: riderecord/api:latest
    container_name: riderecord-api
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_PATH=/app/data/ride-record.db
      - JWT_SECRET=${JWT_SECRET}
      - OBS_ACCESS_KEY=${OBS_ACCESS_KEY}
      - OBS_SECRET_KEY=${OBS_SECRET_KEY}
      - OBS_BUCKET=${OBS_BUCKET}
      - OBS_REGION=${OBS_REGION}
      - AMAP_API_KEY=${AMAP_API_KEY}
    volumes:
      - ride-record-data:/app/data
      - ride-record-logs:/app/logs
      - ride-record-uploads:/app/uploads
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    networks:
      - ride-record-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Nginx 反向代理
  nginx:
    image: nginx:alpine
    container_name: riderecord-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ride-record-web:/usr/share/nginx/html:ro
    depends_on:
      api:
        condition: service_healthy
    networks:
      - ride-record-network

  # Web 前端 (可选，静态托管)
  web:
    build:
      context: ./web
      dockerfile: Dockerfile
    image: riderecord/web:latest
    container_name: riderecord-web
    # 仅用于构建，产物挂载到nginx
    volumes:
      - ride-record-web:/app/dist

networks:
  ride-record-network:
    driver: bridge

volumes:
  ride-record-data:
  ride-record-logs:
  ride-record-uploads:
  ride-record-web:
```

#### 7.3.3 部署命令

```bash
# ===========================================
# Docker 部署操作指南
# ===========================================

# 1. 构建镜像
docker-compose build

# 2. 启动服务
docker-compose up -d

# 3. 查看日志
docker-compose logs -f api

# 4. 健康检查
curl http://localhost:3000/health

# 5. 数据库迁移 (首次部署)
docker-compose exec api npx prisma migrate deploy

# 6. 停止服务
docker-compose down

# 7. 更新部署
docker-compose pull
docker-compose up -d

# 8. 备份数据
docker run --rm -v ride-record-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/ride-record-data-$(date +%Y%m%d).tar.gz /data

# 9. 恢复数据
docker run --rm -v ride-record-data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/ride-record-data-20260306.tar.gz -C /
```

#### 7.3.4 Docker Hub 发布

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Hub 发布流程                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   镜像命名                                                       │
│   ─────────────────────────────────────────────────────────    │
│   riderecord/api:latest          # 最新版本                     │
│   riderecord/api:v1.0.0          # 指定版本                     │
│   riderecord/api:v1.0.0-alpine   # Alpine版本 (更小)           │
│                                                                  │
│   发布命令                                                       │
│   ─────────────────────────────────────────                    │
│   # 登录 Docker Hub                                             │
│   docker login                                                  │
│                                                                  │
│   # 标记镜像                                                    │
│   docker tag riderecord/api:latest riderecord/api:v1.0.0       │
│                                                                  │
│   # 推送镜像                                                    │
│   docker push riderecord/api:latest                             │
│   docker push riderecord/api:v1.0.0                             │
│                                                                  │
│   GitHub Actions 自动构建                                       │
│   ─────────────────────────────────────────                    │
│   .github/workflows/docker-publish.yml:                         │
│   - 推送到 main 分支时自动构建                                  │
│   - 创建 Tag 时自动发布对应版本                                 │
│   - 多架构支持: linux/amd64, linux/arm64                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 7.3.5 镜像大小优化

```
┌─────────────────────────────────────────────────────────────────┐
│                    镜像优化策略                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   优化措施                                                       │
│   ─────────────────────────────────────────────────────────    │
│   1. 多阶段构建        减少最终镜像大小                        │
│   2. Alpine基础镜像    node:20-alpine (~50MB)                  │
│   3. 生产依赖          npm ci --only=production                │
│   4. 删除缓存          npm cache clean --force                 │
│   5. .dockerignore     排除不必要文件                          │
│                                                                  │
│   .dockerignore 示例                                            │
│   ─────────────────────────────────────────                    │
│   node_modules                                                  │
│   dist                                                          │
│   *.log                                                         │
│   .env                                                          │
│   .env.*                                                        │
│   tests/                                                        │
│   docs/                                                         │
│   .git/                                                         │
│   .github/                                                      │
│   *.md                                                          │
│                                                                  │
│   预期镜像大小                                                   │
│   ─────────────────────────────────────────                    │
│   未优化:     ~500MB                                            │
│   优化后:     ~100MB                                            │
│   Alpine:     ~80MB                                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. 手表应用安装与发布指南

### 8.1 手表应用安装方式

```
┌─────────────────────────────────────────────────────────────────┐
│                   手表应用安装方式                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   方式一: 通过华为应用市场安装 (推荐)                            │
│   ─────────────────────────────────────────────────────────    │
│   1. 在华为手表上打开「应用市场」                               │
│   2. 搜索「RideRecord」或「骑行记录」                           │
│   3. 点击安装                                                   │
│   4. 安装完成后在应用列表中找到并打开                           │
│                                                                  │
│   方式二: 通过手机配对安装                                       │
│   ─────────────────────────────────────────────────            │
│   1. 在华为手机上打开「华为运动健康」App                        │
│   2. 进入「设备」→ 选择已配对的手表                             │
│   3. 点击「应用市场」                                           │
│   4. 搜索并安装应用到手表                                       │
│                                                                  │
│   方式三: 开发者调试安装 (开发阶段)                             │
│   ─────────────────────────────────────────                    │
│   1. 在DevEco Studio中打开手表项目                              │
│   │   ride-record-watch/                                        │
│   │                                                              │
│   2. 连接手表到电脑 (USB或WiFi调试)                             │
│   │   - 手表开启开发者模式:                                      │
│   │     设置 → 关于 → 连续点击版本号7次                         │
│   │   - 开启USB调试:                                             │
│   │     设置 → 开发者选项 → USB调试                              │
│   │                                                              │
│   3. 在DevEco Studio中点击运行                                  │
│   │   - 选择目标设备 (Huawei Watch 3 Pro)                       │
│   │   - 自动签名并安装                                           │
│   │                                                              │
│   4. 或使用hdc命令行安装                                        │
│   │   hdc install ride-record-watch.hap                         │
│   │                                                              │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 华为应用市场发布流程

```
┌─────────────────────────────────────────────────────────────────┐
│               华为应用市场发布完整流程                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   第一步: 开发者账号注册                                        │
│   ─────────────────────────────────────────────────────────    │
│   1. 访问华为开发者联盟                                         │
│      https://developer.huawei.com/                              │
│                                                                  │
│   2. 注册开发者账号                                             │
│      - 个人开发者: 免费，需实名认证                             │
│      - 企业开发者: 需营业执照，费用约99元/年                    │
│                                                                  │
│   3. 完成实名认证                                               │
│      - 个人: 身份证+人脸识别                                    │
│      - 企业: 营业执照+对公账户验证                              │
│                                                                  │
│   第二步: 创建应用                                              │
│   ─────────────────────────────────────────                    │
│   1. 登录AppGallery Connect控制台                               │
│      https://developer.huawei.com/consumer/cn/service/app.html │
│                                                                  │
│   2. 点击「我的应用」→「创建」                                  │
│                                                                  │
│   3. 填写应用基本信息                                           │
│      ┌──────────────────────────────────────────────────┐      │
│      │ 应用名称: RideRecord - 骑行记录                   │      │
│      │ 应用类型: 运动健康                                 │      │
│      │ 应用包名: com.riderecord.watch                    │      │
│      │ 支持设备: 手表 (Wearable)                          │      │
│      └──────────────────────────────────────────────────┘      │
│                                                                  │
│   第三步: 应用签名                                              │
│   ─────────────────────────────────────────                    │
│   1. 生成签名证书                                               │
│      - 使用DevEco Studio自动生成                                │
│      - 或使用OpenSSL命令生成                                    │
│                                                                  │
│   2. 申请发布证书                                               │
│      - 在AppGallery Connect申请                                │
│      - 下载.cer和.p12文件                                       │
│                                                                  │
│   3. 配置签名                                                   │
│      在build-profile.json5中配置:                               │
│      {                                                          │
│        "app": {                                                 │
│          "signingConfigs": [{                                   │
│            "name": "release",                                   │
│            "material": {                                        │
│              "certpath": "release.cer",                         │
│              "storePassword": "xxx",                            │
│              "keyAlias": "riderecord",                          │
│              "keyPassword": "xxx",                              │
│              "profile": "release.p12",                          │
│              "signAlg": "SHA256withECDSA",                      │
│              "verify": true                                     │
│            }                                                    │
│          }]                                                     │
│        }                                                        │
│      }                                                          │
│                                                                  │
│   第四步: 构建发布包                                            │
│   ─────────────────────────────────────────                    │
│   1. 在DevEco Studio中:                                         │
│      Build → Build Hap(s)/APP(s) → Build APP(s)                │
│                                                                  │
│   2. 生成产物位置:                                              │
│      ride-record-watch/build/outputs/default/                   │
│      ride-record-watch-default-signed.app                       │
│                                                                  │
│   第五步: 上传审核                                              │
│   ─────────────────────────────────────────                    │
│   1. 上传APP包                                                  │
│                                                                  │
│   2. 填写应用详情                                               │
│      ┌──────────────────────────────────────────────────┐      │
│      │ 应用图标: 512x512 PNG                             │      │
│      │ 应用截图: 至少3张 (手表界面截图)                  │      │
│      │ 应用简介: 80字以内                                │      │
│      │ 应用描述: 详细功能介绍                            │      │
│      │ 版本说明: 本次更新内容                            │      │
│      │ 隐私政策: 填写隐私政策URL                         │      │
│      └──────────────────────────────────────────────────┘      │
│                                                                  │
│   3. 提交审核                                                   │
│      - 审核周期: 通常1-3个工作日                                │
│      - 审核内容: 功能、内容、安全、权限                        │
│                                                                  │
│   第六步: 发布上架                                              │
│   ─────────────────────────────────────────                    │
│   1. 审核通过后，选择发布方式:                                  │
│      - 全量发布: 所有用户可见                                   │
│      - 灰度发布: 先小范围测试                                   │
│                                                                  │
│   2. 应用上架后，用户可在手表应用市场搜索下载                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 8.3 应用市场审核要点

```
┌─────────────────────────────────────────────────────────────────┐
│                    审核注意事项                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   必备材料                                                       │
│   ─────────────────────────────────────────                    │
│   ✓ 应用图标 (512x512, 无圆角)                                  │
│   ✓ 应用截图 (至少3张，展示核心功能)                            │
│   ✓ 宣传图 (1024x500，可选)                                     │
│   ✓ 隐私政策URL                                                 │
│   ✓ 软件著作权证书 (部分应用需要)                               │
│                                                                  │
│   审核常见问题                                                   │
│   ─────────────────────────────────────────                    │
│   ✗ 崩溃或闪退                                                  │
│   ✗ 功能与描述不符                                              │
│   ✗ 权限滥用 (如非必要获取通讯录)                               │
│   ✗ 隐私政策不完整                                              │
│   ✗ 含有违规内容                                                │
│   ✗ 诱导下载或恶意推广                                          │
│                                                                  │
│   权限声明模板                                                   │
│   ─────────────────────────────────────────                    │
│   本应用需要以下权限:                                           │
│   - 位置权限: 用于记录骑行轨迹                                  │
│   - 运动健康权限: 用于获取心率、步频等数据                      │
│   - 蓝牙权限: 用于连接手表设备                                  │
│   - 存储权限: 用于保存骑行数据和离线地图                        │
│                                                                  │
│   隐私政策要点                                                   │
│   ─────────────────────────────────────────                    │
│   1. 收集哪些数据                                               │
│   2. 数据如何使用                                               │
│   3. 数据如何存储和保护                                         │
│   4. 用户权利 (查看、删除、导出)                                │
│   5. 第三方SDK声明 (地图、微信分享等)                           │
│   6. 联系方式                                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 8.4 手表应用发布清单

```
┌─────────────────────────────────────────────────────────────────┐
│                   发布前自查清单                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   功能测试                                                       │
│   □ 动作检测自动启停功能正常                                    │
│   □ 数据采集和显示正确                                          │
│   □ 与手机同步功能正常                                          │
│   □ 圆弧按钮响应正常                                            │
│   □ 心率实时显示正确                                            │
│   □ 离线模式可正常使用                                          │
│                                                                  │
│   性能测试                                                       │
│   □ 内存占用 < 100MB                                            │
│   □ 启动时间 < 3秒                                              │
│   □ 续航影响可接受 (1小时骑行 < 10%电量)                        │
│   □ 无内存泄漏                                                  │
│                                                                  │
│   兼容性测试                                                     │
│   □ Huawei Watch 3 Pro 测试通过                                 │
│   □ HarmonyOS 3.0+ 兼容                                         │
│   □ 与华为手机配对正常                                          │
│                                                                  │
│   安全测试                                                       │
│   □ 数据本地加密存储                                            │
│   □ 无敏感信息泄露                                              │
│   □ 权限申请合理                                                │
│                                                                  │
│   资源准备                                                       │
│   □ 应用图标已准备                                              │
│   □ 应用截图已准备                                              │
│   □ 隐私政策已发布                                              │
│   □ 应用描述已撰写                                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. 开发里程碑

### 8.1 MVP 版本 (v1.0)

```
┌─────────────────────────────────────────────────────────────────┐
│                        MVP 版本规划                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   目标: 验证核心功能，发布内测版本                               │
│                                                                  │
│   功能范围:                                                      │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ ✓ 动作检测自动启停 (核心差异化)                          │  │
│   │ ✓ 基础数据采集 (GPS、心率、速度)                         │  │
│   │ ✓ 实时数据看板                                          │  │
│   │ ✓ 骑行记录列表与详情                                    │  │
│   │ ✓ 基础导航 (公路模式)                                    │  │
│   │ ✓ 云端同步 (华为云OBS)                                  │  │
│   │ ✓ 手表基础界面                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   不含:                                                          │
│   ✗ 探险导航模式                                                │
│   ✗ 冒险指数计算                                                │
│   ✗ 第三方平台同步                                              │
│   ✗ Web端                                                       │
│   ✗ 社交分享                                                    │
│                                                                  │
│   预计工期: 8 周                                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 完整版本 (v1.0)

```
┌─────────────────────────────────────────────────────────────────┐
│                       完整版本规划                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   功能范围:                                                      │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ ✓ 所有MVP功能                                           │  │
│   │ ✓ 探险导航模式 + 混合导航                               │  │
│   │ ✓ 冒险指数实时计算与显示                                │  │
│   │ ✓ 离线地图                                              │  │
│   │ ✓ 统计分析图表                                          │  │
│   │ ✓ Web端数据查看                                         │  │
│   │ ✓ 微信/朋友圈分享                                       │  │
│   │ ✓ Strava同步                                            │  │
│   │ ✓ 手表圆弧按钮界面                                      │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   预计工期: MVP后 6 周                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. 开源发布规划

### 10.1 开源许可证选择

```
┌─────────────────────────────────────────────────────────────────┐
│                    开源许可证对比                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   推荐方案: MIT License (最宽松)                                │
│   ─────────────────────────────────────────────────────────    │
│   优点:                                                         │
│   ✓ 商业友好，允许闭源使用                                      │
│   ✓ 简短易懂，仅要求保留版权声明                                │
│   ✓ 与大多数其他许可证兼容                                      │
│   ✓ 社区接受度高                                                │
│                                                                  │
│   备选方案:                                                      │
│   ─────────────────────────────────────────                    │
│   Apache 2.0                                                    │
│   - 提供专利授权保护                                            │
│   - 需要声明修改内容                                            │
│   - 适合可能有专利的场景                                        │
│                                                                  │
│   GPLv3                                                         │
│   - 要求衍生作品也开源                                          │
│   - 防止闭源商业化                                              │
│   - 限制较多，可能影响贡献者                                    │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  建议: 采用 MIT License                                │  │
│   │  原因:                                                 │  │
│   │  1. 鼓励广泛使用和贡献                                 │  │
│   │  2. 允许他人商业化（如定制开发服务）                   │  │
│   │  3. 华为鸿蒙生态中MIT项目较多                          │  │
│   │  4. 用户可自由修改和分发                               │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 敏感信息分离架构

```
┌─────────────────────────────────────────────────────────────────┐
│                   敏感信息分离设计                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   必须分离的敏感信息                                             │
│   ─────────────────────────────────────────────────────────    │
│   1. API密钥                                                    │
│      - 华为云OBS AccessKey/SecretKey                           │
│      - 高德地图API Key                                          │
│      - 微信开放平台 AppID/AppSecret                             │
│      - Strava Client ID/Secret                                  │
│                                                                  │
│   2. 服务端配置                                                  │
│      - 数据库连接字符串                                         │
│      - JWT签名密钥                                              │
│      - 服务器地址和端口                                         │
│                                                                  │
│   3. 第三方服务凭证                                              │
│      - 推送服务配置                                             │
│      - 分析服务Token                                            │
│                                                                  │
│   解决方案: 配置文件分离                                         │
│   ─────────────────────────────────────────                    │
│                                                                  │
│   项目结构:                                                      │
│   ride-record/                                                  │
│   ├── .env.example              # 环境变量模板 (提交到Git)      │
│   ├── .env                      # 实际环境变量 (Git忽略)        │
│   ├── config/                   # 配置目录                      │
│   │   ├── default.json          # 默认配置 (提交)               │
│   │   ├── production.json       # 生产配置 (Git忽略)            │
│   │   └── development.json      # 开发配置 (Git忽略)            │
│   ├── .gitignore                # 确保敏感文件被忽略            │
│   └── ...                                                       │
│                                                                  │
│   .env.example 模板内容:                                        │
│   ─────────────────────────────────────────                    │
│   # 华为云OBS配置                                               │
│   OBS_ACCESS_KEY=your_access_key_here                          │
│   OBS_SECRET_KEY=your_secret_key_here                          │
│   OBS_BUCKET=your_bucket_name                                  │
│   OBS_REGION=cn-north-4                                        │
│                                                                  │
│   # 高德地图                                                    │
│   AMAP_API_KEY=your_amap_key_here                              │
│                                                                  │
│   # 微信开放平台                                                 │
│   WECHAT_APP_ID=your_wechat_app_id                             │
│   WECHAT_APP_SECRET=your_wechat_secret                         │
│                                                                  │
│   # 服务端配置                                                   │
│   JWT_SECRET=your_random_jwt_secret                            │
│   SERVER_PORT=3000                                              │
│                                                                  │
│   .gitignore 必须包含:                                          │
│   ─────────────────────────────────────────                    │
│   .env                                                          │
│   config/production.json                                        │
│   config/development.json                                       │
│   *.pem                                                         │
│   *.p12                                                         │
│   credentials/                                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.3 代码结构规范

```
┌─────────────────────────────────────────────────────────────────┐
│                    开源友好代码结构                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   推荐项目结构                                                   │
│   ─────────────────────────────────────────────────────────    │
│   ride-record/                                                  │
│   │                                                              │
│   ├── LICENSE                   # MIT许可证                     │
│   ├── README.md                 # 项目说明 (重要!)              │
│   ├── README_EN.md              # 英文说明 (国际化)             │
│   ├── CONTRIBUTING.md           # 贡献指南                      │
│   ├── CODE_OF_CONDUCT.md        # 行为准则                      │
│   ├── SECURITY.md               # 安全披露流程                  │
│   ├── CHANGELOG.md              # 变更日志                      │
│   │                                                              │
│   ├── docs/                     # 文档目录                      │
│   │   ├── index.md              # 文档首页                      │
│   │   ├── getting-started.md    # 快速开始                      │
│   │   ├── architecture.md       # 架构说明                      │
│   │   ├── api-reference.md      # API文档                       │
│   │   ├── deployment.md         # 部署指南                      │
│   │   ├── contributing.md       # 详细贡献指南                  │
│   │   └── faq.md                # 常见问题                      │
│   │                                                              │
│   ├── phone/                    # 手机应用源码                  │
│   │   ├── README.md             # 手机端说明                    │
│   │   ├── docs/                 # 手机端文档                    │
│   │   └── src/                  # 源码                          │
│   │                                                              │
│   ├── watch/                    # 手表应用源码                  │
│   │   ├── README.md             # 手表端说明                    │
│   │   ├── docs/                 # 手表端文档                    │
│   │   └── src/                  # 源码                          │
│   │                                                              │
│   ├── server/                   # 服务端源码                    │
│   │   ├── README.md             # 服务端说明                    │
│   │   ├── docs/                 # 服务端文档                    │
│   │   ├── src/                  # 源码                          │
│   │   └── tests/                # 测试代码                      │
│   │                                                              │
│   ├── web/                      # Web端源码                     │
│   │   ├── README.md             # Web端说明                     │
│   │   └── src/                  # 源码                          │
│   │                                                              │
│   ├── shared/                   # 共享代码                      │
│   │   ├── types/                # 共享类型定义                  │
│   │   ├── utils/                # 共享工具函数                  │
│   │   └── constants/            # 共享常量                      │
│   │                                                              │
│   ├── scripts/                  # 构建和部署脚本                │
│   │   ├── build.sh              # 构建脚本                      │
│   │   ├── deploy.sh             # 部署脚本                      │
│   │   └── release.sh            # 发布脚本                      │
│   │                                                              │
│   ├── .github/                  # GitHub配置                    │
│   │   ├── ISSUE_TEMPLATE/       # Issue模板                     │
│   │   │   ├── bug_report.md                                     │
│   │   │   ├── feature_request.md                                │
│   │   │   └── question.md                                       │
│   │   ├── PULL_REQUEST_TEMPLATE.md                              │
│   │   ├── workflows/            # CI/CD工作流                   │
│   │   │   ├── ci.yml            # 持续集成                      │
│   │   │   └── release.yml       # 发布流程                      │
│   │   └── FUNDING.yml           # 赞助信息                      │
│   │                                                              │
│   └── docker/                   # Docker配置 (可选)             │
│       ├── Dockerfile                                            │
│       └── docker-compose.yml                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.4 必备文档清单

```
┌─────────────────────────────────────────────────────────────────┐
│                     开源必备文档                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   1. README.md (最重要!)                                        │
│   ─────────────────────────────────────────────────────────    │
│   必须包含:                                                      │
│   - 项目Logo/标题                                               │
│   - 一句话简介                                                   │
│   - 功能特性列表                                                 │
│   - 截图/GIF演示                                                 │
│   - 快速开始 (安装+运行)                                         │
│   - 使用文档链接                                                 │
│   - 贡献指南链接                                                 │
│   - 许可证信息                                                   │
│   - 徽章 (Build Status, License, Version等)                     │
│                                                                  │
│   模板示例:                                                      │
│   ─────────────────────────────────────────                    │
│   # RideRecord                                                  │
│                                                                  │
│   [Logo]                                                        │
│                                                                  │
│   > 🚴 智能骑行记录应用 - 动作检测自动启停，探险导航模式        │
│                                                                  │
│   [![License](https://img.shields.io/badge/license-MIT-blue)]  │
│   [![Platform](https://img.shields.io/badge/platform-HarmonyOS │
│   -Watch-orange)]                                               │
│                                                                  │
│   ## ✨ 特性                                                     │
│   - 🎯 动作检测自动启停 - 忘记点开始也没关系                    │
│   - 🗺️ 探险导航模式 - 支持土路、村道、山地车道                 │
│   - ⚠️ 冒险指数提示 - 实时评估路线风险                         │
│   - ☁️ 云端同步 - 华为云OBS存储                                │
│                                                                  │
│   ## 📱 截图                                                     │
│   [截图展示]                                                     │
│                                                                  │
│   ## 🚀 快速开始                                                 │
│   详见 [快速开始指南](docs/getting-started.md)                   │
│                                                                  │
│   ## 📖 文档                                                     │
│   - [架构设计](docs/architecture.md)                            │
│   - [API文档](docs/api-reference.md)                            │
│   - [部署指南](docs/deployment.md)                              │
│                                                                  │
│   ## 🤝 贡献                                                     │
│   详见 [贡献指南](CONTRIBUTING.md)                               │
│                                                                  │
│   ## 📄 许可证                                                   │
│   [MIT License](LICENSE)                                        │
│                                                                  │
│   2. CONTRIBUTING.md (贡献指南)                                 │
│   ─────────────────────────────────────────────────────────    │
│   - 如何提交Issue                                               │
│   - 如何提交Pull Request                                        │
│   - 代码规范                                                    │
│   - 提交信息规范                                                │
│   - 分支策略                                                    │
│                                                                  │
│   3. SECURITY.md (安全披露)                                     │
│   ─────────────────────────────────────────                    │
│   - 支持的版本                                                   │
│   - 如何报告安全漏洞                                            │
│   - 响应时间承诺                                                 │
│   - 安全更新策略                                                 │
│                                                                  │
│   4. CHANGELOG.md (变更日志)                                    │
│   ─────────────────────────────────────────                    │
│   - 遵循 Keep a Changelog 格式                                  │
│   - 记录每个版本的变更                                          │
│   - 标注变更类型 (Added/Changed/Fixed/Removed等)                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.5 开源前自查清单

```
┌─────────────────────────────────────────────────────────────────┐
│                    开源前自查清单                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   代码质量                                                       │
│   □ 无硬编码的敏感信息 (API Key、密码等)                        │
│   □ 代码注释完整，关键逻辑有说明                                │
│   □ 无调试代码、console.log、TODO等                             │
│   □ 遵循代码规范，格式统一                                      │
│   □ 无未使用的代码和依赖                                        │
│                                                                  │
│   安全检查                                                       │
│   □ .gitignore 配置正确                                         │
│   □ 无敏感文件提交到Git                                         │
│   □ .env.example 已创建                                         │
│   □ 依赖无已知安全漏洞 (npm audit)                              │
│   □ 无个人信息泄露 (姓名、邮箱等在注释中)                       │
│                                                                  │
│   文档完整                                                       │
│   □ README.md 内容完整                                          │
│   □ CONTRIBUTING.md 已创建                                      │
│   □ LICENSE 文件已添加                                          │
│   □ 部署文档可操作                                              │
│   □ API文档准确                                                 │
│                                                                  │
│   法律合规                                                       │
│   □ 无侵犯第三方知识产权                                        │
│   □ 使用的第三方库许可证兼容                                    │
│   □ 无品牌商标侵权                                              │
│   □ 明确标注第三方库来源和许可证                                │
│                                                                  │
│   品牌保护                                                       │
│   □ 项目名称未被注册商标                                        │
│   □ Logo/图标原创或可商用                                      │
│   □ 域名可用                                                    │
│                                                                  │
│   技术准备                                                       │
│   □ CI/CD流程正常                                               │
│   □ 测试覆盖率足够                                              │
│   □ Issue模板已创建                                             │
│   □ PR模板已创建                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.6 第三方依赖许可证合规

```
┌─────────────────────────────────────────────────────────────────┐
│                  第三方依赖许可证管理                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   需要在项目中声明的主要依赖:                                    │
│   ─────────────────────────────────────────────────────────    │
│                                                                  │
│   手机端 (HarmonyOS)                                            │
│   ┌──────────────────┬────────────────┬─────────────────────┐  │
│   │ 依赖             │ 许可证         │ 备注                │  │
│   ├──────────────────┼────────────────┼─────────────────────┤  │
│   │ ArkUI            │ Apache 2.0     │ 华为官方            │  │
│   │ 高德地图SDK      │ 商业许可       │ 需申请免费Key       │  │
│   │ 华为地图Kit      │ 华为许可       │ 需华为开发者账号    │  │
│   └──────────────────┴────────────────┴─────────────────────┘  │
│                                                                  │
│   服务端 (Node.js)                                               │
│   ┌──────────────────┬────────────────┬─────────────────────┐  │
│   │ 依赖             │ 许可证         │ 备注                │  │
│   ├──────────────────┼────────────────┼─────────────────────┤  │
│   │ Express          │ MIT            │                     │  │
│   │ Prisma           │ Apache 2.0     │                     │  │
│   │ better-sqlite3   │ MIT            │                     │  │
│   │ Axios            │ MIT            │                     │  │
│   │ 华为云OBS SDK    │ Apache 2.0     │                     │  │
│   └──────────────────┴────────────────┴─────────────────────┘  │
│                                                                  │
│   Web端 (Vue)                                                    │
│   ┌──────────────────┬────────────────┬─────────────────────┐  │
│   │ 依赖             │ 许可证         │ 备注                │  │
│   ├──────────────────┼────────────────┼─────────────────────┤  │
│   │ Vue 3            │ MIT            │                     │  │
│   │ Vite             │ MIT            │                     │  │
│   │ ECharts          │ Apache 2.0     │                     │  │
│   │ TailwindCSS      │ MIT            │                     │  │
│   └──────────────────┴────────────────┴─────────────────────┘  │
│                                                                  │
│   许可证兼容性说明:                                              │
│   ─────────────────────────────────────────                    │
│   MIT + Apache 2.0 → 兼容，可以合并使用                        │
│   MIT + GPLv3    → 兼容，但整体需遵循GPLv3                      │
│                                                                  │
│   建议在项目中添加 THIRD-PARTY-NOTICES 文件                     │
│   列出所有第三方依赖及其许可证                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.7 商业化考量

```
┌─────────────────────────────────────────────────────────────────┐
│                    开源与商业化平衡                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   开源策略                                                       │
│   ─────────────────────────────────────────────────────────    │
│   ✓ 核心功能完全开源 (MIT许可)                                  │
│   ✓ 社区贡献欢迎                                                │
│   ✓ Issue和PR公开透明                                           │
│                                                                  │
│   可能的商业化方向                                               │
│   ─────────────────────────────────────────                    │
│   1. 云托管服务 (SaaS)                                          │
│      - 提供一键部署的云端版本                                    │
│      - 付费用户提供更大存储空间                                  │
│      - 团队协作功能                                              │
│                                                                  │
│   2. 定制开发服务                                                │
│      - 企业级定制                                                │
│      - 品牌定制                                                  │
│      - 功能定制                                                  │
│                                                                  │
│   3. 高级功能订阅                                                │
│      - 高级数据分析                                              │
│      - 训练计划                                                  │
│      - 教练功能                                                  │
│                                                                  │
│   4. 硬件周边                                                    │
│      - 品牌骑行装备                                              │
│      - 手机支架等配件                                            │
│                                                                  │
│   代码架构建议 (支持商业化扩展)                                  │
│   ─────────────────────────────────────────                    │
│   - 核心功能与扩展功能分离                                      │
│   - 插件化架构                                                  │
│   - 配置驱动功能开关                                            │
│   - 商业模块可单独闭源                                          │
│                                                                  │
│   示例:                                                          │
│   ride-record/                                                  │
│   ├── core/                     # 核心开源                     │
│   ├── extensions/               # 扩展插件 (部分可闭源)        │
│   │   ├── free/                 # 免费扩展                      │
│   │   └── premium/              # 付费扩展 (私有仓库)          │
│   └── plugins/                  # 社区插件                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.8 社区建设计划

```
┌─────────────────────────────────────────────────────────────────┐
│                    社区建设路线图                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   阶段一: 项目启动 (0-3个月)                                    │
│   ─────────────────────────────────────────────────────────    │
│   - 发布第一个稳定版本                                           │
│   - 创建GitHub仓库和文档                                        │
│   - 在V2EX、掘金、知乎等平台宣传                                │
│   - 收集早期用户反馈                                            │
│                                                                  │
│   阶段二: 社区成长 (3-6个月)                                    │
│   ─────────────────────────────────────────                    │
│   - 建立微信群/Discord社区                                      │
│   - 完善贡献者文档                                              │
│   - 发布开发者指南                                              │
│   - 接受社区PR                                                  │
│   - 设置Good First Issue标签                                    │
│                                                                  │
│   阶段三: 生态建设 (6-12个月)                                   │
│   ─────────────────────────────────────────                    │
│   - 插件系统                                                    │
│   - 开放API                                                     │
│   - 开发者大会/Meetup                                           │
│   - 建立合作伙伴关系                                            │
│                                                                  │
│   社区运营建议                                                   │
│   ─────────────────────────────────────────                    │
│   1. 定期发布开发进度                                           │
│   2. 及时响应Issue和PR                                          │
│   3. 感谢贡献者 (README中列出)                                  │
│   4. 发布月度/季度更新                                          │
│   5. 组织线上交流活动                                            │
│                                                                  │
│   潜在合作平台                                                   │
│   ─────────────────────────────────────────                    │
│   - 华为开发者联盟                                              │
│   - Gitee (国内开源平台)                                        │
│   - 开源中国                                                    │
│   - 骑行社区 (骑行西藏、黑鸟单车等)                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.9 风险与应对

```
┌─────────────────────────────────────────────────────────────────┐
│                    开源风险评估与应对                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   风险一: 竞品抄袭                                               │
│   ─────────────────────────────────────────                    │
│   风险: 他人基于开源代码开发竞品                                │
│   应对:                                                         │
│   - 持续创新，保持技术领先                                      │
│   - 建立品牌认知度                                              │
│   - 社区运营形成护城河                                          │
│   - MIT许可证下，这是允许的行为                                 │
│                                                                  │
│   风险二: 代码质量参差不齐                                      │
│   ─────────────────────────────────────────                    │
│   风险: 社区提交代码质量不稳定                                  │
│   应对:                                                         │
│   - 建立Code Review流程                                         │
│   - CI自动化测试                                                │
│   - 清晰的代码规范文档                                          │
│   - PR模板强制填写                                              │
│                                                                  │
│   风险三: 安全漏洞披露                                          │
│   ─────────────────────────────────────────                    │
│   风险: 安全漏洞被公开前未修复                                  │
│   应对:                                                         │
│   - 建立SECURITY.md流程                                         │
│   - 私下接收漏洞报告                                            │
│   - 及时修复并发布安全版本                                      │
│   - 设置安全邮箱 security@riderecord.com                        │
│                                                                  │
│   风险四: 维护精力不足                                           │
│   ─────────────────────────────────────────                    │
│   风险: 个人精力有限，项目停滞                                  │
│   应对:                                                         │
│   - 培养核心贡献者                                              │
│   - 文档完善降低维护成本                                        │
│   - 功能请求投票机制                                            │
│   - 寻找商业合作                                                │
│                                                                  │
│   风险五: 法律纠纷                                               │
│   ─────────────────────────────────────────                    │
│   风险: 商标、专利、版权纠纷                                    │
│   应对:                                                         │
│   - 使用原创命名和设计                                          │
│   - 避免使用他人商标                                            │
│   - 第三方依赖合规检查                                          │
│   - 考虑申请软件著作权                                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 修订历史

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0 | 2026-03-06 | Claude | 初始版本 |
| 1.1 | 2026-03-06 | Claude | 改为轻量化架构：SQLite替代PostgreSQL/Redis，单机部署，添加手表应用安装和华为应用市场发布指南 |
| 1.2 | 2026-03-06 | Claude | 添加开源发布规划：许可证选择、敏感信息分离、代码结构规范、必备文档、商业化考量、社区建设、风险评估 |
| 1.3 | 2026-03-06 | Claude | 添加Docker容器化部署方案：多阶段Dockerfile、docker-compose配置、镜像优化、Docker Hub发布流程 |

---

**文档状态**: 已批准

**下一步**: 已创建 feature-list.json，开始 Worker 阶段实现功能

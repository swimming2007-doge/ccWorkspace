# RideRecord - 发布说明

## 版本历史

### [0.1.0] - 2026-03-06

#### 新增
- 项目初始化
- 创建设计文档 (ride-record-design.md)
- 创建需求规格说明书 (ride-record-srs.md)
- 创建UI组件设计指南 (ride-record-ucd.md)
- 创建 feature-list.json 任务清单
- 创建 task-progress.md 进度追踪
- **F004 动作检测核心算法** (手表端)
  - 传感器数据采集服务 (加速度计、陀螺仪、心率、GPS)
  - 数据缓冲队列 (滑动窗口 5秒@50Hz)
  - 特征提取算法 (时域+频域)
  - 动作分类器 (决策树)
  - 骑行状态机 (IDLE/RIDING/PAUSED/ENDING)
  - 单元测试覆盖
- **F005 手表端骑行界面** (手表端)
  - 数据展示组件 (DataCard, HeartRateRing, SpeedDisplay)
  - 骑行中页面 (实时速度/距离/时间/心率)
  - 骑行总结页面 (统计数据、心率区间分布)
  - 页面导航和状态管理集成
- **F006 手机-手表BLE通信** (手机+手表)
  - BLE通信协议定义 (UUID、数据包格式)
  - BLE协议工具类 (分包/重组)
  - 手表端BLE服务 (广播、连接、数据发送)
  - 手机端BLE客户端 (扫描、连接、数据接收)
  - 断线重连机制
- **F007 GPS数据采集** (手机+手表)
  - 手机端GPS服务 (高精度定位)
  - 手表端GPS服务 (低功耗定位)
  - 卡尔曼滤波轨迹平滑
  - 道格拉斯-普克算法简化
  - GPS信号丢失处理 (位置外推)
  - 手机+手表GPS数据融合
- **F008 心率数据采集** (手表)
  - 心率传感器数据采集 (1Hz)
  - 心率区间计算 (Z1-Z5)
  - 心率异常检测 (过高/过低/不规律)
  - 心率统计数据 (平均/最大/最小/区间分布)
- **F009 手机端实时数据看板** (手机)
  - 骑行数据管理服务 (RideDataService.ets)
  - 数据展示组件 (DataCard, HeartRateRing, SpeedDisplay)
  - 实时看板页面 (速度/距离/时间/心率/海拔)
  - 心率区间可视化 (环形图 + 分布条)
  - 地图轨迹实时绘制组件
  - 支持横竖屏切换
- **F010 骑行记录存储** (手机)
  - 数据库服务 (DatabaseService.ets)
  - 骑行记录存储服务 (RideStorageService.ets)
  - 数据导出服务 (ExportService.ets)
  - GPX/TCX/JSON 格式导出
  - 轨迹点按月分表优化
- **F011 手机端骑行记录列表** (手机)
  - 列表项组件 (RideListItem.ets)
  - 统计摘要卡片 (RideStatsCard)
  - 筛选组件 (FilterChip)
  - 时间筛选 (全部/本周/本月/今年)
  - 排序选项 (最新/最早/距离/时长)
  - 分页加载
- **F012 手机端骑行详情页** (手机)
  - 详情数据组件 (RideDetailComponents.ets)
  - 数据摘要展示
  - 心率区间分布图
  - 速度/心率/海拔图表
  - 轨迹地图展示
  - 导出选项 (GPX/TCX/JSON)
  - 分享和删除功能
- **F013 公路导航模式** (手机)
  - 导航服务 (NavigationService.ets)
  - 路线规划功能
  - 导航界面组件 (NavigationComponents.ets)
  - 转向提示卡片
  - 导航信息面板
  - 偏离路线检测
  - 导航控制按钮
  - 导航页面 (NavigationPage.ets)
- **F014 云端同步服务** (手机+服务端)
  - 手机端同步服务 (SyncService.ets)
  - 同步状态管理和进度追踪
  - 断点续传支持
  - 增量同步
  - 自动同步和批量同步
  - 同步界面组件 (SyncComponents.ets)
  - 同步页面 (SyncPage.ets)
  - 服务端OBS存储服务 (obs.service.ts)
  - 华为云OBS SDK集成
  - 分片上传支持
  - 服务端同步服务 (sync.service.ts)
  - 数据上传处理API
  - 增量同步API
  - 批量同步接口
- **F015 用户认证服务** (手机+服务端)
  - 手机端认证服务 (AuthService.ets)
  - 华为账号OAuth登录
  - JWT Token管理和刷新
  - 登录状态持久化
  - 游客模式登录
  - 登录页面 (LoginPage.ets)
  - 个人中心组件
  - 服务端认证服务 (auth.service.ts)
  - OAuth回调处理
  - JWT生成和验证
- **F016 探险导航模式** (手机)
  - 探险路网数据服务 (TrailDataService.ets)
  - 探险导航服务 (AdventureNavigationService.ets)
  - 支持土路、村道、山地车道、小径导航
  - 混合路线规划算法
  - 探险路线渲染组件 (AdventureRouteRenderer.ets)
  - 路况预警组件 (RoadWarningComponent.ets)
  - 冒险指数指示器 (AdventureIndexIndicator.ets)
  - 路况预警提示功能
- **F017 冒险指数计算** (手机)
  - 冒险指数计算服务 (RiskIndexService.ets)
  - 6因素评估模型 (路面、坡度、交通、信号、补给、天气)
  - 高程数据服务 (ElevationService.ets)
  - 天气数据服务 (WeatherService.ets)
  - 信号覆盖服务 (SignalCoverageService.ets)
  - 实时风险等级评估
  - 安全建议生成
- **F018 离线地图** (手机)
  - 离线地图服务 (OfflineMapService.ets)
  - 瓦片下载服务 (TileDownloadService.ets)
  - 存储空间管理服务 (StorageManager.ets)
  - 区域管理 (添加/删除/重命名)
  - 下载任务管理 (开始/暂停/继续)
  - 存储空间监控和预警
  - LRU清理策略
  - 地图更新检测
  - 离线地图UI组件 (OfflineMapComponents.ets)
  - 离线地图页面 (OfflineMapPage.ets)
- **F021 微信分享功能** (手机)
  - 微信分享服务 (WeChatShareService.ets)
  - 分享图片生成器 (ShareImageGenerator.ets)
  - 微信好友/群分享
  - 朋友圈分享
  - 4种分享模板 (简约/运动/探险/数据)
  - 分享内容定制 (位置/速度/心率/热量)
  - 分享图片轨迹渲染
  - 分享UI组件 (ShareComponents.ets)
  - 分享页面 (SharePage.ets)
- **F022 Strava同步** (手机+服务端)
  - 手机端Strava服务 (StravaService.ets)
  - 服务端Strava服务 (strava.service.ts)
  - OAuth 2.0 认证流程
  - GPX 文件生成和上传
  - Token 管理和刷新
  - 同步状态管理
  - Webhook 事件处理
  - Strava UI组件 (StravaComponents.ets)
  - Strava同步页面 (StravaPage.ets)
- **F025 开源准备** (文档)
  - LICENSE 文件 (MIT)
  - README.md 中文版
  - README_EN.md 英文版
  - CONTRIBUTING.md 贡献指南
  - SECURITY.md 安全策略
  - CHANGELOG.md 更新日志
  - GitHub Issue 模板 (bug_report.md, feature_request.md)
  - GitHub PR 模板 (PULL_REQUEST_TEMPLATE.md)
  - CI 工作流 (ci.yml)
  - Dependabot 配置 (dependabot.yml)
  - CODEOWNERS 配置

#### 技术架构
  - 设置服务 (SettingsService.ets)
  - 骑行偏好设置 (导航模式、单位制、语音等)
  - 动作检测设置 (自动启停、灵敏度、超时)
  - 同步设置 (云端同步、自动同步、WiFi限制)
  - 隐私设置 (位置分享、心率分享、公开资料)
  - 设置界面组件 (SettingsComponents.ets)
  - 设置页面 (SettingsPage.ets)
- **F019 统计分析模块** (手机)
  - 统计服务 (StatsService.ets)
  - 日/周/月/年统计
  - 趋势分析
  - 心率区间分布
  - 热量消耗计算
  - 个人记录
  - 统计界面组件 (StatsComponents.ets)
  - 统计页面 (StatsPage.ets)
- **F020 Web端数据看板** (Web)
  - Vue 3 + TypeScript + Vite 项目骨架
  - TailwindCSS 样式配置
  - Vue Router 路由
  - Pinia 状态管理
  - API 服务封装
  - 认证存储
  - 骑行数据存储
  - 导航组件
  - 登录页面
  - 数据看板页面
  - 骑行列表页面
  - 骑行详情页面
  - 统计分析页面
- **F024 性能优化与NFR验证** (全平台)
  - 手机端性能监控服务 (PerformanceMonitor.ets)
  - 手表端性能监控服务 (PerformanceMonitor.ets)
  - 服务端性能监控服务 (performance.service.ts)
  - Web端性能监控服务 (performance.ts)
  - NFR指标验证框架
  - 性能报告文档
  - Web Vitals 监控
  - Vue 3 + TypeScript + Vite 项目骨架
  - TailwindCSS 样式配置
  - Vue Router 路由
  - Pinia 状态管理
  - API 服务封装
  - 认证存储
  - 骑行数据存储
  - 导航组件
  - 登录页面
  - 数据看板页面
  - 骑行列表页面
  - 骑行详情页面
  - 统计分析页面

#### 技术架构
- 采用轻量化单体架构
- 手机端: HarmonyOS + ArkTS + SQLite
- 手表端: Watch OS + ArkTS
- 服务端: Node.js + Express + SQLite + 华为云OBS
- Web端: Vue 3 + TypeScript + Vite

---

## 计划版本

### [1.0.0-alpha] - 计划中

#### MVP 功能
- 动作检测自动启停
- GPS轨迹记录
- 心率数据采集
- 实时数据看板
- 骑行记录存储
- 公路导航模式
- 云端同步

### [1.0.0] - 计划中

#### 完整功能
- 所有MVP功能
- 探险导航模式
- 冒险指数计算
- 离线地图
- Web端查看
- 微信分享
- Strava同步

---

## 发布检查清单

### MVP 发布前

- [ ] 所有P0功能测试通过
- [ ] 性能指标达标 (启动<3秒, 内存<200MB)
- [ ] 动作检测准确率 > 85%
- [ ] GPS精度 < 10米
- [ ] 电池消耗 < 15%/小时 (手机)
- [ ] 华为应用市场审核通过

### 正式版发布前

- [ ] 所有P1功能测试通过
- [ ] Web端响应式测试通过
- [ ] 社交分享功能正常
- [ ] 第三方平台同步正常
- [ ] 安全审计通过
- [ ] 文档完善

---

*格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)*

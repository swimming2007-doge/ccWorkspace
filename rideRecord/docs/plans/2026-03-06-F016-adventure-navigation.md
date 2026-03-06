# F016 探险导航模式 - 实现计划

**功能ID**: F016
**优先级**: P1
**里程碑**: M5
**平台**: phone
**创建日期**: 2026-03-06
**SRS引用**: FR-003-02
**依赖**: F013 (公路导航模式)

---

## 1. 概述

本文档定义 F016 探险导航模式的实现计划，扩展现有的公路导航服务，支持土路、村道、山地车道等非公路路线导航。

### 1.1 功能需求 (FR-003-02)

| 属性 | 描述 |
|------|------|
| 描述 | 提供包含非公路路线的导航，支持土路、村道、山地车道 |
| 路线类型 | 村道（水泥/柏油路面）、土路（砂石路面）、山地车道（崎岖路面）、小径（仅自行车可通行） |
| 冒险指数 | 实时计算并显示：1-5级 |

### 1.2 实现范围

1. **探险路网数据获取** - 获取非公路路网数据
2. **混合路线规划算法** - 结合公路和探险路线
3. **探险路线UI渲染** - 不同路线类型的可视化
4. **路况预警提示** - 实时路况警告

---

## 2. 架构设计

### 2.1 探险导航服务架构

```
┌─────────────────────────────────────────────────────────────────┐
│                   探险导航模块架构                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                  AdventureNavigationService              │  │
│   │                                                          │  │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │  │
│   │   │ 路网数据    │  │ 路线规划    │  │ 路况预警    │    │  │
│   │   │ 获取服务    │  │ 算法引擎    │  │ 服务        │    │  │
│   │   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │  │
│   │          │                │                │            │  │
│   │          ▼                ▼                ▼            │  │
│   │   ┌─────────────────────────────────────────────────┐  │  │
│   │   │              探险路线数据模型                    │  │  │
│   │   │  - 路段类型 (road/trail/path)                   │  │  │
│   │   │  - 路面状况 (paved/gravel/dirt/rough)          │  │  │
│   │   │  - 坡度等级                                     │  │  │
│   │   │  - 冒险指数 (1-5)                               │  │  │
│   │   │  - 路况预警信息                                 │  │  │
│   │   └─────────────────────────────────────────────────┘  │  │
│   │                                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                    探险路线UI组件                        │  │
│   │                                                          │  │
│   │   AdventureRouteRenderer.ets                           │  │
│   │   ├── 路线颜色编码 (公路=蓝, 探险=橙, 危险=红)         │  │
│   │   ├── 路况图标显示                                     │  │
│   │   ├── 冒险指数指示器                                   │  │
│   │   └── 路况预警弹窗                                     │  │
│   │                                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 数据模型

```typescript
// 路线类型
export enum TrailType {
  ROAD = 'road',           // 公路
  VILLAGE = 'village',     // 村道
  DIRT = 'dirt',           // 土路
  TRAIL = 'trail',         // 山地车道
  PATH = 'path'            // 小径
}

// 路面类型
export enum SurfaceType {
  PAVED = 'paved',         // 铺装路面
  GRAVEL = 'gravel',       // 碎石路面
  DIRT = 'dirt',           // 泥土路面
  ROUGH = 'rough',         // 崎岖路面
  SAND = 'sand'            // 沙地
}

// 路况预警类型
export enum RoadWarningType {
  STEEP_UPHILL = 'steep_uphill',     // 陡坡上坡
  STEEP_DOWNHILL = 'steep_downhill', // 陡坡下坡
  ROUGH_SURFACE = 'rough_surface',   // 崎岖路面
  WATER_CROSSING = 'water_crossing', // 涉水路段
  LOW_SIGNAL = 'low_signal',         // 信号弱
  NO_SERVICE = 'no_service',         // 无补给点
  NARROW_PATH = 'narrow_path',       // 窄路
  TRAFFIC = 'traffic'                // 交通注意
}

// 探险路段
export interface AdventureSegment {
  type: TrailType;
  surface: SurfaceType;
  distance: number;          // 距离 (米)
  slopeGrade: number;        // 坡度等级 (1-5)
  adventureIndex: number;    // 冒险指数 (1-5)
  warnings: RoadWarning[];
  coordinates: Coordinate[];
}

// 路况预警
export interface RoadWarning {
  type: RoadWarningType;
  location: Coordinate;
  distance: number;          // 距当前位置的距离
  severity: 'info' | 'warning' | 'danger';
  message: string;
}
```

---

## 3. 实现任务

### 3.1 探险路网数据服务

**文件**: `phone/entry/src/main/ets/services/TrailDataService.ets`

**任务列表**:
1. 创建 TrailDataService 服务类
2. 实现路网数据获取接口
3. 实现路网数据缓存
4. 实现离线路网数据支持

**关键代码结构**:
```typescript
export class TrailDataService {
  // 获取区域内的探险路网
  async getTrailsInBounds(bounds: BoundingBox): Promise<AdventureSegment[]>;

  // 获取路段详情
  async getTrailDetails(trailId: string): Promise<AdventureSegment>;

  // 缓存路网数据
  async cacheTrailData(bounds: BoundingBox): Promise<void>;
}
```

### 3.2 探险导航服务

**文件**: `phone/entry/src/main/ets/services/AdventureNavigationService.ets`

**任务列表**:
1. 创建探险导航服务类 (继承 NavigationService)
2. 实现探险路线规划算法
3. 实现混合路线规划算法
4. 实现路况预警检测
5. 实现冒险指数计算

**关键代码结构**:
```typescript
export class AdventureNavigationService extends NavigationService {
  // 规划探险路线
  async planAdventureRoute(
    start: Coordinate,
    end: Coordinate,
    options: AdventureNavigationOptions
  ): Promise<AdventureRoute>;

  // 规划混合路线
  async planHybridRoute(
    start: Coordinate,
    end: Coordinate,
    adventureRatio: number
  ): Promise<AdventureRoute>;

  // 获取前方路况预警
  async getUpcomingWarnings(
    currentLocation: Coordinate,
    distance: number
  ): Promise<RoadWarning[]>;
}
```

### 3.3 探险路线渲染组件

**文件**: `phone/entry/src/main/ets/components/AdventureRouteRenderer.ets`

**任务列表**:
1. 创建探险路线渲染组件
2. 实现不同路线类型的颜色编码
3. 实现路况图标显示
4. 实现冒险指数指示器

### 3.4 路况预警组件

**文件**: `phone/entry/src/main/ets/components/RoadWarningComponent.ets`

**任务列表**:
1. 创建路况预警弹窗组件
2. 实现预警提示卡片
3. 实现语音预警播报

---

## 4. 文件清单

### 新增文件

| 文件路径 | 描述 |
|----------|------|
| `phone/entry/src/main/ets/services/TrailDataService.ets` | 探险路网数据服务 |
| `phone/entry/src/main/ets/services/AdventureNavigationService.ets` | 探险导航服务 |
| `phone/entry/src/main/ets/components/AdventureRouteRenderer.ets` | 探险路线渲染组件 |
| `phone/entry/src/main/ets/components/RoadWarningComponent.ets` | 路况预警组件 |
| `phone/entry/src/main/ets/components/AdventureIndexIndicator.ets` | 冒险指数指示器 |

---

## 5. 验收标准

### 5.1 功能验收

- [ ] 支持土路、村道、山地车道导航
- [ ] 路线规划算法合理
- [ ] 路况预警准确
- [ ] 冒险指数显示正确

### 5.2 集成验收

- [ ] 与现有导航服务兼容
- [ ] 地图渲染正常
- [ ] 语音提示正常

---

## 6. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 探险路网数据不全 | 高 | 使用多源数据 + 用户贡献 |
| 离线数据量大 | 中 | 分区域下载 + 增量更新 |

---

*创建日期: 2026-03-06*

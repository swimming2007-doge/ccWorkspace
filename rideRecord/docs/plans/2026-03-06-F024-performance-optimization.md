# F024 性能优化与NFR验证 - 实现计划

**功能ID**: F024
**优先级**: P0
**里程碑**: M6
**平台**: phone, watch, server, web
**创建日期**: 2026-03-06
**SRS引用**: NFR-001

---

## 1. 概述

本文档定义 F024 性能优化与NFR验证的实现计划，目标是确保应用满足所有非功能性需求指标。

### 1.1 NFR 目标指标

| ID | 指标 | 目标值 | 平台 |
|----|------|--------|------|
| NFR-001-01 | 应用启动时间 | < 3 秒 | phone, watch, web |
| NFR-001-02 | 动作检测响应时间 | < 3 秒 | watch |
| NFR-001-03 | GPS定位精度 | < 10 米 | phone, watch |
| NFR-001-04 | 数据同步延迟 | < 30 秒 | phone, server |
| NFR-001-05 | 导航路径计算时间 | < 5 秒 | phone |
| NFR-001-06 | 内存占用（前台） | < 200 MB | phone, web |
| NFR-001-07 | 电池消耗（1小时骑行） | < 15%（手机）, < 10%（手表） | phone, watch |

### 1.2 实现范围

1. **性能监控服务** - 各平台统一的性能数据采集
2. **优化策略实现** - 针对每个指标的优化措施
3. **验证测试套件** - 自动化性能测试
4. **性能报告** - 可视化的性能报告生成

---

## 2. 架构设计

### 2.1 性能监控架构

```
┌─────────────────────────────────────────────────────────────────┐
│                     性能监控架构                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                   手机端监控 (Phone)                     │  │
│   │                                                          │  │
│   │   PerformanceMonitor.ets                                │  │
│   │   ├── StartupMonitor (启动时间)                         │  │
│   │   ├── MemoryMonitor (内存占用)                          │  │
│   │   ├── BatteryMonitor (电池消耗)                         │  │
│   │   ├── GpsAccuracyMonitor (GPS精度)                      │  │
│   │   └── SyncLatencyMonitor (同步延迟)                     │  │
│   │                                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                   手表端监控 (Watch)                     │  │
│   │                                                          │  │
│   │   PerformanceMonitor.ets                                │  │
│   │   ├── StartupMonitor (启动时间)                         │  │
│   │   ├── ActionDetectionMonitor (动作检测延迟)             │  │
│   │   ├── BatteryMonitor (电池消耗)                         │  │
│   │   └── GpsAccuracyMonitor (GPS精度)                      │  │
│   │                                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                   服务端监控 (Server)                    │  │
│   │                                                          │  │
│   │   performance.service.ts                                │  │
│   │   ├── ApiLatencyMonitor (API响应时间)                   │  │
│   │   ├── MemoryMonitor (内存占用)                          │  │
│   │   └── SyncThroughputMonitor (同步吞吐量)                │  │
│   │                                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                   Web端监控 (Web)                        │  │
│   │                                                          │  │
│   │   lib/performance.ts                                    │  │
│   │   ├── WebVitalsMonitor (Core Web Vitals)                │  │
│   │   ├── BundleSizeMonitor (包大小)                        │  │
│   │   └── RenderTimeMonitor (渲染时间)                      │  │
│   │                                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 数据模型

```typescript
// 性能指标数据结构
interface PerformanceMetric {
  id: string;
  type: 'startup' | 'memory' | 'battery' | 'gps' | 'sync' | 'action' | 'navigation';
  platform: 'phone' | 'watch' | 'server' | 'web';
  value: number;
  unit: 'ms' | 'MB' | 'percent' | 'meter' | 'second';
  timestamp: number;
  metadata?: Record<string, unknown>;
}

// 性能报告
interface PerformanceReport {
  generatedAt: number;
  platform: string;
  metrics: PerformanceMetric[];
  summary: {
    passed: number;
    failed: number;
    total: number;
  };
  recommendations: string[];
}
```

---

## 3. 实现任务

### 3.1 手机端性能监控服务

**文件**: `phone/entry/src/main/ets/shared/services/PerformanceMonitor.ets`

**任务列表**:
1. 创建 PerformanceMonitor 服务类
2. 实现启动时间监控 (冷启动、热启动)
3. 实现内存占用监控 (定时采样)
4. 实现电池消耗监控 (骑行前后对比)
5. 实现 GPS 精度监控 (与已知位置对比)
6. 实现同步延迟监控 (上传/下载时间)

**关键代码结构**:
```typescript
export class PerformanceMonitor {
  private static instance: PerformanceMonitor;
  private metrics: PerformanceMetric[] = [];

  // 启动时间监控
  static measureStartup(): Promise<number>;

  // 内存监控
  static startMemorySampling(): void;
  static stopMemorySampling(): PerformanceMetric[];

  // 电池监控
  static startBatteryTracking(): void;
  static endBatteryTracking(): PerformanceMetric;

  // GPS精度验证
  static verifyGpsAccuracy(knownLocation: Location): Promise<PerformanceMetric>;

  // 生成报告
  static generateReport(): PerformanceReport;
}
```

### 3.2 手表端性能监控服务

**文件**: `watch/entry/src/main/ets/services/PerformanceMonitor.ets`

**任务列表**:
1. 创建手表端 PerformanceMonitor 服务
2. 实现启动时间监控
3. 实现动作检测延迟监控
4. 实现电池消耗监控
5. 实现 GPS 精度监控

**关键代码结构**:
```typescript
export class PerformanceMonitor {
  // 动作检测延迟监控
  static measureActionDetectionLatency(): Promise<number>;

  // 其他监控方法与手机端类似
}
```

### 3.3 服务端性能监控服务

**文件**: `server/src/services/performance.service.ts`

**任务列表**:
1. 创建性能监控中间件
2. 实现 API 响应时间监控
3. 实现内存使用监控
4. 实现同步吞吐量监控
5. 创建性能报告 API

**关键代码结构**:
```typescript
export class PerformanceService {
  // 性能监控中间件
  static middleware(): RequestHandler;

  // API 响应时间记录
  static recordApiLatency(route: string, duration: number): void;

  // 性能报告
  static getReport(): PerformanceReport;
}
```

### 3.4 Web端性能监控

**文件**: `web/src/lib/performance.ts`

**任务列表**:
1. 实现 Web Vitals 监控 (LCP, FID, CLS)
2. 实现包大小分析
3. 实现页面渲染时间监控
4. 集成性能报告

**关键代码结构**:
```typescript
export class WebPerformanceMonitor {
  // Web Vitals
  static measureWebVitals(): Promise<WebVitals>;

  // 包大小分析
  static analyzeBundleSize(): Promise<BundleInfo>;

  // 页面渲染时间
  static measurePageRender(pageName: string): number;
}
```

### 3.5 优化策略实现

#### 3.5.1 启动时间优化

**手机端**:
- 延迟初始化非关键服务
- 使用懒加载组件
- 优化首屏渲染

**手表端**:
- 最小化启动时传感器初始化
- 延迟加载历史数据

**Web端**:
- 代码分割和懒加载
- 预加载关键资源
- 优化字体加载

#### 3.5.2 内存优化

**策略**:
- 轨迹点数据分批加载
- 图片压缩和缩略图
- 及时释放不用的资源
- 使用对象池复用

#### 3.5.3 电池优化

**策略**:
- 降低传感器采样频率（非骑行时）
- GPS 使用低功耗模式
- 减少屏幕刷新频率
- 优化网络请求频率

#### 3.5.4 GPS精度优化

**策略**:
- 卡尔曼滤波平滑
- 多源数据融合
- 信号强度评估
- 异常点过滤

### 3.6 验证测试套件

**文件**: `tests/performance/`

**测试用例**:
1. `startup.test.ts` - 启动时间测试
2. `memory.test.ts` - 内存占用测试
3. `battery.test.ts` - 电池消耗测试
4. `gps-accuracy.test.ts` - GPS精度测试
5. `sync-latency.test.ts` - 同步延迟测试
6. `action-detection.test.ts` - 动作检测延迟测试

---

## 4. 文件清单

### 新增文件

| 文件路径 | 描述 |
|----------|------|
| `phone/entry/src/main/ets/shared/services/PerformanceMonitor.ets` | 手机端性能监控服务 |
| `watch/entry/src/main/ets/services/PerformanceMonitor.ets` | 手表端性能监控服务 |
| `server/src/services/performance.service.ts` | 服务端性能监控服务 |
| `web/src/lib/performance.ts` | Web端性能监控 |
| `shared/types/performance.ts` | 性能类型定义 |
| `docs/performance-report.md` | 性能报告模板 |

### 测试文件

| 文件路径 | 描述 |
|----------|------|
| `tests/performance/startup.test.ts` | 启动时间测试 |
| `tests/performance/memory.test.ts` | 内存占用测试 |
| `tests/performance/battery.test.ts` | 电池消耗测试 |
| `tests/performance/gps-accuracy.test.ts` | GPS精度测试 |
| `tests/performance/nfr-validation.test.ts` | NFR验证测试套件 |

---

## 5. 验收标准

### 5.1 功能验收

- [ ] 性能监控服务可在各平台正常运行
- [ ] 所有性能指标可被正确采集和记录
- [ ] 性能报告可正确生成

### 5.2 NFR 指标验收

| ID | 指标 | 目标 | 验证方法 |
|----|------|------|----------|
| NFR-001-01 | 启动时间 | < 3秒 | 自动化测试 + 手动验证 |
| NFR-001-02 | 动作检测延迟 | < 3秒 | 模拟器测试 |
| NFR-001-03 | GPS精度 | < 10米 | 已知位置对比 |
| NFR-001-04 | 同步延迟 | < 30秒 | 网络监控 |
| NFR-001-05 | 导航计算时间 | < 5秒 | API计时 |
| NFR-001-06 | 内存占用 | < 200MB | 系统监控 |
| NFR-001-07 | 电池消耗 | < 15%/小时 | 真机测试 |

### 5.3 质量验收

- [ ] 无内存泄漏
- [ ] 无性能退化
- [ ] 测试覆盖率 > 80%

---

## 6. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 真机测试环境限制 | 高 | 使用模拟器 + 云测试平台 |
| 电池测试周期长 | 中 | 标准化测试流程 |
| GPS精度依赖环境 | 中 | 使用已知位置测试点 |

---

## 7. 时间估算

| 阶段 | 预计时间 |
|------|----------|
| 性能监控服务开发 | 2小时 |
| 优化策略实现 | 2小时 |
| 测试套件开发 | 1小时 |
| NFR验证测试 | 1小时 |
| **总计** | **6小时** |

---

*创建日期: 2026-03-06*

# F018 离线地图 - 实现计划

**日期**: 2026-03-06
**功能ID**: F018
**优先级**: P1
**里程碑**: M5

---

## 1. 概述

实现离线地图功能，确保用户在无网络环境下仍可进行骑行导航。支持按区域下载地图瓦片和高程数据，自动管理存储空间，支持增量更新。

## 2. 技术方案

### 2.1 存储结构

```
/offline-maps/
├── {region_id}/
│   ├── metadata.json        # 区域元信息 (名称、边界、大小、版本)
│   ├── vector/{z}/{x}/{y}.pbf  # 矢量瓦片 (Mapbox Vector Tiles)
│   ├── dem/{z}/{x}/{y}.png   # 高程瓦片 (DEM Tiles)
│   └── route_network.json    # 路网数据 (简化版)
└── index.db                 # 索引数据库 (SQLite)
```

### 2.2 核心组件

| 组件 | 职责 |
|------|------|
| OfflineMapService | 离线地图管理主服务 |
| TileDownloadService | 瓦片下载服务 |
| StorageManager | 存储空间管理 |
| OfflineMapDatabase | 离线地图索引数据库 |

### 2.3 下载策略

1. **瓦片范围计算**: 根据区域边界计算需要的瓦片坐标
2. **分批下载**: 每批 50 个瓦片，避免内存溢出
3. **断点续传**: 记录下载进度，支持中断后继续
4. **增量更新**: 只下载变更的瓦片

## 3. 实现任务

### 3.1 核心服务

- [ ] **OfflineMapService.ets** - 离线地图管理服务
  - 区域列表管理
  - 下载任务管理
  - 地图更新检测
  - 离线地图查询

- [ ] **TileDownloadService.ets** - 瓦片下载服务
  - 瓦片坐标计算
  - 批量下载
  - 进度追踪
  - 错误重试

- [ ] **StorageManager.ets** - 存储空间管理
  - 空间使用统计
  - LRU 淘汰策略
  - 自动清理策略

- [ ] **OfflineMapDatabase.ets** - 数据库服务
  - 索引表结构
  - 瓦片元数据
  - 下载记录

### 3.2 UI 组件

- [ ] **OfflineMapComponents.ets** - UI 组件
  - OfflineRegionCard - 区域卡片
  - DownloadProgressIndicator - 下载进度
  - StorageUsageBar - 存储使用条

- [ ] **OfflineMapPage.ets** - 离线地图页面
  - 区域列表
  - 下载管理
  - 存储设置

## 4. 接口设计

### 4.1 OfflineMapService

```typescript
interface OfflineRegion {
  id: string;
  name: string;
  bounds: BoundingBox;
  zoomRange: [number, number];
  size: number;
  downloadedSize: number;
  status: 'pending' | 'downloading' | 'completed' | 'error';
  version: string;
  createdAt: number;
  updatedAt: number;
}

interface DownloadProgress {
  regionId: string;
  totalTiles: number;
  downloadedTiles: number;
  currentSpeed: number;  // KB/s
  estimatedTime: number; // seconds
}

class OfflineMapService {
  // 区域管理
  getRegions(): Promise<OfflineRegion[]>;
  addRegion(region: OfflineRegionCreate): Promise<OfflineRegion>;
  removeRegion(regionId: string): Promise<void>;

  // 下载管理
  startDownload(regionId: string): Promise<void>;
  pauseDownload(regionId: string): Promise<void>;
  resumeDownload(regionId: string): Promise<void>;
  getDownloadProgress(regionId: string): DownloadProgress;

  // 地图查询
  hasOfflineTile(z: number, x: number, y: number): Promise<boolean>;
  getOfflineTilePath(z: number, x: number, y: number): string;

  // 存储管理
  getStorageUsage(): Promise<StorageUsage>;
  cleanupOldData(): Promise<void>;
}
```

### 4.2 存储空间管理

```typescript
interface StorageUsage {
  totalSpace: number;
  usedSpace: number;
  mapSpace: number;
  availableSpace: number;
  regions: {
    id: string;
    name: string;
    size: number;
  }[];
}

interface StorageConfig {
  maxStorageMB: number;  // 最大存储空间
  autoCleanup: boolean;  // 自动清理
  keepRecentDays: number; // 保留最近天数
}
```

## 5. 数据库设计

### 5.1 offline_regions 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT | 区域ID (主键) |
| name | TEXT | 区域名称 |
| min_lat | REAL | 最小纬度 |
| max_lat | REAL | 最大纬度 |
| min_lon | REAL | 最小经度 |
| max_lon | REAL | 最大经度 |
| min_zoom | INTEGER | 最小缩放级别 |
| max_zoom | INTEGER | 最大缩放级别 |
| total_size | INTEGER | 总大小 (bytes) |
| downloaded_size | INTEGER | 已下载大小 |
| status | TEXT | 状态 |
| version | TEXT | 版本号 |
| created_at | INTEGER | 创建时间 |
| updated_at | INTEGER | 更新时间 |

### 5.2 tile_index 表

| 字段 | 类型 | 说明 |
|------|------|------|
| region_id | TEXT | 区域ID |
| z | INTEGER | 缩放级别 |
| x | INTEGER | X坐标 |
| y | INTEGER | Y坐标 |
| type | TEXT | vector/dem |
| size | INTEGER | 文件大小 |
| downloaded | INTEGER | 是否已下载 |
| updated_at | INTEGER | 更新时间 |

## 6. 验收标准

- [ ] 支持按区域选择并下载地图
- [ ] 下载过程支持暂停/继续
- [ ] 存储空间管理正常，显示使用情况
- [ ] 离线状态下地图显示正常
- [ ] 支持增量更新
- [ ] 单元测试覆盖率 >= 80%

## 7. 依赖

- F013 公路导航模式 (已完成) - 地图组件和导航服务

## 8. 风险

| 风险 | 缓解措施 |
|------|----------|
| 瓦片数据量大 | 分批下载，增量更新 |
| 存储空间不足 | LRU淘汰，空间预警 |
| 下载中断 | 断点续传，进度保存 |

/**
 * 离线地图服务
 *
 * 功能说明：
 * - 离线地图区域管理
 * - 下载任务管理
 * - 地图更新检测
 * - 离线瓦片查询
 *
 * SRS引用: FR-003-05
 */
import hilog from '@ohos.hilog';
import { Coordinate } from '../utils/Types';

const TAG = '[OfflineMapService]';
const DOMAIN = 0xFF00;

/**
 * 边界框
 */
export interface BoundingBox {
  minLat: number;
  maxLat: number;
  minLon: number;
  maxLon: number;
}

/**
 * 离线区域状态
 */
export enum RegionStatus {
  PENDING = 'pending',
  DOWNLOADING = 'downloading',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  ERROR = 'error'
}

/**
 * 瓦片类型
 */
export enum TileType {
  VECTOR = 'vector',
  DEM = 'dem'
}

/**
 * 离线区域
 */
export interface OfflineRegion {
  id: string;
  name: string;
  bounds: BoundingBox;
  zoomRange: [number, number]; // [minZoom, maxZoom]
  totalSize: number;           // 总大小 (bytes)
  downloadedSize: number;      // 已下载大小
  status: RegionStatus;
  version: string;
  tileCount: number;           // 总瓦片数
  downloadedTiles: number;     // 已下载瓦片数
  createdAt: number;
  updatedAt: number;
}

/**
 * 创建区域参数
 */
export interface OfflineRegionCreate {
  name: string;
  bounds: BoundingBox;
  zoomRange: [number, number];
}

/**
 * 下载进度
 */
export interface DownloadProgress {
  regionId: string;
  totalTiles: number;
  downloadedTiles: number;
  currentSpeed: number;        // KB/s
  estimatedTime: number;       // seconds
  percent: number;             // 0-100
}

/**
 * 存储使用情况
 */
export interface StorageUsage {
  totalSpace: number;          // 总空间 (bytes)
  usedSpace: number;           // 已用空间
  mapSpace: number;            // 地图占用空间
  availableSpace: number;      // 可用空间
  regions: {
    id: string;
    name: string;
    size: number;
    percent: number;
  }[];
}

/**
 * 存储配置
 */
export interface StorageConfig {
  maxStorageMB: number;        // 最大存储空间
  autoCleanup: boolean;        // 自动清理
  keepRecentDays: number;      // 保留最近天数
}

/**
 * 瓦片信息
 */
export interface TileInfo {
  regionId: string;
  z: number;
  x: number;
  y: number;
  type: TileType;
  size: number;
  downloaded: boolean;
  updatedAt: number;
}

/**
 * 默认存储配置
 */
export const DEFAULT_STORAGE_CONFIG: StorageConfig = {
  maxStorageMB: 2048,          // 2GB
  autoCleanup: true,
  keepRecentDays: 90
};

/**
 * 预设区域
 */
export const PRESET_REGIONS: OfflineRegionCreate[] = [
  {
    name: '北京市区',
    bounds: { minLat: 39.8, maxLat: 40.1, minLon: 116.2, maxLon: 116.6 },
    zoomRange: [10, 15]
  },
  {
    name: '上海市区',
    bounds: { minLat: 31.1, maxLat: 31.4, minLon: 121.3, maxLon: 121.7 },
    zoomRange: [10, 15]
  },
  {
    name: '杭州市区',
    bounds: { minLat: 30.2, maxLat: 30.4, minLon: 120.1, maxLon: 120.3 },
    zoomRange: [10, 15]
  }
];

/**
 * 离线地图服务
 */
export class OfflineMapService {
  private static instance: OfflineMapService;

  // 区域缓存
  private regions: Map<string, OfflineRegion> = new Map();
  private tileIndex: Map<string, TileInfo> = new Map();

  // 下载状态
  private downloadProgress: Map<string, DownloadProgress> = new Map();
  private downloadCallbacks: Map<string, (progress: DownloadProgress) => void> = new Map();

  // 存储配置
  private storageConfig: StorageConfig = DEFAULT_STORAGE_CONFIG;

  // 配置
  private readonly TILE_SIZE_APPROX = 15 * 1024; // 约15KB每瓦片

  private constructor() {
    this.loadRegions();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): OfflineMapService {
    if (!OfflineMapService.instance) {
      OfflineMapService.instance = new OfflineMapService();
    }
    return OfflineMapService.instance;
  }

  // ==================== 区域管理 ====================

  /**
   * 获取所有区域
   */
  async getRegions(): Promise<OfflineRegion[]> {
    return Array.from(this.regions.values());
  }

  /**
   * 获取区域
   */
  getRegion(regionId: string): OfflineRegion | undefined {
    return this.regions.get(regionId);
  }

  /**
   * 添加区域
   */
  async addRegion(create: OfflineRegionCreate): Promise<OfflineRegion> {
    // 生成区域ID
    const id = this.generateRegionId(create);

    // 检查是否已存在
    if (this.regions.has(id)) {
      throw new Error(`区域 "${create.name}" 已存在`);
    }

    // 计算瓦片数量
    const tileCount = this.calculateTileCount(create.bounds, create.zoomRange);
    const totalSize = tileCount * this.TILE_SIZE_APPROX * 2; // vector + dem

    // 创建区域
    const region: OfflineRegion = {
      id,
      name: create.name,
      bounds: create.bounds,
      zoomRange: create.zoomRange,
      totalSize,
      downloadedSize: 0,
      status: RegionStatus.PENDING,
      version: '1.0.0',
      tileCount,
      downloadedTiles: 0,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };

    // 保存区域
    this.regions.set(id, region);
    await this.saveRegions();

    hilog.info(DOMAIN, TAG, `Added region: ${create.name}, tiles: ${tileCount}`);

    return region;
  }

  /**
   * 移除区域
   */
  async removeRegion(regionId: string): Promise<void> {
    const region = this.regions.get(regionId);
    if (!region) {
      throw new Error('区域不存在');
    }

    // 停止下载
    if (region.status === RegionStatus.DOWNLOADING) {
      await this.pauseDownload(regionId);
    }

    // 删除文件
    await this.deleteRegionFiles(regionId);

    // 删除瓦片索引
    for (const [key, tile] of this.tileIndex.entries()) {
      if (tile.regionId === regionId) {
        this.tileIndex.delete(key);
      }
    }

    // 删除区域
    this.regions.delete(regionId);
    await this.saveRegions();

    hilog.info(DOMAIN, TAG, `Removed region: ${regionId}`);
  }

  /**
   * 重命名区域
   */
  async renameRegion(regionId: string, newName: string): Promise<void> {
    const region = this.regions.get(regionId);
    if (!region) {
      throw new Error('区域不存在');
    }

    region.name = newName;
    region.updatedAt = Date.now();
    await this.saveRegions();
  }

  // ==================== 下载管理 ====================

  /**
   * 开始下载
   */
  async startDownload(regionId: string): Promise<void> {
    const region = this.regions.get(regionId);
    if (!region) {
      throw new Error('区域不存在');
    }

    if (region.status === RegionStatus.DOWNLOADING) {
      throw new Error('区域正在下载中');
    }

    // 检查存储空间
    const usage = await this.getStorageUsage();
    const requiredSpace = region.totalSize - region.downloadedSize;
    if (usage.availableSpace < requiredSpace) {
      throw new Error('存储空间不足');
    }

    // 更新状态
    region.status = RegionStatus.DOWNLOADING;
    region.updatedAt = Date.now();
    await this.saveRegions();

    // 初始化进度
    const progress: DownloadProgress = {
      regionId,
      totalTiles: region.tileCount,
      downloadedTiles: region.downloadedTiles,
      currentSpeed: 0,
      estimatedTime: 0,
      percent: Math.round((region.downloadedTiles / region.tileCount) * 100)
    };
    this.downloadProgress.set(regionId, progress);

    // 开始下载任务
    this.startDownloadTask(region);

    hilog.info(DOMAIN, TAG, `Started download: ${regionId}`);
  }

  /**
   * 暂停下载
   */
  async pauseDownload(regionId: string): Promise<void> {
    const region = this.regions.get(regionId);
    if (!region) {
      throw new Error('区域不存在');
    }

    if (region.status !== RegionStatus.DOWNLOADING) {
      throw new Error('区域未在下载中');
    }

    // 更新状态
    region.status = RegionStatus.PAUSED;
    region.updatedAt = Date.now();
    await this.saveRegions();

    hilog.info(DOMAIN, TAG, `Paused download: ${regionId}`);
  }

  /**
   * 继续下载
   */
  async resumeDownload(regionId: string): Promise<void> {
    const region = this.regions.get(regionId);
    if (!region) {
      throw new Error('区域不存在');
    }

    if (region.status !== RegionStatus.PAUSED) {
      throw new Error('区域未暂停');
    }

    await this.startDownload(regionId);
  }

  /**
   * 获取下载进度
   */
  getDownloadProgress(regionId: string): DownloadProgress | undefined {
    return this.downloadProgress.get(regionId);
  }

  /**
   * 设置下载回调
   */
  setDownloadCallback(regionId: string, callback: (progress: DownloadProgress) => void): void {
    this.downloadCallbacks.set(regionId, callback);
  }

  /**
   * 移除下载回调
   */
  removeDownloadCallback(regionId: string): void {
    this.downloadCallbacks.delete(regionId);
  }

  // ==================== 地图查询 ====================

  /**
   * 检查是否有离线瓦片
   */
  async hasOfflineTile(z: number, x: number, y: number, type: TileType = TileType.VECTOR): Promise<boolean> {
    const key = `${z}/${x}/${y}/${type}`;
    const tile = this.tileIndex.get(key);
    return tile?.downloaded ?? false;
  }

  /**
   * 获取离线瓦片路径
   */
  getOfflineTilePath(regionId: string, z: number, x: number, y: number, type: TileType): string {
    const ext = type === TileType.VECTOR ? 'pbf' : 'png';
    return `/offline-maps/${regionId}/${type}/${z}/${x}/${y}.${ext}`;
  }

  /**
   * 获取包含指定坐标的区域
   */
  getRegionsContainingCoordinate(coord: Coordinate): OfflineRegion[] {
    const regions: OfflineRegion[] = [];

    for (const region of this.regions.values()) {
      if (region.status !== RegionStatus.COMPLETED) continue;

      const { bounds } = region;
      if (coord.latitude >= bounds.minLat && coord.latitude <= bounds.maxLat &&
          coord.longitude >= bounds.minLon && coord.longitude <= bounds.maxLon) {
        regions.push(region);
      }
    }

    return regions;
  }

  // ==================== 存储管理 ====================

  /**
   * 获取存储使用情况
   */
  async getStorageUsage(): Promise<StorageUsage> {
    // 在实际实现中，应该调用系统API获取真实存储信息
    // 这里使用模拟数据

    let mapSpace = 0;
    const regionUsages: StorageUsage['regions'] = [];

    for (const region of this.regions.values()) {
      mapSpace += region.downloadedSize;
      regionUsages.push({
        id: region.id,
        name: region.name,
        size: region.downloadedSize,
        percent: region.downloadedSize > 0
          ? Math.round((region.downloadedSize / region.totalSize) * 100)
          : 0
      });
    }

    // 模拟存储信息
    const totalSpace = 64 * 1024 * 1024 * 1024; // 64GB
    const usedSpace = 20 * 1024 * 1024 * 1024;  // 20GB

    return {
      totalSpace,
      usedSpace,
      mapSpace,
      availableSpace: totalSpace - usedSpace,
      regions: regionUsages
    };
  }

  /**
   * 获取存储配置
   */
  getStorageConfig(): StorageConfig {
    return { ...this.storageConfig };
  }

  /**
   * 更新存储配置
   */
  async updateStorageConfig(config: Partial<StorageConfig>): Promise<void> {
    this.storageConfig = { ...this.storageConfig, ...config };
    await this.saveStorageConfig();
  }

  /**
   * 清理旧数据
   */
  async cleanupOldData(): Promise<{ removedRegions: string[]; freedSpace: number }> {
    const removedRegions: string[] = [];
    let freedSpace = 0;

    const threshold = Date.now() - this.storageConfig.keepRecentDays * 24 * 60 * 60 * 1000;

    for (const [id, region] of this.regions.entries()) {
      if (region.updatedAt < threshold && region.status === RegionStatus.COMPLETED) {
        freedSpace += region.downloadedSize;
        removedRegions.push(id);
        await this.removeRegion(id);
      }
    }

    hilog.info(DOMAIN, TAG, `Cleanup completed: removed ${removedRegions.length} regions, freed ${freedSpace} bytes`);

    return { removedRegions, freedSpace };
  }

  /**
   * 检查更新
   */
  async checkForUpdates(): Promise<{ regionId: string; hasUpdate: boolean }[]> {
    const updates: { regionId: string; hasUpdate: boolean }[] = [];

    for (const region of this.regions.values()) {
      // 在实际实现中，应该检查服务端的地图版本
      // 这里返回模拟结果
      updates.push({
        regionId: region.id,
        hasUpdate: Math.random() > 0.9 // 10%概率有更新
      });
    }

    return updates;
  }

  // ==================== 私有方法 ====================

  /**
   * 生成区域ID
   */
  private generateRegionId(create: OfflineRegionCreate): string {
    const { bounds, zoomRange } = create;
    return `region_${bounds.minLat.toFixed(2)}_${bounds.maxLat.toFixed(2)}_${bounds.minLon.toFixed(2)}_${bounds.maxLon.toFixed(2)}_${zoomRange[0]}_${zoomRange[1]}`;
  }

  /**
   * 计算瓦片数量
   */
  private calculateTileCount(bounds: BoundingBox, zoomRange: [number, number]): number {
    let count = 0;

    for (let z = zoomRange[0]; z <= zoomRange[1]; z++) {
      const minTileX = this.lonToTileX(bounds.minLon, z);
      const maxTileX = this.lonToTileX(bounds.maxLon, z);
      const minTileY = this.latToTileY(bounds.maxLat, z);
      const maxTileY = this.latToTileY(bounds.minLat, z);

      const xCount = maxTileX - minTileX + 1;
      const yCount = maxTileY - minTileY + 1;

      count += xCount * yCount;
    }

    return count;
  }

  /**
   * 经度转瓦片X坐标
   */
  private lonToTileX(lon: number, z: number): number {
    return Math.floor((lon + 180) / 360 * Math.pow(2, z));
  }

  /**
   * 纬度转瓦片Y坐标
   */
  private latToTileY(lat: number, z: number): number {
    const latRad = lat * Math.PI / 180;
    return Math.floor((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2 * Math.pow(2, z));
  }

  /**
   * 开始下载任务
   */
  private async startDownloadTask(region: OfflineRegion): Promise<void> {
    const { bounds, zoomRange } = region;

    // 计算所有需要下载的瓦片
    const tiles: { z: number; x: number; y: number }[] = [];

    for (let z = zoomRange[0]; z <= zoomRange[1]; z++) {
      const minTileX = this.lonToTileX(bounds.minLon, z);
      const maxTileX = this.lonToTileX(bounds.maxLon, z);
      const minTileY = this.latToTileY(bounds.maxLat, z);
      const maxTileY = this.latToTileY(bounds.minLat, z);

      for (let x = minTileX; x <= maxTileX; x++) {
        for (let y = minTileY; y <= maxTileY; y++) {
          tiles.push({ z, x, y });
        }
      }
    }

    // 模拟下载过程
    let downloaded = region.downloadedTiles;
    const total = tiles.length;
    const startTime = Date.now();

    for (let i = downloaded; i < total; i++) {
      // 检查是否暂停
      const currentRegion = this.regions.get(region.id);
      if (currentRegion?.status !== RegionStatus.DOWNLOADING) {
        break;
      }

      const tile = tiles[i];

      // 模拟下载延迟
      await new Promise(resolve => setTimeout(resolve, 10));

      // 更新瓦片索引
      const vectorKey = `${tile.z}/${tile.x}/${tile.y}/${TileType.VECTOR}`;
      const demKey = `${tile.z}/${tile.x}/${tile.y}/${TileType.DEM}`;

      this.tileIndex.set(vectorKey, {
        regionId: region.id,
        z: tile.z,
        x: tile.x,
        y: tile.y,
        type: TileType.VECTOR,
        size: this.TILE_SIZE_APPROX,
        downloaded: true,
        updatedAt: Date.now()
      });

      this.tileIndex.set(demKey, {
        regionId: region.id,
        z: tile.z,
        x: tile.x,
        y: tile.y,
        type: TileType.DEM,
        size: this.TILE_SIZE_APPROX,
        downloaded: true,
        updatedAt: Date.now()
      });

      downloaded++;

      // 更新进度
      const elapsed = (Date.now() - startTime) / 1000;
      const speed = (downloaded - region.downloadedTiles) * this.TILE_SIZE_APPROX / 1024 / (elapsed || 1);
      const remaining = total - downloaded;
      const estimatedTime = speed > 0 ? remaining * this.TILE_SIZE_APPROX / 1024 / speed : 0;

      const progress: DownloadProgress = {
        regionId: region.id,
        totalTiles: total,
        downloadedTiles: downloaded,
        currentSpeed: Math.round(speed * 10) / 10,
        estimatedTime: Math.round(estimatedTime),
        percent: Math.round((downloaded / total) * 100)
      };

      this.downloadProgress.set(region.id, progress);

      // 更新区域
      region.downloadedTiles = downloaded;
      region.downloadedSize = downloaded * this.TILE_SIZE_APPROX * 2;
      region.updatedAt = Date.now();

      // 触发回调
      const callback = this.downloadCallbacks.get(region.id);
      if (callback) {
        callback(progress);
      }

      // 每10个瓦片保存一次
      if (downloaded % 10 === 0) {
        await this.saveRegions();
      }
    }

    // 检查是否完成
    if (downloaded >= total) {
      region.status = RegionStatus.COMPLETED;
      region.downloadedTiles = total;
      region.downloadedSize = total * this.TILE_SIZE_APPROX * 2;
      hilog.info(DOMAIN, TAG, `Download completed: ${region.id}`);
    }

    region.updatedAt = Date.now();
    await this.saveRegions();
  }

  /**
   * 删除区域文件
   */
  private async deleteRegionFiles(regionId: string): Promise<void> {
    // 在实际实现中，应该删除存储目录
    // 这里只是模拟
    hilog.info(DOMAIN, TAG, `Deleted files for region: ${regionId}`);
  }

  /**
   * 加载区域
   */
  private loadRegions(): void {
    // 在实际实现中，应该从数据库加载
    // 这里使用空初始化
    hilog.info(DOMAIN, TAG, 'Regions loaded');
  }

  /**
   * 保存区域
   */
  private async saveRegions(): Promise<void> {
    // 在实际实现中，应该保存到数据库
    hilog.debug(DOMAIN, TAG, 'Regions saved');
  }

  /**
   * 保存存储配置
   */
  private async saveStorageConfig(): Promise<void> {
    // 在实际实现中，应该保存到持久化存储
    hilog.debug(DOMAIN, TAG, 'Storage config saved');
  }
}

// 导出单例
export default OfflineMapService.getInstance();

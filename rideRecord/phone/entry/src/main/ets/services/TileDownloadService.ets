/**
 * 瓦片下载服务
 *
 * 功能说明：
 * - 瓦片坐标计算
 * - 批量下载管理
 * - 下载进度追踪
 * - 错误重试机制
 *
 * SRS引用: FR-003-05
 */
import hilog from '@ohos.hilog';
import { BoundingBox, TileType } from './OfflineMapService';

const TAG = '[TileDownloadService]';
const DOMAIN = 0xFF00;

/**
 * 下载状态
 */
export enum DownloadStatus {
  IDLE = 'idle',
  RUNNING = 'running',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  ERROR = 'error'
}

/**
 * 瓦片下载任务
 */
export interface TileDownloadTask {
  id: string;
  regionId: string;
  tiles: TileCoordinate[];
  currentIndex: number;
  status: DownloadStatus;
  startTime: number;
  endTime?: number;
  errorCount: number;
  lastError?: string;
  stats: DownloadStats;
}

/**
 * 瓦片坐标
 */
export interface TileCoordinate {
  z: number;
  x: number;
  y: number;
}

/**
 * 下载统计
 */
export interface DownloadStats {
  totalTiles: number;
  completedTiles: number;
  failedTiles: number;
  totalBytes: number;
  averageSpeed: number;  // KB/s
  peakSpeed: number;
  duration: number;      // seconds
}

/**
 * 下载配置
 */
export interface DownloadConfig {
  batchSize: number;           // 每批下载数量
  maxRetries: number;          // 最大重试次数
  retryDelay: number;          // 重试延迟 (ms)
  timeout: number;             // 下载超时 (ms)
  concurrentDownloads: number; // 并发下载数
}

/**
 * 默认下载配置
 */
export const DEFAULT_DOWNLOAD_CONFIG: DownloadConfig = {
  batchSize: 50,
  maxRetries: 3,
  retryDelay: 1000,
  timeout: 30000,
  concurrentDownloads: 4
};

/**
 * 瓦片源配置
 */
export interface TileSource {
  type: TileType;
  urlTemplate: string;  // 例如: https://tile.example.com/{z}/{x}/{y}.pbf
  apiKey?: string;
  minZoom: number;
  maxZoom: number;
}

/**
 * 预设瓦片源
 */
export const TILE_SOURCES: Record<TileType, TileSource> = {
  [TileType.VECTOR]: {
    type: TileType.VECTOR,
    urlTemplate: 'https://vector.example.com/{z}/{x}/{y}.pbf',
    minZoom: 0,
    maxZoom: 16
  },
  [TileType.DEM]: {
    type: TileType.DEM,
    urlTemplate: 'https://dem.example.com/{z}/{x}/{y}.png',
    minZoom: 0,
    maxZoom: 14
  }
};

/**
 * 瓦片下载服务
 */
export class TileDownloadService {
  private static instance: TileDownloadService;

  // 下载任务
  private tasks: Map<string, TileDownloadTask> = new Map();
  private currentTask: TileDownloadTask | null = null;

  // 配置
  private config: DownloadConfig = DEFAULT_DOWNLOAD_CONFIG;

  // 回调
  private progressCallback?: (task: TileDownloadTask) => void;
  private errorCallback?: (taskId: string, error: string) => void;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): TileDownloadService {
    if (!TileDownloadService.instance) {
      TileDownloadService.instance = new TileDownloadService();
    }
    return TileDownloadService.instance;
  }

  // ==================== 瓦片坐标计算 ====================

  /**
   * 计算边界框内所有瓦片
   */
  calculateTiles(bounds: BoundingBox, zoomRange: [number, number]): TileCoordinate[] {
    const tiles: TileCoordinate[] = [];

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

    return tiles;
  }

  /**
   * 计算单个瓦片的边界框
   */
  tileToBounds(z: number, x: number, y: number): BoundingBox {
    const n = Math.pow(2, z);

    const minLon = (x / n) * 360 - 180;
    const maxLon = ((x + 1) / n) * 360 - 180;

    const latToRad = (lat: number) => Math.atan(Math.sinh(Math.PI * (1 - 2 * lat / n))) * 180 / Math.PI;

    const minLat = latToRad(y + 1);
    const maxLat = latToRad(y);

    return { minLat, maxLat, minLon, maxLon };
  }

  /**
   * 经度转瓦片X坐标
   */
  lonToTileX(lon: number, z: number): number {
    return Math.floor((lon + 180) / 360 * Math.pow(2, z));
  }

  /**
   * 纬度转瓦片Y坐标
   */
  latToTileY(lat: number, z: number): number {
    const latRad = lat * Math.PI / 180;
    return Math.floor((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2 * Math.pow(2, z));
  }

  /**
   * 计算瓦片数量估算
   */
  estimateTileCount(bounds: BoundingBox, zoomRange: [number, number]): number {
    return this.calculateTiles(bounds, zoomRange).length;
  }

  // ==================== 下载任务管理 ====================

  /**
   * 创建下载任务
   */
  createTask(regionId: string, tiles: TileCoordinate[]): TileDownloadTask {
    const taskId = `task_${regionId}_${Date.now()}`;

    const task: TileDownloadTask = {
      id: taskId,
      regionId,
      tiles,
      currentIndex: 0,
      status: DownloadStatus.IDLE,
      startTime: 0,
      errorCount: 0,
      stats: {
        totalTiles: tiles.length,
        completedTiles: 0,
        failedTiles: 0,
        totalBytes: 0,
        averageSpeed: 0,
        peakSpeed: 0,
        duration: 0
      }
    };

    this.tasks.set(taskId, task);
    hilog.info(DOMAIN, TAG, `Created task: ${taskId}, tiles: ${tiles.length}`);

    return task;
  }

  /**
   * 获取任务
   */
  getTask(taskId: string): TileDownloadTask | undefined {
    return this.tasks.get(taskId);
  }

  /**
   * 获取区域的任务
   */
  getTasksByRegion(regionId: string): TileDownloadTask[] {
    return Array.from(this.tasks.values()).filter(t => t.regionId === regionId);
  }

  /**
   * 开始任务
   */
  async startTask(taskId: string): Promise<void> {
    const task = this.tasks.get(taskId);
    if (!task) {
      throw new Error('任务不存在');
    }

    if (task.status === DownloadStatus.RUNNING) {
      throw new Error('任务已在运行中');
    }

    task.status = DownloadStatus.RUNNING;
    task.startTime = Date.now();
    this.currentTask = task;

    hilog.info(DOMAIN, TAG, `Started task: ${taskId}`);

    // 开始下载
    await this.processTask(task);
  }

  /**
   * 暂停任务
   */
  pauseTask(taskId: string): void {
    const task = this.tasks.get(taskId);
    if (!task) {
      throw new Error('任务不存在');
    }

    if (task.status !== DownloadStatus.RUNNING) {
      throw new Error('任务未在运行中');
    }

    task.status = DownloadStatus.PAUSED;
    this.currentTask = null;

    hilog.info(DOMAIN, TAG, `Paused task: ${taskId}`);
  }

  /**
   * 继续任务
   */
  async resumeTask(taskId: string): Promise<void> {
    const task = this.tasks.get(taskId);
    if (!task) {
      throw new Error('任务不存在');
    }

    if (task.status !== DownloadStatus.PAUSED) {
      throw new Error('任务未暂停');
    }

    await this.startTask(taskId);
  }

  /**
   * 取消任务
   */
  cancelTask(taskId: string): void {
    const task = this.tasks.get(taskId);
    if (!task) {
      throw new Error('任务不存在');
    }

    task.status = DownloadStatus.ERROR;
    task.lastError = '用户取消';
    this.currentTask = null;

    hilog.info(DOMAIN, TAG, `Cancelled task: ${taskId}`);
  }

  /**
   * 删除任务
   */
  deleteTask(taskId: string): void {
    const task = this.tasks.get(taskId);
    if (task?.status === DownloadStatus.RUNNING) {
      this.pauseTask(taskId);
    }

    this.tasks.delete(taskId);
    hilog.info(DOMAIN, TAG, `Deleted task: ${taskId}`);
  }

  // ==================== 下载执行 ====================

  /**
   * 处理下载任务
   */
  private async processTask(task: TileDownloadTask): Promise<void> {
    const { tiles, currentIndex, stats } = task;
    const startTime = Date.now();

    for (let i = currentIndex; i < tiles.length; i++) {
      // 检查状态
      if (task.status !== DownloadStatus.RUNNING) {
        break;
      }

      const tile = tiles[i];

      try {
        // 下载瓦片
        const bytes = await this.downloadTile(tile, TileType.VECTOR);
        stats.completedTiles++;
        stats.totalBytes += bytes;

        // 下载高程数据
        const demBytes = await this.downloadTile(tile, TileType.DEM);
        stats.completedTiles++;
        stats.totalBytes += demBytes;

      } catch (error) {
        stats.failedTiles++;
        task.errorCount++;

        if (task.errorCount > this.config.maxRetries) {
          task.status = DownloadStatus.ERROR;
          task.lastError = `下载失败次数过多: ${error}`;
          break;
        }
      }

      // 更新进度
      task.currentIndex = i + 1;

      // 计算速度
      const elapsed = (Date.now() - startTime) / 1000;
      stats.duration = elapsed;
      stats.averageSpeed = stats.totalBytes / 1024 / (elapsed || 1);

      if (stats.averageSpeed > stats.peakSpeed) {
        stats.peakSpeed = stats.averageSpeed;
      }

      // 触发回调
      if (this.progressCallback) {
        this.progressCallback(task);
      }
    }

    // 检查是否完成
    if (task.currentIndex >= tiles.length) {
      task.status = DownloadStatus.COMPLETED;
      task.endTime = Date.now();
      hilog.info(DOMAIN, TAG, `Task completed: ${task.id}`);
    }

    this.currentTask = null;
  }

  /**
   * 下载单个瓦片
   */
  private async downloadTile(tile: TileCoordinate, type: TileType): Promise<number> {
    // 模拟下载
    // 在实际实现中，应该调用HTTP请求下载瓦片
    await new Promise(resolve => setTimeout(resolve, 5));

    // 返回模拟大小
    return 15 * 1024; // 15KB
  }

  /**
   * 构建瓦片URL
   */
  buildTileUrl(tile: TileCoordinate, type: TileType): string {
    const source = TILE_SOURCES[type];
    return source.urlTemplate
      .replace('{z}', tile.z.toString())
      .replace('{x}', tile.x.toString())
      .replace('{y}', tile.y.toString());
  }

  // ==================== 回调设置 ====================

  /**
   * 设置进度回调
   */
  setProgressCallback(callback: (task: TileDownloadTask) => void): void {
    this.progressCallback = callback;
  }

  /**
   * 设置错误回调
   */
  setErrorCallback(callback: (taskId: string, error: string) => void): void {
    this.errorCallback = callback;
  }

  // ==================== 配置管理 ====================

  /**
   * 获取配置
   */
  getConfig(): DownloadConfig {
    return { ...this.config };
  }

  /**
   * 更新配置
   */
  updateConfig(config: Partial<DownloadConfig>): void {
    this.config = { ...this.config, ...config };
  }

  // ==================== 批量操作 ====================

  /**
   * 批量下载瓦片
   */
  async downloadBatch(
    tiles: TileCoordinate[],
    type: TileType,
    onProgress?: (completed: number, total: number) => void
  ): Promise<{ success: number; failed: number; bytes: number }> {
    let success = 0;
    let failed = 0;
    let bytes = 0;

    for (let i = 0; i < tiles.length; i++) {
      try {
        const tileBytes = await this.downloadTile(tiles[i], type);
        success++;
        bytes += tileBytes;
      } catch (error) {
        failed++;
      }

      if (onProgress && i % 10 === 0) {
        onProgress(i + 1, tiles.length);
      }
    }

    return { success, failed, bytes };
  }

  /**
   * 预计算下载大小
   */
  estimateDownloadSize(tileCount: number): number {
    // 每个瓦片约15KB，同时需要vector和dem两种
    return tileCount * 15 * 1024 * 2;
  }
}

// 导出单例
export default TileDownloadService.getInstance();

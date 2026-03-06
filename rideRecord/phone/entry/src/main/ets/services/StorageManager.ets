/**
 * 存储空间管理服务
 *
 * 功能说明：
 * - 存储空间统计
 * - LRU淘汰策略
 * - 自动清理管理
 * - 存储预警通知
 *
 * SRS引用: FR-003-05
 */
import hilog from '@ohos.hilog';
import { OfflineRegion, RegionStatus } from './OfflineMapService';

const TAG = '[StorageManager]';
const DOMAIN = 0xFF00;

/**
 * 存储项
 */
export interface StorageItem {
  id: string;
  type: 'region' | 'cache' | 'temp';
  name: string;
  size: number;
  lastAccessed: number;
  createdAt: number;
  priority: number;  // 0-100, 越高越重要
}

/**
 * 存储统计
 */
export interface StorageStats {
  totalSpace: number;
  usedSpace: number;
  availableSpace: number;
  mapSpace: number;
  cacheSpace: number;
  tempSpace: number;
  usedPercent: number;
}

/**
 * 清理策略
 */
export enum CleanupStrategy {
  LRU = 'lru',           // 最近最少使用
  FIFO = 'fifo',         // 先进先出
  PRIORITY = 'priority', // 按优先级
  SIZE = 'size'          // 按大小
}

/**
 * 清理结果
 */
export interface CleanupResult {
  freedSpace: number;
  removedItems: string[];
  errors: string[];
}

/**
 * 存储预警级别
 */
export enum StorageWarningLevel {
  NONE = 'none',
  LOW = 'low',           // 可用空间 < 20%
  CRITICAL = 'critical', // 可用空间 < 10%
  FULL = 'full'          // 可用空间 < 5%
}

/**
 * 存储配置
 */
export interface StorageManagerConfig {
  maxStorageMB: number;
  warningThresholdPercent: number;
  criticalThresholdPercent: number;
  autoCleanup: boolean;
  cleanupStrategy: CleanupStrategy;
  minKeepRegions: number;
}

/**
 * 默认配置
 */
export const DEFAULT_STORAGE_CONFIG: StorageManagerConfig = {
  maxStorageMB: 2048,
  warningThresholdPercent: 20,
  criticalThresholdPercent: 10,
  autoCleanup: true,
  cleanupStrategy: CleanupStrategy.LRU,
  minKeepRegions: 1
};

/**
 * 存储管理服务
 */
export class StorageManager {
  private static instance: StorageManager;

  // 存储项
  private items: Map<string, StorageItem> = new Map();

  // 配置
  private config: StorageManagerConfig = DEFAULT_STORAGE_CONFIG;

  // 回调
  private warningCallback?: (level: StorageWarningLevel, stats: StorageStats) => void;

  private constructor() {
    this.loadItems();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): StorageManager {
    if (!StorageManager.instance) {
      StorageManager.instance = new StorageManager();
    }
    return StorageManager.instance;
  }

  // ==================== 存储统计 ====================

  /**
   * 获取存储统计
   */
  async getStorageStats(): Promise<StorageStats> {
    // 计算各类存储占用
    let mapSpace = 0;
    let cacheSpace = 0;
    let tempSpace = 0;

    for (const item of this.items.values()) {
      switch (item.type) {
        case 'region':
          mapSpace += item.size;
          break;
        case 'cache':
          cacheSpace += item.size;
          break;
        case 'temp':
          tempSpace += item.size;
          break;
      }
    }

    // 在实际实现中，应该调用系统API获取真实存储信息
    // 这里使用模拟数据
    const totalSpace = 64 * 1024 * 1024 * 1024; // 64GB
    const otherUsedSpace = 20 * 1024 * 1024 * 1024 - mapSpace - cacheSpace - tempSpace;
    const usedSpace = otherUsedSpace + mapSpace + cacheSpace + tempSpace;
    const availableSpace = totalSpace - usedSpace;

    return {
      totalSpace,
      usedSpace,
      availableSpace,
      mapSpace,
      cacheSpace,
      tempSpace,
      usedPercent: Math.round((usedSpace / totalSpace) * 100)
    };
  }

  /**
   * 获取存储预警级别
   */
  async getWarningLevel(): Promise<StorageWarningLevel> {
    const stats = await this.getStorageStats();
    const availablePercent = (stats.availableSpace / stats.totalSpace) * 100;

    if (availablePercent < 5) {
      return StorageWarningLevel.FULL;
    } else if (availablePercent < 10) {
      return StorageWarningLevel.CRITICAL;
    } else if (availablePercent < 20) {
      return StorageWarningLevel.LOW;
    }

    return StorageWarningLevel.NONE;
  }

  /**
   * 检查存储空间是否足够
   */
  async hasEnoughSpace(requiredBytes: number): Promise<boolean> {
    const stats = await this.getStorageStats();
    return stats.availableSpace >= requiredBytes;
  }

  // ==================== 存储项管理 ====================

  /**
   * 注册存储项
   */
  registerItem(item: StorageItem): void {
    this.items.set(item.id, item);
    this.saveItems();
    hilog.debug(DOMAIN, TAG, `Registered item: ${item.id}, size: ${item.size}`);
  }

  /**
   * 更新存储项
   */
  updateItem(id: string, updates: Partial<StorageItem>): void {
    const item = this.items.get(id);
    if (item) {
      Object.assign(item, updates);
      this.saveItems();
    }
  }

  /**
   * 更新访问时间
   */
  touchItem(id: string): void {
    const item = this.items.get(id);
    if (item) {
      item.lastAccessed = Date.now();
      this.saveItems();
    }
  }

  /**
   * 移除存储项
   */
  removeItem(id: string): void {
    this.items.delete(id);
    this.saveItems();
    hilog.debug(DOMAIN, TAG, `Removed item: ${id}`);
  }

  /**
   * 获取所有存储项
   */
  getItems(): StorageItem[] {
    return Array.from(this.items.values());
  }

  /**
   * 获取指定类型的存储项
   */
  getItemsByType(type: StorageItem['type']): StorageItem[] {
    return this.getItems().filter(item => item.type === type);
  }

  // ==================== 清理操作 ====================

  /**
   * 自动清理
   */
  async autoCleanup(): Promise<CleanupResult> {
    const warningLevel = await this.getWarningLevel();

    if (warningLevel === StorageWarningLevel.NONE) {
      return { freedSpace: 0, removedItems: [], errors: [] };
    }

    // 计算需要释放的空间
    const stats = await this.getStorageStats();
    const targetPercent = this.config.warningThresholdPercent;
    const targetAvailable = stats.totalSpace * targetPercent / 100;
    const neededSpace = targetAvailable - stats.availableSpace;

    if (neededSpace <= 0) {
      return { freedSpace: 0, removedItems: [], errors: [] };
    }

    return this.cleanup(neededSpace);
  }

  /**
   * 清理指定大小的空间
   */
  async cleanup(requiredBytes: number): Promise<CleanupResult> {
    const result: CleanupResult = {
      freedSpace: 0,
      removedItems: [],
      errors: []
    };

    // 根据策略排序
    const sortedItems = this.getSortedItemsForCleanup();

    // 保留最小数量的区域
    const regionItems = sortedItems.filter(i => i.type === 'region');
    const keepCount = Math.min(this.config.minKeepRegions, regionItems.length);

    let freed = 0;
    let removedRegions = 0;

    for (const item of sortedItems) {
      if (freed >= requiredBytes) break;

      // 跳过需要保留的区域
      if (item.type === 'region') {
        if (removedRegions >= regionItems.length - keepCount) {
          continue;
        }
        removedRegions++;
      }

      try {
        // 在实际实现中，应该删除实际文件
        await this.deleteItemFiles(item);

        freed += item.size;
        result.removedItems.push(item.id);
        this.items.delete(item.id);

      } catch (error) {
        result.errors.push(`删除 ${item.name} 失败: ${error}`);
      }
    }

    result.freedSpace = freed;
    this.saveItems();

    hilog.info(DOMAIN, TAG, `Cleanup completed: freed ${freed} bytes, removed ${result.removedItems.length} items`);

    return result;
  }

  /**
   * 清理临时文件
   */
  async cleanupTempFiles(): Promise<CleanupResult> {
    const result: CleanupResult = {
      freedSpace: 0,
      removedItems: [],
      errors: []
    };

    const tempItems = this.getItemsByType('temp');

    for (const item of tempItems) {
      try {
        await this.deleteItemFiles(item);
        result.freedSpace += item.size;
        result.removedItems.push(item.id);
        this.items.delete(item.id);
      } catch (error) {
        result.errors.push(`删除 ${item.name} 失败: ${error}`);
      }
    }

    this.saveItems();
    return result;
  }

  /**
   * 清理缓存
   */
  async cleanupCache(): Promise<CleanupResult> {
    const result: CleanupResult = {
      freedSpace: 0,
      removedItems: [],
      errors: []
    };

    const cacheItems = this.getItemsByType('cache');

    for (const item of cacheItems) {
      try {
        await this.deleteItemFiles(item);
        result.freedSpace += item.size;
        result.removedItems.push(item.id);
        this.items.delete(item.id);
      } catch (error) {
        result.errors.push(`删除 ${item.name} 失败: ${error}`);
      }
    }

    this.saveItems();
    return result;
  }

  /**
   * 获取按清理策略排序的项目
   */
  private getSortedItemsForCleanup(): StorageItem[] {
    const items = Array.from(this.items.values());

    switch (this.config.cleanupStrategy) {
      case CleanupStrategy.LRU:
        return items.sort((a, b) => a.lastAccessed - b.lastAccessed);

      case CleanupStrategy.FIFO:
        return items.sort((a, b) => a.createdAt - b.createdAt);

      case CleanupStrategy.PRIORITY:
        return items.sort((a, b) => a.priority - b.priority);

      case CleanupStrategy.SIZE:
        return items.sort((a, b) => b.size - a.size);

      default:
        return items;
    }
  }

  /**
   * 删除项目文件
   */
  private async deleteItemFiles(item: StorageItem): Promise<void> {
    // 在实际实现中，应该删除存储文件
    // 这里只是模拟
    hilog.debug(DOMAIN, TAG, `Deleted files for item: ${item.id}`);
    await new Promise(resolve => setTimeout(resolve, 10));
  }

  // ==================== 区域同步 ====================

  /**
   * 同步离线区域信息
   */
  syncRegions(regions: OfflineRegion[]): void {
    // 移除不存在的区域
    for (const [id, item] of this.items.entries()) {
      if (item.type === 'region' && !regions.find(r => r.id === id)) {
        this.items.delete(id);
      }
    }

    // 添加或更新区域
    for (const region of regions) {
      this.items.set(region.id, {
        id: region.id,
        type: 'region',
        name: region.name,
        size: region.downloadedSize,
        lastAccessed: region.updatedAt,
        createdAt: region.createdAt,
        priority: 50 // 默认优先级
      });
    }

    this.saveItems();
  }

  // ==================== 配置管理 ====================

  /**
   * 获取配置
   */
  getConfig(): StorageManagerConfig {
    return { ...this.config };
  }

  /**
   * 更新配置
   */
  updateConfig(config: Partial<StorageManagerConfig>): void {
    this.config = { ...this.config, ...config };
    this.saveConfig();
  }

  /**
   * 设置预警回调
   */
  setWarningCallback(callback: (level: StorageWarningLevel, stats: StorageStats) => void): void {
    this.warningCallback = callback;
  }

  /**
   * 检查并触发预警
   */
  async checkAndNotifyWarning(): Promise<void> {
    const level = await this.getWarningLevel();
    if (level !== StorageWarningLevel.NONE && this.warningCallback) {
      const stats = await this.getStorageStats();
      this.warningCallback(level, stats);
    }
  }

  // ==================== 持久化 ====================

  /**
   * 加载存储项
   */
  private loadItems(): void {
    // 在实际实现中，应该从持久化存储加载
    hilog.debug(DOMAIN, TAG, 'Storage items loaded');
  }

  /**
   * 保存存储项
   */
  private saveItems(): void {
    // 在实际实现中，应该保存到持久化存储
    hilog.debug(DOMAIN, TAG, 'Storage items saved');
  }

  /**
   * 保存配置
   */
  private saveConfig(): void {
    // 在实际实现中，应该保存到持久化存储
    hilog.debug(DOMAIN, TAG, 'Config saved');
  }

  // ==================== 工具方法 ====================

  /**
   * 格式化存储大小
   */
  static formatSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    } else {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
    }
  }

  /**
   * 计算使用百分比
   */
  static calculatePercent(used: number, total: number): number {
    return Math.round((used / total) * 100);
  }
}

// 导出单例
export default StorageManager.getInstance();

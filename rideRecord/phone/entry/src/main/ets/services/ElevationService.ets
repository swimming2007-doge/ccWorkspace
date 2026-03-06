/**
 * 高程数据服务
 *
 * 功能说明：
 * - 获取位置的高程数据
 * - 计算坡度
 * - 高程数据缓存
 *
 * SRS引用: FR-003-02
 */
import hilog from '@ohos.hilog';
import { Coordinate } from '../utils/Types';

const TAG = '[ElevationService]';
const DOMAIN = 0xFF00;

/**
 * 高程数据点
 */
export interface ElevationPoint {
  coordinate: Coordinate;
  elevation: number;  // 海拔 (米)
  slope?: number;     // 坡度 (%)
}

/**
 * 高程剖面
 */
export interface ElevationProfile {
  points: ElevationPoint[];
  totalAscent: number;     // 总爬升 (米)
  totalDescent: number;    // 总下降 (米)
  maxElevation: number;    // 最高点
  minElevation: number;    // 最低点
  maxSlope: number;        // 最大坡度 (%)
  avgSlope: number;        // 平均坡度 (%)
  distance: number;        // 总距离 (米)
}

/**
 * 高程数据服务
 */
export class ElevationService {
  private static instance: ElevationService;

  // 高程缓存
  private elevationCache: Map<string, number> = new Map();
  private readonly CACHE_MAX_SIZE = 10000;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): ElevationService {
    if (!ElevationService.instance) {
      ElevationService.instance = new ElevationService();
    }
    return ElevationService.instance;
  }

  /**
   * 获取单点高程
   */
  async getElevation(coordinate: Coordinate): Promise<number> {
    const cacheKey = this.getCacheKey(coordinate);

    // 检查缓存
    const cached = this.elevationCache.get(cacheKey);
    if (cached !== undefined) {
      return cached;
    }

    // 获取高程 (模拟实现)
    const elevation = await this.fetchElevation(coordinate);

    // 缓存结果
    this.cacheElevation(cacheKey, elevation);

    return elevation;
  }

  /**
   * 批量获取高程
   */
  async getElevations(coordinates: Coordinate[]): Promise<ElevationPoint[]> {
    const points: ElevationPoint[] = [];

    for (let i = 0; i < coordinates.length; i++) {
      const elevation = await this.getElevation(coordinates[i]);

      // 计算坡度
      let slope = 0;
      if (i > 0) {
        const prevPoint = points[i - 1];
        const distance = this.calculateDistance(
          prevPoint.coordinate,
          coordinates[i]
        );
        const elevationDiff = elevation - prevPoint.elevation;
        slope = distance > 0 ? (elevationDiff / distance) * 100 : 0;
      }

      points.push({
        coordinate: coordinates[i],
        elevation,
        slope
      });
    }

    return points;
  }

  /**
   * 生成高程剖面
   */
  async generateProfile(coordinates: Coordinate[]): Promise<ElevationProfile> {
    const points = await this.getElevations(coordinates);

    let totalAscent = 0;
    let totalDescent = 0;
    let maxElevation = -Infinity;
    let minElevation = Infinity;
    let maxSlope = 0;
    let totalSlope = 0;
    let totalDistance = 0;

    for (let i = 0; i < points.length; i++) {
      const point = points[i];

      // 更新极值
      if (point.elevation > maxElevation) maxElevation = point.elevation;
      if (point.elevation < minElevation) minElevation = point.elevation;

      // 计算爬升和下降
      if (i > 0) {
        const elevationDiff = point.elevation - points[i - 1].elevation;
        if (elevationDiff > 0) {
          totalAscent += elevationDiff;
        } else {
          totalDescent += Math.abs(elevationDiff);
        }

        // 计算距离
        const distance = this.calculateDistance(
          points[i - 1].coordinate,
          point.coordinate
        );
        totalDistance += distance;

        // 坡度统计
        if (point.slope !== undefined) {
          maxSlope = Math.max(maxSlope, Math.abs(point.slope));
          totalSlope += Math.abs(point.slope);
        }
      }
    }

    return {
      points,
      totalAscent,
      totalDescent,
      maxElevation,
      minElevation,
      maxSlope: Math.round(maxSlope * 10) / 10,
      avgSlope: points.length > 1 ? Math.round((totalSlope / (points.length - 1)) * 10) / 10 : 0,
      distance: totalDistance
    };
  }

  /**
   * 计算两点间坡度
   */
  async calculateSlope(start: Coordinate, end: Coordinate): Promise<number> {
    const [startElevation, endElevation] = await Promise.all([
      this.getElevation(start),
      this.getElevation(end)
    ]);

    const distance = this.calculateDistance(start, end);
    const elevationDiff = endElevation - startElevation;

    return distance > 0 ? (elevationDiff / distance) * 100 : 0;
  }

  /**
   * 获取坡度等级
   */
  getSlopeGrade(slope: number): number {
    const absSlope = Math.abs(slope);
    if (absSlope < 3) return 1;
    if (absSlope < 6) return 2;
    if (absSlope < 10) return 3;
    if (absSlope < 15) return 4;
    return 5;
  }

  /**
   * 获取坡度描述
   */
  getSlopeDescription(slope: number): string {
    const absSlope = Math.abs(slope);
    if (absSlope < 3) return '平路';
    if (absSlope < 6) return '缓坡';
    if (absSlope < 10) return '中等坡度';
    if (absSlope < 15) return '陡坡';
    return '极陡坡';
  }

  // ==================== 私有方法 ====================

  /**
   * 获取高程 (模拟实现)
   */
  private async fetchElevation(coordinate: Coordinate): Promise<number> {
    // 模拟API调用延迟
    await new Promise(resolve => setTimeout(resolve, 50));

    // 在实际实现中，应该调用高程API
    // 例如：华为地图Kit、高德地图API、Google Elevation API
    // 这里返回基于坐标的模拟值
    const baseElevation = 100; // 基础海拔
    const variation = Math.sin(coordinate.latitude * 10) * 50 +
                      Math.cos(coordinate.longitude * 10) * 30;

    return Math.round(baseElevation + variation + Math.random() * 20);
  }

  /**
   * 计算两点间距离
   */
  private calculateDistance(p1: Coordinate, p2: Coordinate): number {
    const R = 6371000;
    const lat1 = p1.latitude * Math.PI / 180;
    const lat2 = p2.latitude * Math.PI / 180;
    const deltaLat = (p2.latitude - p1.latitude) * Math.PI / 180;
    const deltaLon = (p2.longitude - p1.longitude) * Math.PI / 180;

    const a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
      Math.cos(lat1) * Math.cos(lat2) *
      Math.sin(deltaLon / 2) * Math.sin(deltaLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * 生成缓存键
   */
  private getCacheKey(coordinate: Coordinate): string {
    return `${coordinate.latitude.toFixed(5)},${coordinate.longitude.toFixed(5)}`;
  }

  /**
   * 缓存高程数据
   */
  private cacheElevation(key: string, elevation: number): void {
    // 检查缓存大小
    if (this.elevationCache.size >= this.CACHE_MAX_SIZE) {
      // 删除最早的条目
      const firstKey = this.elevationCache.keys().next().value;
      if (firstKey) {
        this.elevationCache.delete(firstKey);
      }
    }

    this.elevationCache.set(key, elevation);
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.elevationCache.clear();
  }

  /**
   * 获取缓存统计
   */
  getCacheStats(): { size: number; maxSize: number } {
    return {
      size: this.elevationCache.size,
      maxSize: this.CACHE_MAX_SIZE
    };
  }
}

// 导出单例
export default ElevationService.getInstance();

/**
 * 信号覆盖数据服务
 *
 * 功能说明：
 * - 获取位置的手机信号覆盖情况
 * - 信号强度估算
 * - 无信号区域预警
 *
 * SRS引用: FR-003-02
 */
import hilog from '@ohos.hilog';
import { Coordinate } from '../utils/Types';

const TAG = '[SignalCoverageService]';
const DOMAIN = 0xFF00;

/**
 * 信号强度等级
 */
export enum SignalLevel {
  EXCELLENT = 'excellent',  // 优秀
  GOOD = 'good',            // 良好
  POOR = 'poor',            // 较差
  WEAK = 'weak',            // 弱
  NONE = 'none'             // 无信号
}

/**
 * 信号类型
 */
export enum SignalType {
  GSM = 'gsm',      // 2G
  WCDMA = 'wcdma',  // 3G
  LTE = 'lte',      // 4G
  NR = 'nr'         // 5G
}

/**
 * 信号信息
 */
export interface SignalInfo {
  level: SignalLevel;
  strength: number;         // 信号强度 (dBm)
  quality: number;          // 信号质量 (%)
  type: SignalType;         // 信号类型
  operator?: string;        // 运营商
  latitude: number;
  longitude: number;
  timestamp: number;
}

/**
 * 信号覆盖数据
 */
export interface SignalCoverage {
  location: Coordinate;
  level: SignalLevel;
  estimatedStrength: number;
  coverage: 'urban' | 'suburban' | 'rural' | 'remote';
  nearestTowerDistance?: number; // 最近基站距离 (米)
  providers: string[];
}

/**
 * 信号预警
 */
export interface SignalWarning {
  location: Coordinate;
  distanceFromStart: number;
  level: SignalLevel;
  message: string;
  severity: 'info' | 'warning' | 'danger';
}

/**
 * 信号强度阈值配置
 */
export const SIGNAL_THRESHOLDS = {
  [SignalLevel.EXCELLENT]: { min: -70, max: -50 },
  [SignalLevel.GOOD]: { min: -85, max: -70 },
  [SignalLevel.POOR]: { min: -100, max: -85 },
  [SignalLevel.WEAK]: { min: -110, max: -100 },
  [SignalLevel.NONE]: { min: -150, max: -110 }
};

/**
 * 信号强度评分
 */
export const SIGNAL_SCORES: Record<SignalLevel, number> = {
  [SignalLevel.EXCELLENT]: 1,
  [SignalLevel.GOOD]: 2,
  [SignalLevel.POOR]: 3,
  [SignalLevel.WEAK]: 4,
  [SignalLevel.NONE]: 5
};

/**
 * 信号覆盖服务
 */
export class SignalCoverageService {
  private static instance: SignalCoverageService;

  // 信号缓存
  private signalCache: Map<string, SignalInfo> = new Map();
  private coverageCache: Map<string, SignalCoverage> = new Map();

  // 配置
  private readonly CACHE_DURATION = 60 * 60 * 1000; // 1小时

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): SignalCoverageService {
    if (!SignalCoverageService.instance) {
      SignalCoverageService.instance = new SignalCoverageService();
    }
    return SignalCoverageService.instance;
  }

  /**
   * 获取当前位置信号信息
   */
  async getSignalInfo(coordinate: Coordinate): Promise<SignalInfo> {
    // 尝试获取实际信号信息
    const actualSignal = await this.getActualSignalStrength();

    if (actualSignal) {
      return {
        ...actualSignal,
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        timestamp: Date.now()
      };
    }

    // 回退到估算
    return this.estimateSignalInfo(coordinate);
  }

  /**
   * 获取信号覆盖情况
   */
  async getSignalCoverage(coordinate: Coordinate): Promise<SignalCoverage> {
    const cacheKey = this.getCacheKey(coordinate);

    // 检查缓存
    const cached = this.coverageCache.get(cacheKey);
    if (cached) {
      return cached;
    }

    // 估算信号覆盖
    const coverage = await this.estimateSignalCoverage(coordinate);

    // 缓存结果
    this.coverageCache.set(cacheKey, coverage);

    return coverage;
  }

  /**
   * 获取路线信号预警
   */
  async getRouteSignalWarnings(
    coordinates: Coordinate[]
  ): Promise<SignalWarning[]> {
    const warnings: SignalWarning[] = [];
    let distance = 0;

    for (let i = 0; i < coordinates.length; i++) {
      const coverage = await this.getSignalCoverage(coordinates[i]);

      if (coverage.level === SignalLevel.NONE || coverage.level === SignalLevel.WEAK) {
        warnings.push({
          location: coordinates[i],
          distanceFromStart: distance,
          level: coverage.level,
          message: coverage.level === SignalLevel.NONE
            ? '前方区域无手机信号'
            : '前方区域信号较弱',
          severity: coverage.level === SignalLevel.NONE ? 'danger' : 'warning'
        });
      }

      // 计算累计距离
      if (i > 0) {
        distance += this.calculateDistance(coordinates[i - 1], coordinates[i]);
      }
    }

    return warnings;
  }

  /**
   * 检查信号是否适合安全骑行
   */
  async isSignalSafeForRide(coordinates: Coordinate[]): Promise<{
    safe: boolean;
    minLevel: SignalLevel;
    warnings: string[];
  }> {
    const warnings: string[] = [];
    let minLevel = SignalLevel.EXCELLENT;

    for (const coord of coordinates) {
      const coverage = await this.getSignalCoverage(coord);

      if (coverage.level === SignalLevel.NONE) {
        warnings.push('路线经过无信号区域');
        minLevel = SignalLevel.NONE;
      } else if (coverage.level === SignalLevel.WEAK && minLevel !== SignalLevel.NONE) {
        warnings.push('路线经过信号弱区域');
        minLevel = SignalLevel.WEAK;
      } else if (coverage.level === SignalLevel.POOR &&
                 minLevel !== SignalLevel.NONE &&
                 minLevel !== SignalLevel.WEAK) {
        minLevel = SignalLevel.POOR;
      }
    }

    return {
      safe: minLevel !== SignalLevel.NONE,
      minLevel,
      warnings: [...new Set(warnings)]
    };
  }

  /**
   * 获取信号评分 (用于冒险指数计算)
   */
  getSignalScore(level: SignalLevel): number {
    return SIGNAL_SCORES[level];
  }

  /**
   * 根据信号强度获取信号等级
   */
  getSignalLevel(strength: number): SignalLevel {
    for (const [level, threshold] of Object.entries(SIGNAL_THRESHOLDS)) {
      if (strength >= threshold.min && strength < threshold.max) {
        return level as SignalLevel;
      }
    }
    return SignalLevel.NONE;
  }

  // ==================== 私有方法 ====================

  /**
   * 获取实际信号强度
   */
  private async getActualSignalStrength(): Promise<Partial<SignalInfo> | null> {
    // 在实际实现中，应该调用系统API获取真实信号信息
    // HarmonyOS: @ohos.telephony.signalInformation
    // 这里返回null以使用估算
    return null;
  }

  /**
   * 估算信号信息
   */
  private async estimateSignalInfo(coordinate: Coordinate): Promise<SignalInfo> {
    const coverage = await this.getSignalCoverage(coordinate);

    // 根据覆盖情况估算信号强度
    let strength = -80; // 默认值

    switch (coverage.level) {
      case SignalLevel.EXCELLENT:
        strength = -60 + Math.random() * 10;
        break;
      case SignalLevel.GOOD:
        strength = -75 + Math.random() * 10;
        break;
      case SignalLevel.POOR:
        strength = -90 + Math.random() * 10;
        break;
      case SignalLevel.WEAK:
        strength = -105 + Math.random() * 5;
        break;
      case SignalLevel.NONE:
        strength = -120;
        break;
    }

    return {
      level: coverage.level,
      strength: Math.round(strength),
      quality: this.calculateQuality(strength),
      type: this.estimateSignalType(coverage.level),
      operator: coverage.providers[0],
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      timestamp: Date.now()
    };
  }

  /**
   * 估算信号覆盖
   */
  private async estimateSignalCoverage(coordinate: Coordinate): Promise<SignalCoverage> {
    // 基于地理位置估算信号覆盖
    // 实际实现应该：
    // 1. 查询运营商基站数据库
    // 2. 使用历史信号数据
    // 3. 结合地形数据

    const coverage = this.estimateCoverageByLocation(coordinate);
    const level = this.estimateLevelByCoverage(coverage);

    return {
      location: coordinate,
      level,
      estimatedStrength: this.getTypicalStrength(level),
      coverage,
      providers: ['中国移动', '中国联通', '中国电信']
    };
  }

  /**
   * 根据位置估算覆盖类型
   */
  private estimateCoverageByLocation(coordinate: Coordinate): 'urban' | 'suburban' | 'rural' | 'remote' {
    // 简化实现：基于经纬度范围估算
    // 实际应该使用地图数据

    // 中国东部沿海地区通常是城市
    if (coordinate.longitude > 115 && coordinate.longitude < 125 &&
        coordinate.latitude > 25 && coordinate.latitude < 40) {
      // 随机模拟，实际应根据POI数据判断
      const rand = Math.random();
      if (rand < 0.6) return 'urban';
      if (rand < 0.85) return 'suburban';
      return 'rural';
    }

    // 西部地区
    if (coordinate.longitude < 105) {
      if (Math.random() < 0.3) return 'rural';
      return 'remote';
    }

    // 中部地区
    return Math.random() < 0.5 ? 'suburban' : 'rural';
  }

  /**
   * 根据覆盖类型估算信号等级
   */
  private estimateLevelByCoverage(coverage: 'urban' | 'suburban' | 'rural' | 'remote'): SignalLevel {
    const levelMap: Record<string, SignalLevel> = {
      'urban': SignalLevel.EXCELLENT,
      'suburban': SignalLevel.GOOD,
      'rural': SignalLevel.POOR,
      'remote': SignalLevel.WEAK
    };

    // 添加一些随机性
    const baseLevel = levelMap[coverage];
    if (Math.random() < 0.1) {
      // 10%概率信号下降一级
      const levels = [SignalLevel.EXCELLENT, SignalLevel.GOOD, SignalLevel.POOR, SignalLevel.WEAK, SignalLevel.NONE];
      const index = levels.indexOf(baseLevel);
      return levels[Math.min(index + 1, levels.length - 1)];
    }

    return baseLevel;
  }

  /**
   * 获取典型信号强度
   */
  private getTypicalStrength(level: SignalLevel): number {
    const strengths: Record<SignalLevel, number> = {
      [SignalLevel.EXCELLENT]: -60,
      [SignalLevel.GOOD]: -75,
      [SignalLevel.POOR]: -90,
      [SignalLevel.WEAK]: -105,
      [SignalLevel.NONE]: -120
    };
    return strengths[level];
  }

  /**
   * 计算信号质量
   */
  private calculateQuality(strength: number): number {
    // 将信号强度转换为质量百分比
    // -50 dBm = 100%, -120 dBm = 0%
    const quality = ((strength + 120) / 70) * 100;
    return Math.max(0, Math.min(100, Math.round(quality)));
  }

  /**
   * 估算信号类型
   */
  private estimateSignalType(level: SignalLevel): SignalType {
    switch (level) {
      case SignalLevel.EXCELLENT:
        return SignalType.NR; // 5G
      case SignalLevel.GOOD:
        return SignalType.LTE; // 4G
      case SignalLevel.POOR:
        return Math.random() > 0.5 ? SignalType.LTE : SignalType.WCDMA;
      case SignalLevel.WEAK:
        return SignalType.WCDMA; // 3G
      case SignalLevel.NONE:
        return SignalType.GSM; // 2G或无
    }
  }

  /**
   * 生成缓存键
   */
  private getCacheKey(coordinate: Coordinate): string {
    // 使用约1km精度的缓存键
    return `${coordinate.latitude.toFixed(3)},${coordinate.longitude.toFixed(3)}`;
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
   * 清除缓存
   */
  clearCache(): void {
    this.signalCache.clear();
    this.coverageCache.clear();
  }
}

// 导出单例
export default SignalCoverageService.getInstance();

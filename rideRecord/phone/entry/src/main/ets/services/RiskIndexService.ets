/**
 * 冒险指数计算服务
 *
 * 功能说明：
 * - 实时计算路线冒险指数 (1-5级)
 * - 集成多因素评估：路面状况、坡度、交通、信号、补给、天气
 * - 支持实时更新和历史分析
 *
 * SRS引用: FR-003-02
 * 公式: 冒险指数 = Σ(因素权重 × 因素评分) / Σ权重
 */
import hilog from '@ohos.hilog';
import { Coordinate } from '../utils/Types';
import { SurfaceType, TrailType } from './TrailDataService';

const TAG = '[RiskIndexService]';
const DOMAIN = 0xFF00;

/**
 * 冒险因素类型
 */
export enum RiskFactorType {
  SURFACE = 'surface',       // 路面状况
  SLOPE = 'slope',           // 坡度
  TRAFFIC = 'traffic',       // 交通流量
  SIGNAL = 'signal',         // 信号覆盖
  SUPPLY = 'supply',         // 补给距离
  WEATHER = 'weather'        // 天气条件
}

/**
 * 冒险因素权重配置
 */
export const RISK_FACTOR_WEIGHTS: Record<RiskFactorType, number> = {
  [RiskFactorType.SURFACE]: 0.25,   // 路面状况
  [RiskFactorType.SLOPE]: 0.20,     // 坡度
  [RiskFactorType.TRAFFIC]: 0.15,   // 交通流量
  [RiskFactorType.SIGNAL]: 0.15,    // 信号覆盖
  [RiskFactorType.SUPPLY]: 0.15,    // 补给距离
  [RiskFactorType.WEATHER]: 0.10    // 天气条件
};

/**
 * 冒险因素评分
 */
export interface RiskFactorScore {
  type: RiskFactorType;
  score: number;           // 评分 1-5
  weight: number;          // 权重
  weightedScore: number;   // 加权评分
  rawValue?: number;       // 原始值
  description?: string;    // 描述
}

/**
 * 冒险指数计算结果
 */
export interface RiskIndexResult {
  overallIndex: number;              // 综合冒险指数 (1-5)
  level: number;                     // 等级 (1-5，四舍五入)
  factors: RiskFactorScore[];         // 各因素评分
  riskLevel: 'low' | 'medium' | 'high'; // 风险等级
  recommendations: string[];         // 建议
  timestamp: number;
}

/**
 * 路面评分配置
 */
export const SURFACE_SCORES: Record<SurfaceType, number> = {
  [SurfaceType.PAVED]: 1,    // 铺装路面 - 低风险
  [SurfaceType.GRAVEL]: 2,   // 碎石路面 - 较低风险
  [SurfaceType.DIRT]: 3,     // 泥土路面 - 中等风险
  [SurfaceType.MIXED]: 3,    // 混合路面 - 中等风险
  [SurfaceType.ROUGH]: 4,    // 崎岖路面 - 较高风险
  [SurfaceType.SAND]: 5      // 沙地 - 高风险
};

/**
 * 坡度评分配置
 */
export const SLOPE_THRESHOLDS = [
  { maxSlope: 5, score: 1, description: '平缓' },
  { maxSlope: 10, score: 2, description: '缓坡' },
  { maxSlope: 15, score: 3, description: '中等坡度' },
  { maxSlope: 20, score: 4, description: '陡坡' },
  { maxSlope: Infinity, score: 5, description: '极陡坡' }
];

/**
 * 交通流量评分
 */
export const TRAFFIC_LEVELS = {
  low: { score: 1, description: '低流量' },
  medium: { score: 2, description: '中等流量' },
  high: { score: 3, description: '高流量' }
};

/**
 * 信号覆盖评分
 */
export const SIGNAL_LEVELS = {
  excellent: { score: 1, description: '信号良好' },
  good: { score: 2, description: '信号一般' },
  poor: { score: 3, description: '信号较弱' },
  weak: { score: 4, description: '信号弱' },
  none: { score: 5, description: '无信号' }
};

/**
 * 补给距离评分
 */
export const SUPPLY_THRESHOLDS = [
  { maxDistance: 1000, score: 1, description: '补给充足 (<1km)' },
  { maxDistance: 5000, score: 2, description: '补给较近 (1-5km)' },
  { maxDistance: 10000, score: 3, description: '补给较远 (5-10km)' },
  { maxDistance: 20000, score: 4, description: '补给远 (10-20km)' },
  { maxDistance: Infinity, score: 5, description: '无补给 (>20km)' }
];

/**
 * 天气评分配置
 */
export const WEATHER_SCORES = {
  sunny: { score: 1, description: '晴天' },
  cloudy: { score: 2, description: '多云' },
  windy: { score: 2, description: '大风' },
  rainy: { score: 4, description: '雨天' },
  foggy: { score: 4, description: '雾天' },
  stormy: { score: 5, description: '恶劣天气' }
};

/**
 * 冒险指数计算服务
 */
export class RiskIndexService {
  private static instance: RiskIndexService;

  // 缓存
  private lastResult: RiskIndexResult | null = null;
  private signalCache: Map<string, number> = new Map();
  private supplyCache: Map<string, number> = new Map();

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): RiskIndexService {
    if (!RiskIndexService.instance) {
      RiskIndexService.instance = new RiskIndexService();
    }
    return RiskIndexService.instance;
  }

  /**
   * 计算综合冒险指数
   */
  calculateRiskIndex(params: {
    surface: SurfaceType;
    slope: number;
    traffic: 'low' | 'medium' | 'high';
    signalLevel: 'excellent' | 'good' | 'poor' | 'weak' | 'none';
    supplyDistance: number;
    weather: 'sunny' | 'cloudy' | 'windy' | 'rainy' | 'foggy' | 'stormy';
  }): RiskIndexResult {
    hilog.debug(DOMAIN, TAG, 'Calculating risk index');

    const factors: RiskFactorScore[] = [];

    // 1. 路面状况评分
    factors.push(this.calculateSurfaceScore(params.surface));

    // 2. 坡度评分
    factors.push(this.calculateSlopeScore(params.slope));

    // 3. 交通流量评分
    factors.push(this.calculateTrafficScore(params.traffic));

    // 4. 信号覆盖评分
    factors.push(this.calculateSignalScore(params.signalLevel));

    // 5. 补给距离评分
    factors.push(this.calculateSupplyScore(params.supplyDistance));

    // 6. 天气评分
    factors.push(this.calculateWeatherScore(params.weather));

    // 计算加权平均
    const totalWeight = factors.reduce((sum, f) => sum + f.weight, 0);
    const weightedSum = factors.reduce((sum, f) => sum + f.weightedScore, 0);
    const overallIndex = weightedSum / totalWeight;

    // 确定风险等级
    const level = Math.round(overallIndex);
    const riskLevel = this.determineRiskLevel(overallIndex);

    // 生成建议
    const recommendations = this.generateRecommendations(factors, overallIndex);

    const result: RiskIndexResult = {
      overallIndex: Math.round(overallIndex * 10) / 10,
      level,
      factors,
      riskLevel,
      recommendations,
      timestamp: Date.now()
    };

    this.lastResult = result;
    hilog.info(DOMAIN, TAG, 'Risk index calculated: %{public}f, level %{public}d', overallIndex, level);

    return result;
  }

  /**
   * 快速计算冒险指数 (仅基于路面和坡度)
   */
  quickCalculate(surface: SurfaceType, slope: number): number {
    const surfaceScore = SURFACE_SCORES[surface] || 1;
    const slopeScore = this.getSlopeScore(slope);

    // 简化计算：路面权重0.6，坡度权重0.4
    return Math.round((surfaceScore * 0.6 + slopeScore * 0.4) * 10) / 10;
  }

  /**
   * 获取上次计算结果
   */
  getLastResult(): RiskIndexResult | null {
    return this.lastResult;
  }

  /**
   * 计算路面状况评分
   */
  private calculateSurfaceScore(surface: SurfaceType): RiskFactorScore {
    const score = SURFACE_SCORES[surface] || 1;
    const weight = RISK_FACTOR_WEIGHTS[RiskFactorType.SURFACE];

    return {
      type: RiskFactorType.SURFACE,
      score,
      weight,
      weightedScore: score * weight,
      rawValue: score,
      description: this.getSurfaceDescription(surface)
    };
  }

  /**
   * 计算坡度评分
   */
  private calculateSlopeScore(slope: number): RiskFactorScore {
    const score = this.getSlopeScore(slope);
    const weight = RISK_FACTOR_WEIGHTS[RiskFactorType.SLOPE];
    const threshold = SLOPE_THRESHOLDS.find(t => slope <= t.maxSlope);

    return {
      type: RiskFactorType.SLOPE,
      score,
      weight,
      weightedScore: score * weight,
      rawValue: slope,
      description: threshold?.description || '未知'
    };
  }

  /**
   * 获取坡度评分
   */
  private getSlopeScore(slope: number): number {
    for (const threshold of SLOPE_THRESHOLDS) {
      if (slope <= threshold.maxSlope) {
        return threshold.score;
      }
    }
    return 5;
  }

  /**
   * 计算交通流量评分
   */
  private calculateTrafficScore(traffic: 'low' | 'medium' | 'high'): RiskFactorScore {
    const level = TRAFFIC_LEVELS[traffic] || TRAFFIC_LEVELS.low;
    const weight = RISK_FACTOR_WEIGHTS[RiskFactorType.TRAFFIC];

    return {
      type: RiskFactorType.TRAFFIC,
      score: level.score,
      weight,
      weightedScore: level.score * weight,
      description: level.description
    };
  }

  /**
   * 计算信号覆盖评分
   */
  private calculateSignalScore(signalLevel: 'excellent' | 'good' | 'poor' | 'weak' | 'none'): RiskFactorScore {
    const level = SIGNAL_LEVELS[signalLevel] || SIGNAL_LEVELS.good;
    const weight = RISK_FACTOR_WEIGHTS[RiskFactorType.SIGNAL];

    return {
      type: RiskFactorType.SIGNAL,
      score: level.score,
      weight,
      weightedScore: level.score * weight,
      description: level.description
    };
  }

  /**
   * 计算补给距离评分
   */
  private calculateSupplyScore(distance: number): RiskFactorScore {
    const threshold = SUPPLY_THRESHOLDS.find(t => distance <= t.maxDistance) || SUPPLY_THRESHOLDS[SUPPLY_THRESHOLDS.length - 1];
    const weight = RISK_FACTOR_WEIGHTS[RiskFactorType.SUPPLY];

    return {
      type: RiskFactorType.SUPPLY,
      score: threshold.score,
      weight,
      weightedScore: threshold.score * weight,
      rawValue: distance,
      description: threshold.description
    };
  }

  /**
   * 计算天气评分
   */
  private calculateWeatherScore(weather: 'sunny' | 'cloudy' | 'windy' | 'rainy' | 'foggy' | 'stormy'): RiskFactorScore {
    const level = WEATHER_SCORES[weather] || WEATHER_SCORES.sunny;
    const weight = RISK_FACTOR_WEIGHTS[RiskFactorType.WEATHER];

    return {
      type: RiskFactorType.WEATHER,
      score: level.score,
      weight,
      weightedScore: level.score * weight,
      description: level.description
    };
  }

  /**
   * 确定风险等级
   */
  private determineRiskLevel(index: number): 'low' | 'medium' | 'high' {
    if (index <= 2.5) {
      return 'low';
    } else if (index <= 3.5) {
      return 'medium';
    } else {
      return 'high';
    }
  }

  /**
   * 生成建议
   */
  private generateRecommendations(factors: RiskFactorScore[], overallIndex: number): string[] {
    const recommendations: string[] = [];

    // 检查各因素
    for (const factor of factors) {
      if (factor.score >= 4) {
        switch (factor.type) {
          case RiskFactorType.SURFACE:
            recommendations.push('路面状况较差，建议减速慢行');
            break;
          case RiskFactorType.SLOPE:
            recommendations.push('坡度较陡，注意控制车速');
            break;
          case RiskFactorType.SIGNAL:
            recommendations.push('前方信号较弱，建议提前告知行程');
            break;
          case RiskFactorType.SUPPLY:
            recommendations.push('补给点较远，建议携带充足饮水');
            break;
          case RiskFactorType.WEATHER:
            recommendations.push('天气条件不佳，建议谨慎骑行');
            break;
        }
      }
    }

    // 综合建议
    if (overallIndex >= 4) {
      recommendations.push('高风险路段，仅限资深骑行者');
    } else if (overallIndex >= 3) {
      recommendations.push('中等风险，需要一定骑行经验');
    }

    return recommendations;
  }

  /**
   * 获取路面描述
   */
  private getSurfaceDescription(surface: SurfaceType): string {
    const descriptions: Record<SurfaceType, string> = {
      [SurfaceType.PAVED]: '铺装路面',
      [SurfaceType.GRAVEL]: '碎石路面',
      [SurfaceType.DIRT]: '泥土路面',
      [SurfaceType.ROUGH]: '崎岖路面',
      [SurfaceType.SAND]: '沙地',
      [SurfaceType.MIXED]: '混合路面'
    };
    return descriptions[surface] || '未知';
  }

  /**
   * 更新信号缓存
   */
  updateSignalCache(coordinate: Coordinate, signalStrength: number): void {
    const key = `${coordinate.latitude.toFixed(4)},${coordinate.longitude.toFixed(4)}`;
    this.signalCache.set(key, signalStrength);
  }

  /**
   * 获取信号强度
   */
  getSignalStrength(coordinate: Coordinate): number {
    const key = `${coordinate.latitude.toFixed(4)},${coordinate.longitude.toFixed(4)}`;
    return this.signalCache.get(key) || 0;
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.signalCache.clear();
    this.supplyCache.clear();
    this.lastResult = null;
  }
}

// 导出单例
export default RiskIndexService.getInstance();

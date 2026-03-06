/**
 * 探险路网数据服务
 *
 * 功能说明：
 * - 获取非公路路网数据 (土路、村道、山地车道、小径)
 * - 路网数据缓存
 * - 离线路网数据支持
 *
 * SRS引用: FR-003-02
 */
import hilog from '@ohos.hilog';
import { Coordinate, BoundingBox } from '../utils/Types';

const TAG = '[TrailDataService]';
const DOMAIN = 0xFF00;

/**
 * 路线类型
 */
export enum TrailType {
  ROAD = 'road',           // 公路
  VILLAGE = 'village',     // 村道
  DIRT = 'dirt',           // 土路
  TRAIL = 'trail',         // 山地车道
  PATH = 'path'            // 小径
}

/**
 * 路面类型
 */
export enum SurfaceType {
  PAVED = 'paved',         // 铺装路面
  GRAVEL = 'gravel',       // 碎石路面
  DIRT = 'dirt',           // 泥土路面
  ROUGH = 'rough',         // 崎岖路面
  SAND = 'sand',           // 沙地
  MIXED = 'mixed'          // 混合路面
}

/**
 * 路况预警类型
 */
export enum RoadWarningType {
  STEEP_UPHILL = 'steep_uphill',       // 陡坡上坡
  STEEP_DOWNHILL = 'steep_downhill',   // 陡坡下坡
  ROUGH_SURFACE = 'rough_surface',     // 崎岖路面
  WATER_CROSSING = 'water_crossing',   // 涉水路段
  LOW_SIGNAL = 'low_signal',           // 信号弱
  NO_SERVICE = 'no_service',           // 无补给点
  NARROW_PATH = 'narrow_path',         // 窄路
  TRAFFIC = 'traffic',                 // 交通注意
  ANIMALS = 'animals',                 // 动物出没
  GATE = 'gate'                        // 门/障碍
}

/**
 * 路况预警
 */
export interface RoadWarning {
  type: RoadWarningType;
  location: Coordinate;
  distanceFromStart: number;  // 距起点的距离 (米)
  severity: 'info' | 'warning' | 'danger';
  message: string;
  description?: string;
}

/**
 * 探险路段
 */
export interface AdventureSegment {
  id: string;
  name?: string;
  type: TrailType;
  surface: SurfaceType;
  distance: number;           // 距离 (米)
  elevationGain: number;      // 爬升 (米)
  elevationLoss: number;      // 下降 (米)
  maxSlope: number;           // 最大坡度 (%)
  avgSlope: number;           // 平均坡度 (%)
  slopeGrade: number;         // 坡度等级 (1-5)
  adventureIndex: number;     // 冒险指数 (1-5)
  difficulty: 'easy' | 'moderate' | 'hard' | 'expert';
  warnings: RoadWarning[];
  coordinates: Coordinate[];
  osmId?: string;             // OpenStreetMap ID
  lastUpdated: number;
}

/**
 * 探险路网数据
 */
export interface TrailNetwork {
  segments: AdventureSegment[];
  totalDistance: number;
  bounds: BoundingBox;
  lastUpdated: number;
}

/**
 * 探险路网查询选项
 */
export interface TrailQueryOptions {
  types?: TrailType[];
  minDistance?: number;
  maxDistance?: number;
  maxAdventureIndex?: number;
  includeWarnings?: boolean;
}

/**
 * 探险路网数据服务
 */
export class TrailDataService {
  private static instance: TrailDataService;

  // 路网数据缓存
  private trailCache: Map<string, AdventureSegment> = new Map();
  private networkCache: Map<string, TrailNetwork> = new Map();
  private lastFetchTime: number = 0;

  // 配置
  private readonly CACHE_DURATION = 24 * 60 * 60 * 1000; // 24小时
  private readonly MAX_CACHE_SIZE = 1000; // 最大缓存路段数

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): TrailDataService {
    if (!TrailDataService.instance) {
      TrailDataService.instance = new TrailDataService();
    }
    return TrailDataService.instance;
  }

  /**
   * 获取区域内的探险路网
   */
  async getTrailsInBounds(
    bounds: BoundingBox,
    options?: TrailQueryOptions
  ): Promise<AdventureSegment[]> {
    hilog.info(DOMAIN, TAG, 'Getting trails in bounds: %{public}s', JSON.stringify(bounds));

    // 检查缓存
    const cacheKey = this.getBoundsKey(bounds);
    const cached = this.networkCache.get(cacheKey);

    if (cached && Date.now() - cached.lastUpdated < this.CACHE_DURATION) {
      hilog.info(DOMAIN, TAG, 'Using cached trail data');
      return this.filterSegments(cached.segments, options);
    }

    // 在实际实现中，这里应该调用地图API或本地数据库
    // 目前返回模拟数据
    const segments = await this.mockFetchTrailsInBounds(bounds, options);

    // 更新缓存
    this.networkCache.set(cacheKey, {
      segments,
      totalDistance: segments.reduce((sum, s) => sum + s.distance, 0),
      bounds,
      lastUpdated: Date.now()
    });

    return segments;
  }

  /**
   * 获取路段详情
   */
  async getTrailDetails(trailId: string): Promise<AdventureSegment | null> {
    // 先检查缓存
    const cached = this.trailCache.get(trailId);
    if (cached) {
      return cached;
    }

    // 模拟获取路段详情
    const segment = await this.mockGetTrailDetails(trailId);
    if (segment) {
      this.trailCache.set(trailId, segment);
    }

    return segment;
  }

  /**
   * 获取指定类型的路段
   */
  async getTrailsByType(
    bounds: BoundingBox,
    type: TrailType
  ): Promise<AdventureSegment[]> {
    const allTrails = await this.getTrailsInBounds(bounds);
    return allTrails.filter(trail => trail.type === type);
  }

  /**
   * 获取路段上的路况预警
   */
  async getTrailWarnings(trailId: string): Promise<RoadWarning[]> {
    const segment = await this.getTrailDetails(trailId);
    return segment?.warnings || [];
  }

  /**
   * 缓存路网数据到本地
   */
  async cacheTrailData(bounds: BoundingBox): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Caching trail data for offline use');

    const segments = await this.getTrailsInBounds(bounds);

    // 在实际实现中，这里应该将数据保存到本地存储
    // 例如使用 @ohos.data.relationalStore

    hilog.info(DOMAIN, TAG, 'Cached %{public}d trail segments', segments.length);
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.trailCache.clear();
    this.networkCache.clear();
    hilog.info(DOMAIN, TAG, 'Trail cache cleared');
  }

  /**
   * 获取缓存统计
   */
  getCacheStats(): { segmentCount: number; networkCount: number } {
    return {
      segmentCount: this.trailCache.size,
      networkCount: this.networkCache.size
    };
  }

  // ==================== 私有方法 ====================

  /**
   * 过滤路段
   */
  private filterSegments(
    segments: AdventureSegment[],
    options?: TrailQueryOptions
  ): AdventureSegment[] {
    if (!options) return segments;

    let filtered = segments;

    if (options.types && options.types.length > 0) {
      filtered = filtered.filter(s => options.types!.includes(s.type));
    }

    if (options.minDistance !== undefined) {
      filtered = filtered.filter(s => s.distance >= options.minDistance!);
    }

    if (options.maxDistance !== undefined) {
      filtered = filtered.filter(s => s.distance <= options.maxDistance!);
    }

    if (options.maxAdventureIndex !== undefined) {
      filtered = filtered.filter(s => s.adventureIndex <= options.maxAdventureIndex!);
    }

    return filtered;
  }

  /**
   * 生成边界框缓存键
   */
  private getBoundsKey(bounds: BoundingBox): string {
    return `${bounds.minLat.toFixed(2)}_${bounds.maxLat.toFixed(2)}_${bounds.minLng.toFixed(2)}_${bounds.maxLng.toFixed(2)}`;
  }

  /**
   * 模拟获取区域内的探险路网
   */
  private async mockFetchTrailsInBounds(
    bounds: BoundingBox,
    options?: TrailQueryOptions
  ): Promise<AdventureSegment[]> {
    // 模拟网络延迟
    await new Promise(resolve => setTimeout(resolve, 300));

    const segments: AdventureSegment[] = [];
    const centerLat = (bounds.minLat + bounds.maxLat) / 2;
    const centerLng = (bounds.minLng + bounds.maxLng) / 2;

    // 生成模拟探险路段
    const trailTypes = [TrailType.VILLAGE, TrailType.DIRT, TrailType.TRAIL, TrailType.PATH];
    const surfaces = [SurfaceType.GRAVEL, SurfaceType.DIRT, SurfaceType.ROUGH, SurfaceType.MIXED];
    const difficulties: Array<'easy' | 'moderate' | 'hard' | 'expert'> = ['easy', 'moderate', 'hard', 'expert'];

    for (let i = 0; i < 5; i++) {
      const type = trailTypes[Math.floor(Math.random() * trailTypes.length)];
      const adventureIndex = Math.floor(Math.random() * 5) + 1;

      // 生成路段坐标
      const coordinates: Coordinate[] = [];
      const pointCount = 10 + Math.floor(Math.random() * 20);
      const baseLat = centerLat + (Math.random() - 0.5) * 0.02;
      const baseLng = centerLng + (Math.random() - 0.5) * 0.02;

      for (let j = 0; j < pointCount; j++) {
        coordinates.push({
          latitude: baseLat + Math.random() * 0.005 * (j % 2 === 0 ? 1 : -1),
          longitude: baseLng + Math.random() * 0.005 * (j % 2 === 0 ? 1 : -1),
          altitude: 100 + Math.random() * 50
        });
      }

      // 生成路况预警
      const warnings: RoadWarning[] = [];
      if (adventureIndex >= 3) {
        warnings.push({
          type: RoadWarningType.ROUGH_SURFACE,
          location: coordinates[Math.floor(coordinates.length / 2)],
          distanceFromStart: 500 + Math.random() * 500,
          severity: adventureIndex >= 4 ? 'warning' : 'info',
          message: '前方崎岖路面，请小心骑行'
        });
      }
      if (Math.random() > 0.7) {
        warnings.push({
          type: RoadWarningType.LOW_SIGNAL,
          location: coordinates[Math.floor(coordinates.length * 0.7)],
          distanceFromStart: 800 + Math.random() * 400,
          severity: 'info',
          message: '前方手机信号较弱'
        });
      }

      const segment: AdventureSegment = {
        id: `trail-${Date.now()}-${i}`,
        name: this.getTrailName(type, i),
        type,
        surface: surfaces[Math.floor(Math.random() * surfaces.length)],
        distance: 500 + Math.random() * 2000,
        elevationGain: 20 + Math.random() * 100,
        elevationLoss: 15 + Math.random() * 80,
        maxSlope: 5 + Math.random() * 15,
        avgSlope: 2 + Math.random() * 8,
        slopeGrade: Math.floor(Math.random() * 5) + 1,
        adventureIndex,
        difficulty: difficulties[Math.min(adventureIndex - 1, 3)],
        warnings,
        coordinates,
        lastUpdated: Date.now()
      };

      segments.push(segment);
    }

    return segments;
  }

  /**
   * 模拟获取路段详情
   */
  private async mockGetTrailDetails(trailId: string): Promise<AdventureSegment | null> {
    await new Promise(resolve => setTimeout(resolve, 100));

    // 返回一个简单的模拟路段
    return {
      id: trailId,
      name: '探险路段',
      type: TrailType.TRAIL,
      surface: SurfaceType.DIRT,
      distance: 1500,
      elevationGain: 50,
      elevationLoss: 30,
      maxSlope: 12,
      avgSlope: 5,
      slopeGrade: 3,
      adventureIndex: 3,
      difficulty: 'moderate',
      warnings: [],
      coordinates: [],
      lastUpdated: Date.now()
    };
  }

  /**
   * 获取路段名称
   */
  private getTrailName(type: TrailType, index: number): string {
    const names: Record<TrailType, string[]> = {
      [TrailType.ROAD]: ['公路'],
      [TrailType.VILLAGE]: ['村道A', '村道B', '乡村小路'],
      [TrailType.DIRT]: ['土路', '砂石路', '乡间土路'],
      [TrailType.TRAIL]: ['山地车道', '越野路线', '林间小道'],
      [TrailType.PATH]: ['自行车小径', '探线路径']
    };

    const typeNames = names[type];
    return typeNames[index % typeNames.length];
  }
}

// 导出单例
export default TrailDataService.getInstance();

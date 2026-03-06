/**
 * 探险导航服务
 *
 * 功能说明：
 * - 扩展公路导航服务，支持探险导航模式
 * - 探险路线规划算法
 * - 混合路线规划算法
 * - 路况预警检测
 * - 冒险指数计算
 *
 * SRS引用: FR-003-02, FR-003-03
 */
import hilog from '@ohos.hilog';
import {
  NavigationService,
  NavigationMode,
  NavigationRoute,
  NavigationOptions,
  Maneuver,
  ManeuverType
} from './NavigationService';
import {
  TrailDataService,
  TrailType,
  SurfaceType,
  RoadWarningType,
  RoadWarning,
  AdventureSegment
} from './TrailDataService';
import { Coordinate } from '../utils/Types';

const TAG = '[AdventureNavigationService]';
const DOMAIN = 0xFF00;

/**
 * 探险导航选项
 */
export interface AdventureNavigationOptions extends NavigationOptions {
  mode: NavigationMode.ADVENTURE | NavigationMode.HYBRID;
  adventureRatio?: number;      // 探险比例 (0-1)，混合模式使用
  maxRiskIndex?: number;        // 最大冒险指数 (1-5)
  preferredSurface?: SurfaceType[];
  avoidSteep?: boolean;         // 避开陡坡
  avoidRough?: boolean;         // 避开崎岖路面
}

/**
 * 探险路线
 */
export interface AdventureRoute extends NavigationRoute {
  adventureSegments: AdventureSegment[];
  totalAdventureDistance: number;  // 探险路段总距离
  totalAdventurePercentage: number; // 探险路段占比
  averageAdventureIndex: number;   // 平均冒险指数
  maxAdventureIndex: number;       // 最大冒险指数
  surfaceTypes: SurfaceType[];     // 路面类型列表
  warnings: RoadWarning[];         // 路况预警列表
  trailTypes: TrailType[];         // 路线类型列表
}

/**
 * 路况预警事件
 */
export interface RoadWarningEvent {
  warning: RoadWarning;
  distance: number;  // 距当前位置的距离 (米)
  announced: boolean; // 是否已播报
}

/**
 * 探险导航状态
 */
export interface AdventureNavigationStatus {
  route: AdventureRoute | null;
  currentSegmentIndex: number;
  currentSegmentType: TrailType;
  currentAdventureIndex: number;
  upcomingWarnings: RoadWarningEvent[];
  distanceToNextWarning: number;
}

/**
 * 探险导航服务类
 */
export class AdventureNavigationService {
  private static instance: AdventureNavigationService;
  private baseNavigationService: NavigationService;
  private trailDataService: TrailDataService;

  // 当前探险路线
  private currentAdventureRoute: AdventureRoute | null = null;
  private currentSegmentIndex: number = 0;
  private lastLocation: Coordinate | null = null;

  // 路况预警
  private warningEvents: RoadWarningEvent[] = [];
  private warningCallbacks: Array<(event: RoadWarningEvent) => void> = [];

  // 配置
  private readonly WARNING_ANNOUNCE_DISTANCE = 200; // 预警播报距离 (米)

  private constructor() {
    this.baseNavigationService = new NavigationService();
    this.trailDataService = TrailDataService.getInstance();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): AdventureNavigationService {
    if (!AdventureNavigationService.instance) {
      AdventureNavigationService.instance = new AdventureNavigationService();
    }
    return AdventureNavigationService.instance;
  }

  /**
   * 规划探险路线
   */
  async planAdventureRoute(
    start: Coordinate,
    end: Coordinate,
    options: AdventureNavigationOptions
  ): Promise<AdventureRoute | null> {
    hilog.info(DOMAIN, TAG, 'Planning adventure route from %{public}f,%{public}f to %{public}f,%{public}f',
      start.latitude, start.longitude, end.latitude, end.longitude);

    try {
      // 获取区域内的探险路网
      const bounds = this.calculateBounds(start, end, 0.05); // 5km 边距
      const trailSegments = await this.trailDataService.getTrailsInBounds(bounds);

      // 根据模式选择规划策略
      let route: AdventureRoute | null = null;

      if (options.mode === NavigationMode.ADVENTURE) {
        route = await this.planPureAdventureRoute(start, end, trailSegments, options);
      } else if (options.mode === NavigationMode.HYBRID) {
        route = await this.planHybridRoute(start, end, trailSegments, options);
      }

      if (route) {
        this.currentAdventureRoute = route;
        this.currentSegmentIndex = 0;
        this.collectWarnings(route);
        hilog.info(DOMAIN, TAG, 'Adventure route planned: %{public}d segments, adventure index %{public}d',
          route.adventureSegments.length, route.averageAdventureIndex);
      }

      return route;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Adventure route planning failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 规划纯探险路线
   */
  private async planPureAdventureRoute(
    start: Coordinate,
    end: Coordinate,
    trailSegments: AdventureSegment[],
    options: AdventureNavigationOptions
  ): Promise<AdventureRoute> {
    // 筛选符合要求的探险路段
    let filteredSegments = trailSegments;

    if (options.maxRiskIndex) {
      filteredSegments = filteredSegments.filter(s => s.adventureIndex <= options.maxRiskIndex!);
    }

    if (options.avoidSteep) {
      filteredSegments = filteredSegments.filter(s => s.slopeGrade < 4);
    }

    if (options.avoidRough) {
      filteredSegments = filteredSegments.filter(s => s.surface !== SurfaceType.ROUGH);
    }

    // 构建路线
    const routeSegments = this.buildRouteFromSegments(start, end, filteredSegments);

    return this.createAdventureRoute(routeSegments, start, end, options);
  }

  /**
   * 规划混合路线
   */
  private async planHybridRoute(
    start: Coordinate,
    end: Coordinate,
    trailSegments: AdventureSegment[],
    options: AdventureNavigationOptions
  ): Promise<AdventureRoute> {
    const adventureRatio = options.adventureRatio || 0.3; // 默认30%探险路段

    // 计算总距离
    const directDistance = this.calculateDirectDistance(start, end);
    const targetAdventureDistance = directDistance * adventureRatio;

    // 选择探险路段
    const selectedAdventureSegments: AdventureSegment[] = [];
    let accumulatedDistance = 0;

    for (const segment of trailSegments) {
      if (accumulatedDistance >= targetAdventureDistance) break;
      if (options.maxRiskIndex && segment.adventureIndex > options.maxRiskIndex) continue;

      selectedAdventureSegments.push(segment);
      accumulatedDistance += segment.distance;
    }

    // 构建混合路线
    const routeSegments = this.buildHybridRouteSegments(start, end, selectedAdventureSegments);

    return this.createAdventureRoute(routeSegments, start, end, options);
  }

  /**
   * 创建探险路线对象
   */
  private createAdventureRoute(
    segments: AdventureSegment[],
    start: Coordinate,
    end: Coordinate,
    options: AdventureNavigationOptions
  ): AdventureRoute {
    const totalDistance = segments.reduce((sum, s) => sum + s.distance, 0);
    const adventureDistance = segments
      .filter(s => s.type !== TrailType.ROAD)
      .reduce((sum, s) => sum + s.distance, 0);

    // 计算平均冒险指数
    const adventureSegments = segments.filter(s => s.type !== TrailType.ROAD);
    const avgIndex = adventureSegments.length > 0
      ? adventureSegments.reduce((sum, s) => sum + s.adventureIndex, 0) / adventureSegments.length
      : 1;

    // 收集所有预警
    const allWarnings: RoadWarning[] = [];
    for (const segment of segments) {
      allWarnings.push(...segment.warnings);
    }

    // 生成转向指令
    const maneuvers = this.generateManeuvers(segments);

    // 生成路线点
    const points = this.generateRoutePoints(segments);

    return {
      id: `adv-${Date.now().toString(36)}`,
      name: this.generateRouteName(options.mode, adventureSegments.length),
      mode: options.mode,
      distance: totalDistance,
      duration: this.estimateDuration(segments),
      points,
      maneuvers,
      startPoint: start,
      endPoint: end,
      viaPoints: [],
      elevationGain: segments.reduce((sum, s) => sum + s.elevationGain, 0),
      adventureIndex: Math.round(avgIndex * 10) / 10,
      adventureSegments: segments,
      totalAdventureDistance: adventureDistance,
      totalAdventurePercentage: totalDistance > 0 ? (adventureDistance / totalDistance) * 100 : 0,
      averageAdventureIndex: Math.round(avgIndex * 10) / 10,
      maxAdventureIndex: Math.max(...segments.map(s => s.adventureIndex), 1),
      surfaceTypes: [...new Set(segments.map(s => s.surface))],
      warnings: allWarnings,
      trailTypes: [...new Set(segments.map(s => s.type))]
    };
  }

  /**
   * 更新当前位置
   */
  updateLocation(coordinate: Coordinate, speed: number): void {
    this.lastLocation = coordinate;

    if (!this.currentAdventureRoute) return;

    // 查找当前路段
    this.currentSegmentIndex = this.findCurrentSegmentIndex(coordinate);

    // 检查路况预警
    this.checkWarnings(coordinate, speed);
  }

  /**
   * 获取前方路况预警
   */
  getUpcomingWarnings(distance: number = 1000): RoadWarningEvent[] {
    if (!this.lastLocation || !this.currentAdventureRoute) return [];

    return this.warningEvents
      .filter(event => event.distance <= distance && event.distance > 0)
      .sort((a, b) => a.distance - b.distance);
  }

  /**
   * 获取当前导航状态
   */
  getStatus(): AdventureNavigationStatus {
    const route = this.currentAdventureRoute;
    const segment = route?.adventureSegments[this.currentSegmentIndex];

    return {
      route,
      currentSegmentIndex: this.currentSegmentIndex,
      currentSegmentType: segment?.type || TrailType.ROAD,
      currentAdventureIndex: segment?.adventureIndex || 1,
      upcomingWarnings: this.getUpcomingWarnings(1000),
      distanceToNextWarning: this.warningEvents[0]?.distance || -1
    };
  }

  /**
   * 注册路况预警回调
   */
  onRoadWarning(callback: (event: RoadWarningEvent) => void): void {
    this.warningCallbacks.push(callback);
  }

  /**
   * 获取探险路线
   */
  getCurrentRoute(): AdventureRoute | null {
    return this.currentAdventureRoute;
  }

  /**
   * 停止导航
   */
  stopNavigation(): void {
    this.currentAdventureRoute = null;
    this.currentSegmentIndex = 0;
    this.lastLocation = null;
    this.warningEvents = [];
    hilog.info(DOMAIN, TAG, 'Adventure navigation stopped');
  }

  // ==================== 私有方法 ====================

  /**
   * 计算边界框
   */
  private calculateBounds(p1: Coordinate, p2: Coordinate, padding: number): {
    minLat: number; maxLat: number; minLng: number; maxLng: number;
  } {
    return {
      minLat: Math.min(p1.latitude, p2.latitude) - padding,
      maxLat: Math.max(p1.latitude, p2.latitude) + padding,
      minLng: Math.min(p1.longitude, p2.longitude) - padding,
      maxLng: Math.max(p1.longitude, p2.longitude) + padding
    };
  }

  /**
   * 计算直线距离
   */
  private calculateDirectDistance(p1: Coordinate, p2: Coordinate): number {
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
   * 从路段构建路线
   */
  private buildRouteFromSegments(
    start: Coordinate,
    end: Coordinate,
    segments: AdventureSegment[]
  ): AdventureSegment[] {
    // 在实际实现中，这里应该使用图算法找到最优路径
    // 目前返回简化的路段列表
    return segments.slice(0, 3);
  }

  /**
   * 构建混合路线路段
   */
  private buildHybridRouteSegments(
    start: Coordinate,
    end: Coordinate,
    adventureSegments: AdventureSegment[]
  ): AdventureSegment[] {
    const result: AdventureSegment[] = [];

    // 添加公路路段（起点到第一个探险路段）
    result.push({
      id: 'road-start',
      type: TrailType.ROAD,
      surface: SurfaceType.PAVED,
      distance: 500,
      elevationGain: 10,
      elevationLoss: 5,
      maxSlope: 3,
      avgSlope: 1,
      slopeGrade: 1,
      adventureIndex: 1,
      difficulty: 'easy',
      warnings: [],
      coordinates: [start],
      lastUpdated: Date.now()
    });

    // 添加探险路段
    result.push(...adventureSegments);

    // 添加公路路段（最后一个探险路段到终点）
    result.push({
      id: 'road-end',
      type: TrailType.ROAD,
      surface: SurfaceType.PAVED,
      distance: 500,
      elevationGain: 10,
      elevationLoss: 5,
      maxSlope: 3,
      avgSlope: 1,
      slopeGrade: 1,
      adventureIndex: 1,
      difficulty: 'easy',
      warnings: [],
      coordinates: [end],
      lastUpdated: Date.now()
    });

    return result;
  }

  /**
   * 生成转向指令
   */
  private generateManeuvers(segments: AdventureSegment[]): Maneuver[] {
    const maneuvers: Maneuver[] = [];
    let distance = 0;

    for (let i = 0; i < segments.length; i++) {
      const segment = segments[i];

      // 进入路段的指令
      if (i === 0) {
        maneuvers.push({
          type: ManeuverType.DEPART,
          distance: 0,
          duration: 0,
          instruction: '出发，进入探险路线',
          coordinate: segment.coordinates[0]
        });
      } else {
        const prevType = segments[i - 1].type;
        const instruction = this.getTransitionInstruction(prevType, segment.type);

        maneuvers.push({
          type: ManeuverType.STRAIGHT,
          distance,
          duration: distance / 5, // 假设5m/s
          instruction,
          coordinate: segment.coordinates[0]
        });
      }

      distance += segment.distance;
    }

    // 到达指令
    const lastSegment = segments[segments.length - 1];
    maneuvers.push({
      type: ManeuverType.ARRIVE,
      distance,
      duration: distance / 5,
      instruction: '到达目的地',
      coordinate: lastSegment.coordinates[lastSegment.coordinates.length - 1]
    });

    return maneuvers;
  }

  /**
   * 获取路段转换指令
   */
  private getTransitionInstruction(fromType: TrailType, toType: TrailType): string {
    const typeNames: Record<TrailType, string> = {
      [TrailType.ROAD]: '公路',
      [TrailType.VILLAGE]: '村道',
      [TrailType.DIRT]: '土路',
      [TrailType.TRAIL]: '山地车道',
      [TrailType.PATH]: '小径'
    };

    if (fromType === TrailType.ROAD && toType !== TrailType.ROAD) {
      return `进入${typeNames[toType]}，注意路况变化`;
    } else if (fromType !== TrailType.ROAD && toType === TrailType.ROAD) {
      return `返回${typeNames[toType]}`;
    } else {
      return `继续进入${typeNames[toType]}`;
    }
  }

  /**
   * 生成路线点
   */
  private generateRoutePoints(segments: AdventureSegment[]): any[] {
    const points: any[] = [];
    let distance = 0;

    for (const segment of segments) {
      for (const coord of segment.coordinates) {
        points.push({
          coordinate: coord,
          distance,
          duration: distance / 5
        });
        distance += 10; // 假设每个点间隔10米
      }
    }

    return points;
  }

  /**
   * 估算行程时间
   */
  private estimateDuration(segments: AdventureSegment[]): number {
    // 根据路段类型和距离估算时间
    let duration = 0;

    for (const segment of segments) {
      let speed = 8; // 默认速度 m/s (~29 km/h)

      switch (segment.type) {
        case TrailType.ROAD:
          speed = 10;
          break;
        case TrailType.VILLAGE:
          speed = 7;
          break;
        case TrailType.DIRT:
          speed = 5;
          break;
        case TrailType.TRAIL:
          speed = 4;
          break;
        case TrailType.PATH:
          speed = 3;
          break;
      }

      // 根据坡度调整
      if (segment.avgSlope > 5) {
        speed *= 0.7;
      }

      duration += segment.distance / speed;
    }

    return duration;
  }

  /**
   * 生成路线名称
   */
  private generateRouteName(mode: NavigationMode, adventureCount: number): string {
    if (mode === NavigationMode.ADVENTURE) {
      return `探险路线 (${adventureCount}个探险路段)`;
    } else {
      return `混合路线 (${adventureCount}个探险路段)`;
    }
  }

  /**
   * 收集路况预警
   */
  private collectWarnings(route: AdventureRoute): void {
    this.warningEvents = [];

    for (const warning of route.warnings) {
      this.warningEvents.push({
        warning,
        distance: warning.distanceFromStart,
        announced: false
      });
    }

    // 按距离排序
    this.warningEvents.sort((a, b) => a.distance - b.distance);
  }

  /**
   * 检查路况预警
   */
  private checkWarnings(coordinate: Coordinate, speed: number): void {
    if (!this.currentAdventureRoute) return;

    // 计算当前位置距起点的距离
    const currentDistance = this.calculateCurrentDistance(coordinate);

    for (const event of this.warningEvents) {
      const distanceToWarning = event.distance - currentDistance;

      // 在预警距离内且未播报
      if (distanceToWarning > 0 && distanceToWarning < this.WARNING_ANNOUNCE_DISTANCE && !event.announced) {
        event.announced = true;

        // 通知回调
        for (const callback of this.warningCallbacks) {
          callback({
            ...event,
            distance: distanceToWarning
          });
        }

        hilog.info(DOMAIN, TAG, 'Warning announced: %{public}s', event.warning.message);
      }
    }
  }

  /**
   * 计算当前位置距起点的距离
   */
  private calculateCurrentDistance(coordinate: Coordinate): number {
    if (!this.currentAdventureRoute) return 0;

    let distance = 0;
    for (let i = 0; i < this.currentSegmentIndex; i++) {
      distance += this.currentAdventureRoute.adventureSegments[i].distance;
    }

    return distance;
  }

  /**
   * 查找当前路段索引
   */
  private findCurrentSegmentIndex(coordinate: Coordinate): number {
    if (!this.currentAdventureRoute) return 0;

    // 简化实现：返回当前索引
    return Math.min(this.currentSegmentIndex, this.currentAdventureRoute.adventureSegments.length - 1);
  }
}

// 导出单例
export default AdventureNavigationService.getInstance();

/**
 * 导航服务
 *
 * 功能说明：
 * - 路线规划 (公路模式)
 * - 导航状态管理
 * - 语音提示控制
 * - 路线偏离检测和重算
 * - 剩余距离/时间计算
 *
 * 技术栈：
 * - 地图SDK集成 (华为地图/高德地图)
 * - 路线规划API
 */
import hilog from '@ohos.hilog';
import { Coordinate } from '../utils/Types';

const TAG = '[NavigationService]';
const DOMAIN = 0xFF00;

// 导航模式
export enum NavigationMode {
  ROAD = 'road',           // 公路模式
  ADVENTURE = 'adventure', // 探险模式
  HYBRID = 'hybrid'        // 混合模式
}

// 导航状态
export enum NavigationState {
  IDLE = 'IDLE',           // 空闲
  PLANNING = 'PLANNING',   // 规划中
  READY = 'READY',         // 准备就绪
  NAVIGATING = 'NAVIGATING', // 导航中
  PAUSED = 'PAUSED',       // 已暂停
  ARRIVED = 'ARRIVED',     // 已到达
  ERROR = 'ERROR'          // 错误
}

// 转向类型
export enum ManeuverType {
  TURN_LEFT = 'TURN_LEFT',
  TURN_RIGHT = 'TURN_RIGHT',
  TURN_SLIGHT_LEFT = 'TURN_SLIGHT_LEFT',
  TURN_SLIGHT_RIGHT = 'TURN_SLIGHT_RIGHT',
  TURN_SHARP_LEFT = 'TURN_SHARP_LEFT',
  TURN_SHARP_RIGHT = 'TURN_SHARP_RIGHT',
  STRAIGHT = 'STRAIGHT',
  U_TURN = 'U_TURN',
  MERGE_LEFT = 'MERGE_LEFT',
  MERGE_RIGHT = 'MERGE_RIGHT',
  ROUNDABOUT = 'ROUNDABOUT',
  EXIT = 'EXIT',
  ARRIVE = 'ARRIVE',
  DEPART = 'DEPART'
}

// 转向指令
export interface Maneuver {
  type: ManeuverType;
  distance: number;        // 距离 (米)
  duration: number;        // 时长 (秒)
  instruction: string;     // 指令文本
  roadName?: string;       // 道路名称
  coordinate: Coordinate;  // 转向点坐标
}

// 路线点
export interface RoutePoint {
  coordinate: Coordinate;
  distance: number;        // 距起点的累计距离
  duration: number;        // 预计用时
  maneuver?: Maneuver;     // 转向指令
}

// 导航路线
export interface NavigationRoute {
  id: string;
  name: string;
  mode: NavigationMode;
  distance: number;        // 总距离 (米)
  duration: number;        // 预计时间 (秒)
  points: RoutePoint[];    // 路线点
  maneuvers: Maneuver[];    // 转向指令列表
  startPoint: Coordinate;
  endPoint: Coordinate;
  viaPoints: Coordinate[]; // 途经点
  elevationGain: number;   // 累计爬升
  adventureIndex?: number; // 冒险指数 (探险模式)
}

// 导航状态
export interface NavigationStatus {
  state: NavigationState;
  route: NavigationRoute | null;
  currentPointIndex: number;
  nextManeuver: Maneuver | null;
  distanceToNextManeuver: number;
  remainingDistance: number;
  remainingDuration: number;
  currentSpeed: number;
  estimatedArrival: Date;
  offRoute: boolean;
  distanceOffRoute: number;
}

// 导航选项
export interface NavigationOptions {
  mode: NavigationMode;
  avoidTolls?: boolean;
  avoidHighways?: boolean;
  avoidFerries?: boolean;
  adventureRatio?: number; // 探险比例 (0-1)
  maxRiskIndex?: number;   // 最大冒险指数
}

// 导航回调
export type NavigationStatusCallback = (status: NavigationStatus) => void;
export type ManeuverCallback = (maneuver: Maneuver) => void;
export type OffRouteCallback = (distance: number) => void;

/**
 * 导航服务类
 */
export class NavigationService {
  // 导航状态
  private state: NavigationState = NavigationState.IDLE;
  private currentRoute: NavigationRoute | null = null;
  private currentPointIndex: number = 0;
  private lastLocation: Coordinate | null = null;

  // 配置
  private readonly OFF_ROUTE_THRESHOLD = 50; // 偏离阈值 (米)
  private readonly REROUTE_THRESHOLD = 100;  // 重算阈值 (米)

  // 回调
  private statusCallbacks: NavigationStatusCallback[] = [];
  private maneuverCallbacks: ManeuverCallback[] = [];
  private offRouteCallbacks: OffRouteCallback[] = [];

  // 语音提示
  private voiceEnabled: boolean = true;
  private lastAnnouncedManeuver: number = -1;

  /**
   * 规划路线
   */
  async planRoute(
    start: Coordinate,
    end: Coordinate,
    options: NavigationOptions
  ): Promise<NavigationRoute | null> {
    hilog.info(DOMAIN, TAG, 'Planning route from %{public}f,%{public}f to %{public}f,%{public}f',
      start.latitude, start.longitude, end.latitude, end.longitude);

    this.state = NavigationState.PLANNING;
    this.notifyStatusCallbacks();

    try {
      // 在实际实现中，这里应该调用地图SDK的路线规划API
      // 目前返回模拟数据
      const route = await this.mockPlanRoute(start, end, options);

      if (route) {
        this.currentRoute = route;
        this.state = NavigationState.READY;
        this.currentPointIndex = 0;
        hilog.info(DOMAIN, TAG, 'Route planned: %{public}d points, %{public}d km',
          route.points.length, Math.round(route.distance / 1000));
      }

      this.notifyStatusCallbacks();
      return route;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Route planning failed: %{public}s', JSON.stringify(error));
      this.state = NavigationState.ERROR;
      this.notifyStatusCallbacks();
      return null;
    }
  }

  /**
   * 开始导航
   */
  startNavigation(): void {
    if (!this.currentRoute) {
      hilog.warn(DOMAIN, TAG, 'No route available');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting navigation');
    this.state = NavigationState.NAVIGATING;
    this.currentPointIndex = 0;
    this.lastAnnouncedManeuver = -1;
    this.notifyStatusCallbacks();
  }

  /**
   * 暂停导航
   */
  pauseNavigation(): void {
    if (this.state !== NavigationState.NAVIGATING) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Pausing navigation');
    this.state = NavigationState.PAUSED;
    this.notifyStatusCallbacks();
  }

  /**
   * 恢复导航
   */
  resumeNavigation(): void {
    if (this.state !== NavigationState.PAUSED) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Resuming navigation');
    this.state = NavigationState.NAVIGATING;
    this.notifyStatusCallbacks();
  }

  /**
   * 停止导航
   */
  stopNavigation(): void {
    hilog.info(DOMAIN, TAG, 'Stopping navigation');
    this.state = NavigationState.IDLE;
    this.currentRoute = null;
    this.currentPointIndex = 0;
    this.lastLocation = null;
    this.notifyStatusCallbacks();
  }

  /**
   * 更新当前位置
   */
  updateLocation(coordinate: Coordinate, speed: number): void {
    if (this.state !== NavigationState.NAVIGATING || !this.currentRoute) {
      return;
    }

    this.lastLocation = coordinate;

    // 计算当前路线点索引
    this.currentPointIndex = this.findClosestPointIndex(coordinate);

    // 检查是否偏离路线
    const offRoute = this.checkOffRoute(coordinate);

    // 获取下一个转向指令
    const nextManeuver = this.getNextManeuver();
    const distanceToManeuver = this.getDistanceToNextManeuver(coordinate);

    // 语音提示
    if (nextManeuver && distanceToManeuver < 100 && this.voiceEnabled) {
      this.announceManeuver(nextManeuver, distanceToManeuver);
    }

    // 检查是否到达
    const remainingDistance = this.getRemainingDistance();
    if (remainingDistance < 20) {
      this.state = NavigationState.ARRIVED;
      hilog.info(DOMAIN, TAG, 'Arrived at destination');
    }

    this.notifyStatusCallbacks();
  }

  /**
   * 获取当前状态
   */
  getStatus(): NavigationStatus {
    const route = this.currentRoute;
    const nextManeuver = route ? this.getNextManeuver() : null;

    return {
      state: this.state,
      route: route,
      currentPointIndex: this.currentPointIndex,
      nextManeuver: nextManeuver,
      distanceToNextManeuver: route ? this.getDistanceToNextManeuver(this.lastLocation!) : 0,
      remainingDistance: route ? this.getRemainingDistance() : 0,
      remainingDuration: route ? this.getRemainingDuration() : 0,
      currentSpeed: 0,
      estimatedArrival: new Date(Date.now() + (route ? this.getRemainingDuration() * 1000 : 0)),
      offRoute: this.lastLocation ? this.checkOffRoute(this.lastLocation) : false,
      distanceOffRoute: 0
    };
  }

  /**
   * 获取当前路线
   */
  getCurrentRoute(): NavigationRoute | null {
    return this.currentRoute;
  }

  /**
   * 设置语音提示
   */
  setVoiceEnabled(enabled: boolean): void {
    this.voiceEnabled = enabled;
    hilog.info(DOMAIN, TAG, 'Voice enabled: %{public}s', enabled);
  }

  /**
   * 注册状态回调
   */
  onStatusChange(callback: NavigationStatusCallback): void {
    this.statusCallbacks.push(callback);
  }

  /**
   * 注册转向回调
   */
  onManeuver(callback: ManeuverCallback): void {
    this.maneuverCallbacks.push(callback);
  }

  /**
   * 注册偏离回调
   */
  onOffRoute(callback: OffRouteCallback): void {
    this.offRouteCallbacks.push(callback);
  }

  // ==================== 私有方法 ====================

  /**
   * 模拟路线规划
   */
  private async mockPlanRoute(
    start: Coordinate,
    end: Coordinate,
    options: NavigationOptions
  ): Promise<NavigationRoute> {
    // 生成模拟路线点
    const points: RoutePoint[] = [];
    const maneuvers: Maneuver[] = [];

    // 简单模拟：从起点到终点的直线插值
    const totalDistance = this.calculateDistance(start, end);
    const pointCount = Math.max(10, Math.floor(totalDistance / 100));

    for (let i = 0; i <= pointCount; i++) {
      const ratio = i / pointCount;
      const lat = start.latitude + (end.latitude - start.latitude) * ratio;
      const lon = start.longitude + (end.longitude - start.longitude) * ratio;

      points.push({
        coordinate: { latitude: lat, longitude: lon },
        distance: totalDistance * ratio,
        duration: (totalDistance / 1000 / 25 * 3600) * ratio // 假设25km/h
      });
    }

    // 生成模拟转向指令
    const maneuverTypes = [
      ManeuverType.DEPART,
      ManeuverType.TURN_RIGHT,
      ManeuverType.STRAIGHT,
      ManeuverType.TURN_LEFT,
      ManeuverType.ARRIVE
    ];

    const maneuverInterval = Math.floor(pointCount / 4);
    for (let i = 0; i < 5; i++) {
      const pointIndex = i * maneuverInterval;
      if (pointIndex < points.length) {
        maneuvers.push({
          type: maneuverTypes[i],
          distance: points[pointIndex].distance,
          duration: points[pointIndex].duration,
          instruction: this.getManeuverInstruction(maneuverTypes[i]),
          coordinate: points[pointIndex].coordinate
        });
      }
    }

    return {
      id: Date.now().toString(36),
      name: `骑行路线`,
      mode: options.mode,
      distance: totalDistance,
      duration: totalDistance / 1000 / 25 * 3600,
      points,
      maneuvers,
      startPoint: start,
      endPoint: end,
      viaPoints: [],
      elevationGain: totalDistance * 0.02 // 模拟2%的爬升
    };
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
   * 查找最近的路线点
   */
  private findClosestPointIndex(coordinate: Coordinate): number {
    if (!this.currentRoute) return 0;

    let minDistance = Infinity;
    let closestIndex = this.currentPointIndex;

    // 从当前点开始搜索
    for (let i = this.currentPointIndex; i < this.currentRoute.points.length; i++) {
      const distance = this.calculateDistance(coordinate, this.currentRoute.points[i].coordinate);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /**
   * 检查是否偏离路线
   */
  private checkOffRoute(coordinate: Coordinate): boolean {
    if (!this.currentRoute) return false;

    const closestDistance = this.calculateDistance(
      coordinate,
      this.currentRoute.points[this.currentPointIndex].coordinate
    );

    return closestDistance > this.OFF_ROUTE_THRESHOLD;
  }

  /**
   * 获取下一个转向指令
   */
  private getNextManeuver(): Maneuver | null {
    if (!this.currentRoute) return null;

    for (const maneuver of this.currentRoute.maneuvers) {
      if (maneuver.distance > this.currentRoute.points[this.currentPointIndex].distance) {
        return maneuver;
      }
    }

    return null;
  }

  /**
   * 获取到下一个转向点的距离
   */
  private getDistanceToNextManeuver(coordinate: Coordinate): number {
    const nextManeuver = this.getNextManeuver();
    if (!nextManeuver || !this.currentRoute) return 0;

    return Math.max(0, nextManeuver.distance - this.currentRoute.points[this.currentPointIndex].distance);
  }

  /**
   * 获取剩余距离
   */
  private getRemainingDistance(): number {
    if (!this.currentRoute) return 0;
    return this.currentRoute.distance - this.currentRoute.points[this.currentPointIndex].distance;
  }

  /**
   * 获取剩余时间
   */
  private getRemainingDuration(): number {
    if (!this.currentRoute) return 0;
    return this.currentRoute.duration - this.currentRoute.points[this.currentPointIndex].duration;
  }

  /**
   * 获取转向指令文本
   */
  private getManeuverInstruction(type: ManeuverType): string {
    const instructions: Record<ManeuverType, string> = {
      [ManeuverType.TURN_LEFT]: '左转',
      [ManeuverType.TURN_RIGHT]: '右转',
      [ManeuverType.TURN_SLIGHT_LEFT]: '稍向左转',
      [ManeuverType.TURN_SLIGHT_RIGHT]: '稍向右转',
      [ManeuverType.TURN_SHARP_LEFT]: '急左转',
      [ManeuverType.TURN_SHARP_RIGHT]: '急右转',
      [ManeuverType.STRAIGHT]: '直行',
      [ManeuverType.U_TURN]: '掉头',
      [ManeuverType.MERGE_LEFT]: '向左并入',
      [ManeuverType.MERGE_RIGHT]: '向右并入',
      [ManeuverType.ROUNDABOUT]: '进入环岛',
      [ManeuverType.EXIT]: '驶出',
      [ManeuverType.ARRIVE]: '到达目的地',
      [ManeuverType.DEPART]: '出发'
    };
    return instructions[type] || '继续';
  }

  /**
   * 语音播报转向
   */
  private announceManeuver(maneuver: Maneuver, distance: number): void {
    const maneuverIndex = this.currentRoute?.maneuvers.indexOf(maneuver) ?? -1;
    if (maneuverIndex === this.lastAnnouncedManeuver) {
      return;
    }

    this.lastAnnouncedManeuver = maneuverIndex;

    let announcement = '';
    if (distance < 50) {
      announcement = `${maneuver.instruction}`;
    } else if (distance < 200) {
      announcement = `前方${Math.round(distance)}米${maneuver.instruction}`;
    } else {
      announcement = `${Math.round(distance)}米后${maneuver.instruction}`;
    }

    hilog.info(DOMAIN, TAG, 'Announce: %{public}s', announcement);

    // 通知回调
    for (const callback of this.maneuverCallbacks) {
      callback(maneuver);
    }
  }

  /**
   * 通知状态回调
   */
  private notifyStatusCallbacks(): void {
    const status = this.getStatus();
    for (const callback of this.statusCallbacks) {
      callback(status);
    }
  }
}

// 导出单例
export default new NavigationService();

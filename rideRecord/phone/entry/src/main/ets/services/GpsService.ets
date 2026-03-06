/**
 * 手机端 GPS 服务
 *
 * 功能说明：
 * - GPS定位数据采集
 * - 轨迹点记录
 * - GPS信号状态监测
 * - 轨迹平滑处理
 *
 * 技术栈：
 * - @ohos.geoLocationManager 定位API
 */
import geoLocationManager from '@ohos.geoLocationManager';
import hilog from '@ohos.hilog';
import { Coordinate, TrackPoint } from '../utils/Types';

const TAG = '[GpsService]';
const DOMAIN = 0xFF00;

// GPS配置
const GPS_UPDATE_INTERVAL = 1; // 1秒
const GPS_DISTANCE_INTERVAL = 0; // 不限制距离
const MIN_ACCURACY = 50; // 最小精度要求 (米)
const MAX_SIGNAL_LOST_TIME = 30000; // 最大信号丢失时间 (30秒)

/**
 * GPS信号状态
 */
export enum GpsSignalState {
  EXCELLENT = 'EXCELLENT',   // 精度 < 5米
  GOOD = 'GOOD',             // 精度 < 10米
  FAIR = 'FAIR',             // 精度 < 20米
  POOR = 'POOR',             // 精度 < 50米
  LOST = 'LOST'              // 信号丢失
}

/**
 * GPS配置选项
 */
export interface GpsConfig {
  interval?: number;         // 更新间隔 (秒)
  distanceInterval?: number; // 距离间隔 (米)
  minAccuracy?: number;      // 最小精度 (米)
}

/**
 * GPS数据回调
 */
export type GpsDataCallback = (location: TrackPoint) => void;
export type SignalStateCallback = (state: GpsSignalState) => void;

/**
 * 手机端 GPS 服务类
 */
export class GpsService {
  private isRunning: boolean = false;
  private locationCallbackId: number | null = null;
  private lastLocation: TrackPoint | null = null;
  private lastValidTime: number = 0;
  private signalState: GpsSignalState = GpsSignalState.LOST;

  // 回调
  private locationCallbacks: GpsDataCallback[] = [];
  private signalCallbacks: SignalStateCallback[] = [];

  // 轨迹点缓存
  private trackPoints: TrackPoint[] = [];
  private maxCacheSize: number = 3600; // 约1小时数据

  // 信号丢失检测
  private signalCheckTimer: number = -1;

  /**
   * 启动GPS服务
   */
  async start(config?: GpsConfig): Promise<void> {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'GPS service is already running');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting GPS service');

    try {
      // 请求定位权限（需要在前端处理）

      // 创建定位请求
      const requestInfo: geoLocationManager.LocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.NAVIGATION,
        timeInterval: config?.interval ?? GPS_UPDATE_INTERVAL,
        distanceInterval: config?.distanceInterval ?? GPS_DISTANCE_INTERVAL
      };

      // 注册位置变化回调
      this.locationCallbackId = geoLocationManager.on('locationChange', requestInfo, (location) => {
        this.onLocationReceived(location);
      });

      // 启动信号检测
      this.startSignalCheck();

      this.isRunning = true;
      hilog.info(DOMAIN, TAG, 'GPS service started');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start GPS: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 停止GPS服务
   */
  async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Stopping GPS service');

    try {
      // 停止位置监听
      if (this.locationCallbackId !== null) {
        geoLocationManager.off('locationChange', this.locationCallbackId);
        this.locationCallbackId = null;
      }

      // 停止信号检测
      this.stopSignalCheck();

      this.isRunning = false;
      hilog.info(DOMAIN, TAG, 'GPS service stopped');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to stop GPS: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 获取最后已知位置
   */
  getLastLocation(): TrackPoint | null {
    return this.lastLocation;
  }

  /**
   * 获取GPS信号状态
   */
  getSignalState(): GpsSignalState {
    return this.signalState;
  }

  /**
   * 获取轨迹点缓存
   */
  getTrackPoints(): TrackPoint[] {
    return [...this.trackPoints];
  }

  /**
   * 清空轨迹点缓存
   */
  clearTrackPoints(): void {
    this.trackPoints = [];
  }

  /**
   * 注册位置回调
   */
  onLocation(callback: GpsDataCallback): void {
    this.locationCallbacks.push(callback);
  }

  /**
   * 注册信号状态回调
   */
  onSignalState(callback: SignalStateCallback): void {
    this.signalCallbacks.push(callback);
  }

  /**
   * 获取运行状态
   */
  isServiceRunning(): boolean {
    return this.isRunning;
  }

  // ==================== 私有方法 ====================

  /**
   * 位置数据接收处理
   */
  private onLocationReceived(location: geoLocationManager.Location): void {
    const now = Date.now();

    // 检查精度
    const accuracy = location.accuracy ?? 999;
    if (accuracy > MIN_ACCURACY) {
      hilog.debug(DOMAIN, TAG, 'Low accuracy: %{public}f, skipping', accuracy);
      return;
    }

    // 创建轨迹点
    const trackPoint: TrackPoint = {
      coordinate: {
        latitude: location.latitude,
        longitude: location.longitude,
        altitude: location.altitude,
        accuracy: location.accuracy,
        timestamp: now
      },
      timestamp: now,
      speed: (location.speed ?? 0) * 3.6, // m/s -> km/h
      heartRate: 0, // 由外部填充
      elevation: location.altitude ?? 0,
      distance: 0 // 由外部计算
    };

    // 计算距离增量
    if (this.lastLocation) {
      trackPoint.distance = this.calculateDistance(
        this.lastLocation.coordinate,
        trackPoint.coordinate
      );
    }

    // 更新状态
    this.lastLocation = trackPoint;
    this.lastValidTime = now;

    // 更新信号状态
    this.updateSignalState(accuracy);

    // 缓存轨迹点
    this.cacheTrackPoint(trackPoint);

    // 通知回调
    this.notifyLocationCallbacks(trackPoint);

    hilog.debug(DOMAIN, TAG, 'Location: lat=%{public}f, lon=%{public}f, acc=%{public}f',
      location.latitude, location.longitude, accuracy);
  }

  /**
   * 计算两点间距离 (Haversine公式)
   */
  private calculateDistance(p1: Coordinate, p2: Coordinate): number {
    const R = 6371000; // 地球半径 (米)

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
   * 更新信号状态
   */
  private updateSignalState(accuracy: number): void {
    let newState: GpsSignalState;

    if (accuracy < 5) {
      newState = GpsSignalState.EXCELLENT;
    } else if (accuracy < 10) {
      newState = GpsSignalState.GOOD;
    } else if (accuracy < 20) {
      newState = GpsSignalState.FAIR;
    } else {
      newState = GpsSignalState.POOR;
    }

    if (newState !== this.signalState) {
      this.signalState = newState;
      this.notifySignalCallbacks(newState);
    }
  }

  /**
   * 启动信号检测
   */
  private startSignalCheck(): void {
    this.signalCheckTimer = setInterval(() => {
      const now = Date.now();
      const timeSinceLastValid = now - this.lastValidTime;

      if (timeSinceLastValid > MAX_SIGNAL_LOST_TIME) {
        if (this.signalState !== GpsSignalState.LOST) {
          this.signalState = GpsSignalState.LOST;
          this.notifySignalCallbacks(GpsSignalState.LOST);
          hilog.warn(DOMAIN, TAG, 'GPS signal lost');
        }
      }
    }, 5000);
  }

  /**
   * 停止信号检测
   */
  private stopSignalCheck(): void {
    if (this.signalCheckTimer !== -1) {
      clearInterval(this.signalCheckTimer);
      this.signalCheckTimer = -1;
    }
  }

  /**
   * 缓存轨迹点
   */
  private cacheTrackPoint(point: TrackPoint): void {
    this.trackPoints.push(point);

    // 限制缓存大小
    if (this.trackPoints.length > this.maxCacheSize) {
      this.trackPoints.shift();
    }
  }

  /**
   * 通知位置回调
   */
  private notifyLocationCallbacks(location: TrackPoint): void {
    for (const callback of this.locationCallbacks) {
      try {
        callback(location);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Callback error: %{public}s', JSON.stringify(error));
      }
    }
  }

  /**
   * 通知信号状态回调
   */
  private notifySignalCallbacks(state: GpsSignalState): void {
    for (const callback of this.signalCallbacks) {
      try {
        callback(state);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Signal callback error: %{public}s', JSON.stringify(error));
      }
    }
  }
}

// 导出单例
export default new GpsService();

/**
 * 手表端 GPS 服务
 *
 * 功能说明：
 * - GPS定位数据采集 (手表端)
 * - 低功耗定位策略
 * - GPS数据预处理
 * - 与手机端数据同步
 *
 * 技术栈：
 * - @ohos.geoLocationManager 定位API
 */
import geoLocationManager from '@ohos.geoLocationManager';
import hilog from '@ohos.hilog';
import { Coordinate, TrackPoint } from '../utils/Types';

const TAG = '[GpsService]';
const DOMAIN = 0xFF00;

// GPS配置 - 手表端更注重功耗
const GPS_UPDATE_INTERVAL = 2; // 2秒 (比手机端更慢，省电)
const MAX_ACCURACY_THRESHOLD = 100; // 最大精度阈值 (米)
const STATIONARY_SPEED_THRESHOLD = 1; // 静止速度阈值 (m/s)

/**
 * GPS信号状态
 */
export enum GpsSignalState {
  GOOD = 'GOOD',
  FAIR = 'FAIR',
  POOR = 'POOR',
  LOST = 'LOST'
}

/**
 * GPS数据回调
 */
export type GpsDataCallback = (trackPoint: TrackPoint) => void;

/**
 * 手表端 GPS 服务类
 */
export class GpsService {
  private isRunning: boolean = false;
  private locationCallbackId: number | null = null;
  private lastLocation: TrackPoint | null = null;
  private signalState: GpsSignalState = GpsSignalState.LOST;
  private lastValidTime: number = 0;

  // 回调
  private locationCallbacks: GpsDataCallback[] = [];

  // 省电模式
  private powerSaveMode: boolean = false;
  private stationaryCount: number = 0;

  /**
   * 启动GPS服务
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'GPS service is already running');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting GPS service (watch)');

    try {
      const requestInfo: geoLocationManager.LocationRequest = {
        priority: this.powerSaveMode
          ? geoLocationManager.LocationRequestPriority.LOW_POWER
          : geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.NAVIGATION,
        timeInterval: GPS_UPDATE_INTERVAL,
        distanceInterval: 0
      };

      this.locationCallbackId = geoLocationManager.on('locationChange', requestInfo, (location) => {
        this.onLocationReceived(location);
      });

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
      if (this.locationCallbackId !== null) {
        geoLocationManager.off('locationChange', this.locationCallbackId);
        this.locationCallbackId = null;
      }

      this.isRunning = false;
      hilog.info(DOMAIN, TAG, 'GPS service stopped');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to stop GPS: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 设置省电模式
   */
  setPowerSaveMode(enabled: boolean): void {
    this.powerSaveMode = enabled;
    hilog.info(DOMAIN, TAG, 'Power save mode: %{public}s', enabled);

    // 如果正在运行，重启服务以应用新模式
    if (this.isRunning) {
      this.stop().then(() => this.start());
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
   * 注册位置回调
   */
  onLocation(callback: GpsDataCallback): void {
    this.locationCallbacks.push(callback);
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
    const accuracy = location.accuracy ?? 999;

    // 过滤低精度数据
    if (accuracy > MAX_ACCURACY_THRESHOLD) {
      hilog.debug(DOMAIN, TAG, 'Low accuracy: %{public}f, skipping', accuracy);
      return;
    }

    // 检测静止状态 (省电优化)
    const speed = location.speed ?? 0;
    if (speed < STATIONARY_SPEED_THRESHOLD) {
      this.stationaryCount++;
      // 连续静止5次后跳过更新
      if (this.stationaryCount > 5 && this.powerSaveMode) {
        return;
      }
    } else {
      this.stationaryCount = 0;
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
      speed: speed * 3.6, // m/s -> km/h
      heartRate: 0,
      elevation: location.altitude ?? 0,
      distance: 0
    };

    // 计算距离
    if (this.lastLocation) {
      trackPoint.distance = this.calculateDistance(
        this.lastLocation.coordinate,
        trackPoint.coordinate
      );
    }

    // 更新状态
    this.lastLocation = trackPoint;
    this.lastValidTime = now;
    this.updateSignalState(accuracy);

    // 通知回调
    this.notifyLocationCallbacks(trackPoint);

    hilog.debug(DOMAIN, TAG, 'Location: lat=%{public}f, lon=%{public}f',
      location.latitude, location.longitude);
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
   * 更新信号状态
   */
  private updateSignalState(accuracy: number): void {
    let newState: GpsSignalState;

    if (accuracy < 15) {
      newState = GpsSignalState.GOOD;
    } else if (accuracy < 30) {
      newState = GpsSignalState.FAIR;
    } else {
      newState = GpsSignalState.POOR;
    }

    if (newState !== this.signalState) {
      this.signalState = newState;
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
}

// 导出单例
export default new GpsService();

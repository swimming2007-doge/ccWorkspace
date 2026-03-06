/**
 * 骑行数据管理服务
 *
 * 功能说明：
 * - 整合 GPS、BLE、心率数据源
 * - 管理骑行状态和统计数据
 * - 提供实时数据订阅
 * - 计算骑行指标
 *
 * 依赖服务：
 * - GpsService: GPS定位数据
 * - BleClient: 手表传感器数据
 * - LocationFusionService: GPS信号丢失处理
 */
import hilog from '@ohos.hilog';
import {
  RideState,
  RideEvent,
  TrackPoint,
  SensorDataFromWatch,
  RideStatistics
} from '../utils/Types';
import GpsService, { GpsSignalState } from './GpsService';
import BleClient, { ConnectionState } from './BleClient';
import SignalLostHandler, { SignalStatus, FusedLocation } from './LocationFusionService';

const TAG = '[RideDataService]';
const DOMAIN = 0xFF00;

// 心率区间定义
export enum HeartRateZone {
  Z1_RECOVERY = 'Z1',      // 恢复区 50-60%
  Z2_AEROBIC = 'Z2',       // 有氧区 60-70%
  Z3_TEMPO = 'Z3',         // 强化区 70-80%
  Z4_THRESHOLD = 'Z4',     // 阈值区 80-90%
  Z5_MAX = 'Z5'            // 极限区 90-100%
}

// 骑行实时数据
export interface RideData {
  // 基础数据
  state: RideState;
  startTime: number;
  elapsedTime: number;         // 总时间 (秒)
  movingTime: number;          // 移动时间 (秒)

  // 速度和距离
  currentSpeed: number;        // km/h
  avgSpeed: number;            // km/h
  maxSpeed: number;            // km/h
  distance: number;            // 米

  // 心率
  heartRate: number;           // bpm
  avgHeartRate: number;        // bpm
  maxHeartRate: number;        // bpm
  heartRateZone: HeartRateZone;
  heartRateZoneDistribution: Map<HeartRateZone, number>; // 区间时间分布

  // 海拔
  elevation: number;           // 米
  elevationGain: number;       // 累计爬升 (米)
  elevationLoss: number;       // 累计下降 (米)
  gradient: number;            // 坡度 (%)

  // 轨迹
  trackPoints: TrackPoint[];
  currentLocation: TrackPoint | null;

  // 信号状态
  gpsSignal: GpsSignalState;
  bleConnection: ConnectionState;

  // 卡路里估算
  calories: number;
}

// 数据更新回调
export type RideDataCallback = (data: RideData) => void;
export type StateChangeCallback = (event: RideEvent) => void;

/**
 * 骑行数据管理服务类
 */
export class RideDataService {
  // 骑行状态
  private rideState: RideState = RideState.IDLE;
  private startTime: number = 0;
  private pauseStartTime: number = 0;
  private totalPauseTime: number = 0;

  // 实时数据
  private currentData: RideData;
  private previousLocation: TrackPoint | null = null;

  // 心率区间追踪
  private maxHeartRate: number = 185;
  private zoneDurations: Map<HeartRateZone, number> = new Map();

  // 回调
  private dataCallbacks: RideDataCallback[] = [];
  private stateCallbacks: StateChangeCallback[] = [];

  // 定时器
  private updateTimer: number = -1;
  private readonly UPDATE_INTERVAL = 1000; // 1秒更新一次

  constructor() {
    // 初始化数据
    this.currentData = this.createEmptyRideData();
    this.initZoneDurations();
  }

  /**
   * 开始骑行
   */
  async startRide(): Promise<void> {
    if (this.rideState !== RideState.IDLE) {
      hilog.warn(DOMAIN, TAG, 'Ride already started');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting ride');

    // 初始化骑行数据
    this.startTime = Date.now();
    this.totalPauseTime = 0;
    this.rideState = RideState.RIDING;

    // 重置数据
    this.currentData = this.createEmptyRideData();
    this.currentData.state = RideState.RIDING;
    this.currentData.startTime = this.startTime;
    this.initZoneDurations();

    // 启动GPS
    try {
      await GpsService.start();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start GPS: %{public}s', JSON.stringify(error));
    }

    // 注册回调
    this.registerServiceCallbacks();

    // 启动定时更新
    this.startUpdateTimer();

    // 通知状态变化
    this.notifyStateChange(RideEvent.RIDE_START);

    hilog.info(DOMAIN, TAG, 'Ride started');
  }

  /**
   * 暂停骑行
   */
  pauseRide(): void {
    if (this.rideState !== RideState.RIDING) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Pausing ride');
    this.rideState = RideState.PAUSED;
    this.pauseStartTime = Date.now();
    this.currentData.state = RideState.PAUSED;
    this.notifyStateChange(RideEvent.RIDE_PAUSE);
  }

  /**
   * 恢复骑行
   */
  resumeRide(): void {
    if (this.rideState !== RideState.PAUSED) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Resuming ride');
    this.totalPauseTime += Date.now() - this.pauseStartTime;
    this.rideState = RideState.RIDING;
    this.currentData.state = RideState.RIDING;
    this.notifyStateChange(RideEvent.RIDE_RESUME);
  }

  /**
   * 结束骑行
   */
  async endRide(): Promise<void> {
    if (this.rideState === RideState.IDLE) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Ending ride');

    // 停止定时器
    this.stopUpdateTimer();

    // 停止GPS
    try {
      await GpsService.stop();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to stop GPS: %{public}s', JSON.stringify(error));
    }

    // 计算最终统计
    this.finalizeRideData();

    // 更新状态
    this.rideState = RideState.ENDING;
    this.currentData.state = RideState.ENDING;
    this.notifyStateChange(RideEvent.RIDE_END_REQUEST);
  }

  /**
   * 确认结束
   */
  confirmEnd(): void {
    this.rideState = RideState.IDLE;
    this.currentData.state = RideState.IDLE;
    this.notifyStateChange(RideEvent.RIDE_END_CONFIRMED);
  }

  /**
   * 获取当前数据
   */
  getCurrentData(): RideData {
    return { ...this.currentData };
  }

  /**
   * 获取骑行状态
   */
  getRideState(): RideState {
    return this.rideState;
  }

  /**
   * 设置最大心率
   */
  setMaxHeartRate(maxHr: number): void {
    this.maxHeartRate = maxHr;
  }

  /**
   * 注册数据回调
   */
  onDataChange(callback: RideDataCallback): void {
    this.dataCallbacks.push(callback);
  }

  /**
   * 注册状态回调
   */
  onStateChange(callback: StateChangeCallback): void {
    this.stateCallbacks.push(callback);
  }

  // ==================== 私有方法 ====================

  /**
   * 创建空的骑行数据
   */
  private createEmptyRideData(): RideData {
    return {
      state: RideState.IDLE,
      startTime: 0,
      elapsedTime: 0,
      movingTime: 0,
      currentSpeed: 0,
      avgSpeed: 0,
      maxSpeed: 0,
      distance: 0,
      heartRate: 0,
      avgHeartRate: 0,
      maxHeartRate: 0,
      heartRateZone: HeartRateZone.Z1_RECOVERY,
      heartRateZoneDistribution: new Map(),
      elevation: 0,
      elevationGain: 0,
      elevationLoss: 0,
      gradient: 0,
      trackPoints: [],
      currentLocation: null,
      gpsSignal: GpsSignalState.LOST,
      bleConnection: ConnectionState.DISCONNECTED,
      calories: 0
    };
  }

  /**
   * 初始化心率区间时长
   */
  private initZoneDurations(): void {
    Object.values(HeartRateZone).forEach(zone => {
      this.zoneDurations.set(zone, 0);
    });
  }

  /**
   * 注册服务回调
   */
  private registerServiceCallbacks(): void {
    // GPS位置更新
    GpsService.onLocation((location: TrackPoint) => {
      this.onGpsLocationUpdate(location);
    });

    // GPS信号状态
    GpsService.onSignalState((state: GpsSignalState) => {
      this.currentData.gpsSignal = state;
      this.notifyDataCallbacks();
    });

    // BLE数据更新
    BleClient.onDataReceived((data) => {
      this.onBleDataReceived(data);
    });

    // BLE连接状态
    BleClient.onConnectionStateChange((state) => {
      this.currentData.bleConnection = state;
      this.notifyDataCallbacks();
    });
  }

  /**
   * GPS位置更新处理
   */
  private onGpsLocationUpdate(location: TrackPoint): void {
    if (this.rideState !== RideState.RIDING) {
      return;
    }

    // 更新当前位置
    this.currentData.currentLocation = location;
    this.currentData.currentSpeed = location.speed;

    // 计算距离增量
    if (this.previousLocation) {
      const distanceDelta = this.calculateDistance(
        this.previousLocation.coordinate,
        location.coordinate
      );
      this.currentData.distance += distanceDelta;

      // 计算海拔变化
      const elevationDelta = location.elevation - this.previousLocation.elevation;
      if (elevationDelta > 0) {
        this.currentData.elevationGain += elevationDelta;
      } else if (elevationDelta < 0) {
        this.currentData.elevationLoss += Math.abs(elevationDelta);
      }

      // 计算坡度
      if (distanceDelta > 0) {
        this.currentData.gradient = (elevationDelta / distanceDelta) * 100;
      }
    }

    // 更新海拔
    this.currentData.elevation = location.elevation;

    // 更新最大速度
    if (location.speed > this.currentData.maxSpeed) {
      this.currentData.maxSpeed = location.speed;
    }

    // 添加轨迹点
    this.currentData.trackPoints.push({ ...location });

    // 保存上一位置
    this.previousLocation = location;

    // 更新移动时间
    if (location.speed > 0) {
      this.currentData.movingTime++;
    }
  }

  /**
   * BLE数据接收处理
   */
  private onBleDataReceived(data: { type: number; data: any }): void {
    if (this.rideState !== RideState.RIDING) {
      return;
    }

    const { type, data: payload } = data;

    switch (type) {
      case 0x02: // SENSOR_DATA
        const sensorData = payload as SensorDataFromWatch;
        if (sensorData) {
          // 更新心率
          this.currentData.heartRate = sensorData.heartRate;
          this.updateHeartRateZone(sensorData.heartRate);

          // 更新最大心率
          if (sensorData.heartRate > this.currentData.maxHeartRate) {
            this.currentData.maxHeartRate = sensorData.heartRate;
          }
        }
        break;

      case 0x03: // RIDE_STATE
        if (payload && payload.state === 'PAUSED') {
          this.pauseRide();
        } else if (payload && payload.state === 'RIDING') {
          if (this.rideState === RideState.PAUSED) {
            this.resumeRide();
          }
        }
        break;
    }
  }

  /**
   * 更新心率区间
   */
  private updateHeartRateZone(heartRate: number): void {
    const percentage = (heartRate / this.maxHeartRate) * 100;
    let zone: HeartRateZone;

    if (percentage < 60) {
      zone = HeartRateZone.Z1_RECOVERY;
    } else if (percentage < 70) {
      zone = HeartRateZone.Z2_AEROBIC;
    } else if (percentage < 80) {
      zone = HeartRateZone.Z3_TEMPO;
    } else if (percentage < 90) {
      zone = HeartRateZone.Z4_THRESHOLD;
    } else {
      zone = HeartRateZone.Z5_MAX;
    }

    this.currentData.heartRateZone = zone;
    this.zoneDurations.set(zone, (this.zoneDurations.get(zone) ?? 0) + 1);
    this.currentData.heartRateZoneDistribution = new Map(this.zoneDurations);
  }

  /**
   * 启动更新定时器
   */
  private startUpdateTimer(): void {
    this.updateTimer = setInterval(() => {
      this.updateRideData();
    }, this.UPDATE_INTERVAL);
  }

  /**
   * 停止更新定时器
   */
  private stopUpdateTimer(): void {
    if (this.updateTimer !== -1) {
      clearInterval(this.updateTimer);
      this.updateTimer = -1;
    }
  }

  /**
   * 更新骑行数据
   */
  private updateRideData(): void {
    if (this.rideState === RideState.RIDING) {
      // 更新时间
      this.currentData.elapsedTime = Math.floor((Date.now() - this.startTime - this.totalPauseTime) / 1000);

      // 计算平均速度
      if (this.currentData.movingTime > 0) {
        this.currentData.avgSpeed = (this.currentData.distance / 1000) / (this.currentData.movingTime / 3600);
      }

      // 估算卡路里 (简化公式: 约0.5 kcal/kg/km)
      // 假设用户体重70kg
      const weight = 70;
      this.currentData.calories = Math.round(this.currentData.distance * weight * 0.0005);

      // 计算平均心率
      if (this.currentData.trackPoints.length > 0) {
        const hrValues = this.currentData.trackPoints
          .filter(p => p.heartRate > 0)
          .map(p => p.heartRate);

        if (hrValues.length > 0) {
          this.currentData.avgHeartRate = Math.round(
            hrValues.reduce((a, b) => a + b, 0) / hrValues.length
          );
        }
      }
    }

    // 通知更新
    this.notifyDataCallbacks();
  }

  /**
   * 计算两点间距离
   */
  private calculateDistance(p1: { latitude: number; longitude: number },
                            p2: { latitude: number; longitude: number }): number {
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
   * 完成骑行数据计算
   */
  private finalizeRideData(): void {
    // 最终时间计算
    this.currentData.elapsedTime = Math.floor((Date.now() - this.startTime - this.totalPauseTime) / 1000);

    // 最终平均速度
    if (this.currentData.movingTime > 0) {
      this.currentData.avgSpeed = (this.currentData.distance / 1000) / (this.currentData.movingTime / 3600);
    }

    hilog.info(DOMAIN, TAG, 'Ride finalized - Distance: %{public}f km, Time: %{public}d min',
      this.currentData.distance / 1000,
      Math.floor(this.currentData.elapsedTime / 60));
  }

  /**
   * 通知数据回调
   */
  private notifyDataCallbacks(): void {
    const data = this.getCurrentData();
    for (const callback of this.dataCallbacks) {
      try {
        callback(data);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Data callback error: %{public}s', JSON.stringify(error));
      }
    }
  }

  /**
   * 通知状态变化
   */
  private notifyStateChange(event: RideEvent): void {
    hilog.info(DOMAIN, TAG, 'Ride event: %{public}s', event);

    for (const callback of this.stateCallbacks) {
      try {
        callback(event);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'State callback error: %{public}s', JSON.stringify(error));
      }
    }
  }
}

// 导出单例
export default new RideDataService();

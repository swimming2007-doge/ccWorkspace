/**
 * 传感器数据采集服务
 *
 * 功能说明：
 * - 采集加速度计数据 (50Hz)
 * - 采集陀螺仪数据 (50Hz)
 * - 采集心率数据 (1Hz)
 * - 采集GPS数据 (1Hz)
 * - 提供数据订阅和取消订阅接口
 *
 * 技术栈：
 * - @ohos.sensor 加速度计、陀螺仪、心率
 * - @ohos.geoLocationManager GPS定位
 */
import sensor from '@ohos.sensor';
import geoLocationManager from '@ohos.geoLocationManager';
import hilog from '@ohos.hilog';
import { SensorData, Coordinate, HeartRateData } from '../utils/Types';

const TAG = '[SensorService]';
const DOMAIN = 0xFF00;

// 传感器采样频率
const ACCELEROMETER_INTERVAL = 20000000; // 20ms = 50Hz
const GYROSCOPE_INTERVAL = 20000000; // 20ms = 50Hz
const HEART_RATE_INTERVAL = 1000000000; // 1s = 1Hz
const GPS_INTERVAL = 1; // 1秒

// 回调类型定义
export type SensorDataCallback = (data: SensorData) => void;
export type HeartRateCallback = (data: HeartRateData) => void;
export type LocationCallback = (location: Coordinate) => void;

/**
 * 传感器服务类
 * 负责采集和管理传感器数据
 */
export class SensorService {
  private accelerometerSubscriber: number | null = null;
  private gyroscopeSubscriber: number | null = null;
  private heartRateSubscriber: number | null = null;
  private locationCallbackId: number | null = null;

  private sensorDataCallback: SensorDataCallback | null = null;
  private heartRateCallback: HeartRateCallback | null = null;
  private locationCallback: LocationCallback | null = null;

  private lastAccData: { x: number, y: number, z: number } | null = null;
  private lastGyroData: { x: number, y: number, z: number } | null = null;
  private lastHeartRate: number = 0;
  private lastLocation: Coordinate | null = null;
  private lastSpeed: number = 0;

  private isRunning: boolean = false;

  /**
   * 启动传感器采集
   */
  start(): void {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'Sensor service is already running');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting sensor service');
    this.startAccelerometer();
    this.startGyroscope();
    this.startHeartRate();
    this.startLocation();
    this.isRunning = true;
  }

  /**
   * 停止传感器采集
   */
  stop(): void {
    if (!this.isRunning) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Stopping sensor service');
    this.stopAccelerometer();
    this.stopGyroscope();
    this.stopHeartRate();
    this.stopLocation();
    this.isRunning = false;
  }

  /**
   * 设置传感器数据回调
   */
  setSensorDataCallback(callback: SensorDataCallback): void {
    this.sensorDataCallback = callback;
  }

  /**
   * 设置心率数据回调
   */
  setHeartRateCallback(callback: HeartRateCallback): void {
    this.heartRateCallback = callback;
  }

  /**
   * 设置位置数据回调
   */
  setLocationCallback(callback: LocationCallback): void {
    this.locationCallback = callback;
  }

  /**
   * 获取当前运行状态
   */
  getRunningState(): boolean {
    return this.isRunning;
  }

  /**
   * 获取最后一次传感器数据
   */
  getLastSensorData(): SensorData | null {
    if (this.lastAccData && this.lastGyroData) {
      return {
        timestamp: Date.now(),
        accX: this.lastAccData.x,
        accY: this.lastAccData.y,
        accZ: this.lastAccData.z,
        gyroX: this.lastGyroData.x,
        gyroY: this.lastGyroData.y,
        gyroZ: this.lastGyroData.z,
        speed: this.lastSpeed,
        heartRate: this.lastHeartRate
      };
    }
    return null;
  }

  // ==================== 私有方法 ====================

  private startAccelerometer(): void {
    try {
      this.accelerometerSubscriber = sensor.on(sensor.SensorType.ACCELEROMETER, (data) => {
        this.lastAccData = {
          x: data.x,
          y: data.y,
          z: data.z
        };
        this.emitSensorData();
      }, {
        interval: ACCELEROMETER_INTERVAL
      });
      hilog.info(DOMAIN, TAG, 'Accelerometer started');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start accelerometer: %{public}s', JSON.stringify(error));
    }
  }

  private stopAccelerometer(): void {
    if (this.accelerometerSubscriber !== null) {
      try {
        sensor.off(sensor.SensorType.ACCELEROMETER, this.accelerometerSubscriber);
        hilog.info(DOMAIN, TAG, 'Accelerometer stopped');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to stop accelerometer: %{public}s', JSON.stringify(error));
      }
      this.accelerometerSubscriber = null;
    }
  }

  private startGyroscope(): void {
    try {
      this.gyroscopeSubscriber = sensor.on(sensor.SensorType.GYROSCOPE, (data) => {
        this.lastGyroData = {
          x: data.x,
          y: data.y,
          z: data.z
        };
        this.emitSensorData();
      }, {
        interval: GYROSCOPE_INTERVAL
      });
      hilog.info(DOMAIN, TAG, 'Gyroscope started');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start gyroscope: %{public}s', JSON.stringify(error));
    }
  }

  private stopGyroscope(): void {
    if (this.gyroscopeSubscriber !== null) {
      try {
        sensor.off(sensor.SensorType.GYROSCOPE, this.gyroscopeSubscriber);
        hilog.info(DOMAIN, TAG, 'Gyroscope stopped');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to stop gyroscope: %{public}s', JSON.stringify(error));
      }
      this.gyroscopeSubscriber = null;
    }
  }

  private startHeartRate(): void {
    try {
      this.heartRateSubscriber = sensor.on(sensor.SensorType.HEART_RATE, (data) => {
        this.lastHeartRate = data.heartRate;
        if (this.heartRateCallback) {
          this.heartRateCallback({
            timestamp: Date.now(),
            heartRate: data.heartRate,
            confidence: data.confidence ?? 0
          });
        }
      }, {
        interval: HEART_RATE_INTERVAL
      });
      hilog.info(DOMAIN, TAG, 'Heart rate sensor started');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start heart rate sensor: %{public}s', JSON.stringify(error));
    }
  }

  private stopHeartRate(): void {
    if (this.heartRateSubscriber !== null) {
      try {
        sensor.off(sensor.SensorType.HEART_RATE, this.heartRateSubscriber);
        hilog.info(DOMAIN, TAG, 'Heart rate sensor stopped');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to stop heart rate sensor: %{public}s', JSON.stringify(error));
      }
      this.heartRateSubscriber = null;
    }
  }

  private startLocation(): void {
    try {
      const requestInfo: geoLocationManager.LocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        scenario: geoLocationManager.LocationRequestScenario.NAVIGATION,
        timeInterval: GPS_INTERVAL,
        distanceInterval: 0
      };

      this.locationCallbackId = geoLocationManager.on('locationChange', requestInfo, (location) => {
        this.lastLocation = {
          latitude: location.latitude,
          longitude: location.longitude,
          altitude: location.altitude,
          accuracy: location.accuracy
        };
        this.lastSpeed = location.speed * 3.6; // m/s -> km/h

        if (this.locationCallback) {
          this.locationCallback(this.lastLocation);
        }
        this.emitSensorData();
      });
      hilog.info(DOMAIN, TAG, 'Location service started');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start location service: %{public}s', JSON.stringify(error));
    }
  }

  private stopLocation(): void {
    if (this.locationCallbackId !== null) {
      try {
        geoLocationManager.off('locationChange', this.locationCallbackId);
        hilog.info(DOMAIN, TAG, 'Location service stopped');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to stop location service: %{public}s', JSON.stringify(error));
      }
      this.locationCallbackId = null;
    }
  }

  /**
   * 发送融合的传感器数据
   */
  private emitSensorData(): void {
    if (this.sensorDataCallback && this.lastAccData && this.lastGyroData) {
      this.sensorDataCallback({
        timestamp: Date.now(),
        accX: this.lastAccData.x,
        accY: this.lastAccData.y,
        accZ: this.lastAccData.z,
        gyroX: this.lastGyroData.x,
        gyroY: this.lastGyroData.y,
        gyroZ: this.lastGyroData.z,
        speed: this.lastSpeed,
        heartRate: this.lastHeartRate
      });
    }
  }
}

// 导出单例
export default new SensorService();

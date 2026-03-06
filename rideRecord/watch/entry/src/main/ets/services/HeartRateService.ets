/**
 * 心率数据采集服务
 *
 * 功能说明：
 * - 心率传感器数据采集
 * - 心率区间计算 (Z1-Z5)
 * - 心率异常检测
 * - 心率数据统计
 *
 * 技术栈：
 * - @ohos.sensor 心率传感器API
 */
import sensor from '@ohos.sensor';
import hilog from '@ohos.hilog';

const TAG = '[HeartRateService]';
const DOMAIN = 0xFF00;

// 心率采集间隔
const HEART_RATE_INTERVAL = 1000000000; // 1秒

/**
 * 心率区间
 */
export enum HeartRateZone {
  Z1_RECOVERY = 'Z1',      // 恢复区 50-60%
  Z2_AEROBIC = 'Z2',       // 有氧区 60-70%
  Z3_TEMPO = 'Z3',         // 强化区 70-80%
  Z4_THRESHOLD = 'Z4',     // 阈值区 80-90%
  Z5_MAX = 'Z5'            // 极限区 90-100%
}

/**
 * 心率区间配置
 */
export interface HeartRateZoneConfig {
  z1Max: number;  // Z1 上限 (百分比)
  z2Max: number;  // Z2 上限
  z3Max: number;  // Z3 上限
  z4Max: number;  // Z4 上限
}

/**
 * 心率统计
 */
export interface HeartRateStats {
  current: number;           // 当前心率
  avg: number;               // 平均心率
  max: number;               // 最大心率
  min: number;               // 最小心率
  zoneDistribution: Map<HeartRateZone, number>; // 区间分布 (百分比)
  zoneDurations: Map<HeartRateZone, number>;    // 区间时长 (秒)
}

/**
 * 心率异常类型
 */
export enum HeartRateAnomaly {
  NONE = 'NONE',
  TOO_HIGH = 'TOO_HIGH',    // 心率过高
  TOO_LOW = 'TOO_LOW',      // 心率过低
  IRREGULAR = 'IRREGULAR'   // 心率不规律
}

/**
 * 心率异常回调
 */
export type HeartRateAnomalyCallback = (anomaly: HeartRateAnomaly, heartRate: number) => void;

/**
 * 心率数据回调
 */
export type HeartRateDataCallback = (heartRate: number, zone: HeartRateZone) => void;

/**
 * 心率数据采集服务类
 */
export class HeartRateService {
  private isRunning: boolean = false;
  private heartRateSubscriber: number | null = null;

  // 用户设置
  private maxHeartRate: number = 185;  // 最大心率 (默认用年龄估算)
  private restingHeartRate: number = 60; // 静息心率

  // 心率区间配置
  private zoneConfig: HeartRateZoneConfig = {
    z1Max: 60,
    z2Max: 70,
    z3Max: 80,
    z4Max: 90
  };

  // 心率统计
  private heartRateHistory: number[] = [];
  private maxHistorySize: number = 300; // 5分钟数据
  private currentZone: HeartRateZone = HeartRateZone.Z1_RECOVERY;
  private zoneDurations: Map<HeartRateZone, number> = new Map();
  private totalDuration: number = 0;

  // 异常检测
  private readonly HIGH_HEART_RATE_THRESHOLD = 0.9; // 最大心率90%
  private readonly LOW_HEART_RATE_THRESHOLD = 0.5;  // 最大心率50%
  private anomalyCheckSize: number = 5; // 检测窗口大小

  // 回调
  private dataCallbacks: HeartRateDataCallback[] = [];
  private anomalyCallbacks: HeartRateAnomalyCallback[] = [];

  /**
   * 启动心率服务
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'Heart rate service is already running');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting heart rate service');

    try {
      this.heartRateSubscriber = sensor.on(sensor.SensorType.HEART_RATE, (data) => {
        this.onHeartRateReceived(data.heartRate, data.confidence ?? 0);
      }, {
        interval: HEART_RATE_INTERVAL
      });

      this.isRunning = true;
      this.initZoneDurations();
      hilog.info(DOMAIN, TAG, 'Heart rate service started');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start heart rate: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 停止心率服务
   */
  async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Stopping heart rate service');

    try {
      if (this.heartRateSubscriber !== null) {
        sensor.off(sensor.SensorType.HEART_RATE, this.heartRateSubscriber);
        this.heartRateSubscriber = null;
      }

      this.isRunning = false;
      hilog.info(DOMAIN, TAG, 'Heart rate service stopped');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to stop heart rate: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 设置最大心率
   */
  setMaxHeartRate(maxHr: number): void {
    this.maxHeartRate = maxHr;
    hilog.info(DOMAIN, TAG, 'Max heart rate set to: %{public}d', maxHr);
  }

  /**
   * 设置静息心率
   */
  setRestingHeartRate(restingHr: number): void {
    this.restingHeartRate = restingHr;
  }

  /**
   * 根据年龄估算最大心率
   */
  estimateMaxHeartRate(age: number): void {
    // 使用 Tanaka 公式: 208 - 0.7 * age
    this.maxHeartRate = Math.round(208 - 0.7 * age);
    hilog.info(DOMAIN, TAG, 'Estimated max heart rate: %{public}d (age: %{public}d)',
      this.maxHeartRate, age);
  }

  /**
   * 获取当前心率
   */
  getCurrentHeartRate(): number {
    return this.heartRateHistory.length > 0
      ? this.heartRateHistory[this.heartRateHistory.length - 1]
      : 0;
  }

  /**
   * 获取当前心率区间
   */
  getCurrentZone(): HeartRateZone {
    return this.currentZone;
  }

  /**
   * 获取心率统计
   */
  getStats(): HeartRateStats {
    const history = this.heartRateHistory;

    return {
      current: history.length > 0 ? history[history.length - 1] : 0,
      avg: this.calculateAverage(history),
      max: history.length > 0 ? Math.max(...history) : 0,
      min: history.length > 0 ? Math.min(...history) : 0,
      zoneDistribution: this.calculateZoneDistribution(),
      zoneDurations: new Map(this.zoneDurations)
    };
  }

  /**
   * 重置统计
   */
  resetStats(): void {
    this.heartRateHistory = [];
    this.totalDuration = 0;
    this.initZoneDurations();
    hilog.info(DOMAIN, TAG, 'Heart rate stats reset');
  }

  /**
   * 注册数据回调
   */
  onData(callback: HeartRateDataCallback): void {
    this.dataCallbacks.push(callback);
  }

  /**
   * 注册异常回调
   */
  onAnomaly(callback: HeartRateAnomalyCallback): void {
    this.anomalyCallbacks.push(callback);
  }

  /**
   * 获取运行状态
   */
  isServiceRunning(): boolean {
    return this.isRunning;
  }

  // ==================== 私有方法 ====================

  /**
   * 心率数据接收处理
   */
  private onHeartRateReceived(heartRate: number, confidence: number): void {
    // 过滤低置信度数据
    if (confidence < 0.5) {
      hilog.debug(DOMAIN, TAG, 'Low confidence: %{public}f, skipping', confidence);
      return;
    }

    // 过滤异常值
    if (heartRate < 30 || heartRate > 220) {
      hilog.warn(DOMAIN, TAG, 'Invalid heart rate: %{public}d', heartRate);
      return;
    }

    // 更新历史
    this.heartRateHistory.push(heartRate);
    if (this.heartRateHistory.length > this.maxHistorySize) {
      this.heartRateHistory.shift();
    }

    // 计算心率区间
    const zone = this.calculateZone(heartRate);
    this.currentZone = zone;

    // 更新区间时长
    this.zoneDurations.set(zone, (this.zoneDurations.get(zone) ?? 0) + 1);
    this.totalDuration++;

    // 检测异常
    this.detectAnomaly(heartRate);

    // 通知回调
    this.notifyDataCallbacks(heartRate, zone);

    hilog.debug(DOMAIN, TAG, 'Heart rate: %{public}d bpm, zone: %{public}s',
      heartRate, zone);
  }

  /**
   * 计算心率区间
   */
  private calculateZone(heartRate: number): HeartRateZone {
    const percentage = (heartRate / this.maxHeartRate) * 100;

    if (percentage < this.zoneConfig.z1Max) {
      return HeartRateZone.Z1_RECOVERY;
    } else if (percentage < this.zoneConfig.z2Max) {
      return HeartRateZone.Z2_AEROBIC;
    } else if (percentage < this.zoneConfig.z3Max) {
      return HeartRateZone.Z3_TEMPO;
    } else if (percentage < this.zoneConfig.z4Max) {
      return HeartRateZone.Z4_THRESHOLD;
    } else {
      return HeartRateZone.Z5_MAX;
    }
  }

  /**
   * 检测心率异常
   */
  private detectAnomaly(heartRate: number): void {
    // 检测心率过高
    if (heartRate > this.maxHeartRate * this.HIGH_HEART_RATE_THRESHOLD) {
      this.notifyAnomalyCallbacks(HeartRateAnomaly.TOO_HIGH, heartRate);
      return;
    }

    // 检测心率过低 (运动中)
    if (heartRate < this.maxHeartRate * this.LOW_HEART_RATE_THRESHOLD) {
      // 需要结合运动状态判断，这里简化处理
    }

    // 检测心率不规律 (短时间内大幅波动)
    if (this.heartRateHistory.length >= this.anomalyCheckSize) {
      const recent = this.heartRateHistory.slice(-this.anomalyCheckSize);
      const variance = this.calculateVariance(recent);

      // 如果变异系数过大，可能心率不规律
      const avg = this.calculateAverage(recent);
      const cv = Math.sqrt(variance) / avg;

      if (cv > 0.15) { // 变异系数 > 15%
        this.notifyAnomalyCallbacks(HeartRateAnomaly.IRREGULAR, heartRate);
      }
    }
  }

  /**
   * 初始化区间时长
   */
  private initZoneDurations(): void {
    Object.values(HeartRateZone).forEach(zone => {
      this.zoneDurations.set(zone, 0);
    });
  }

  /**
   * 计算平均值
   */
  private calculateAverage(values: number[]): number {
    if (values.length === 0) return 0;
    return values.reduce((sum, v) => sum + v, 0) / values.length;
  }

  /**
   * 计算方差
   */
  private calculateVariance(values: number[]): number {
    if (values.length === 0) return 0;
    const avg = this.calculateAverage(values);
    return values.reduce((sum, v) => sum + (v - avg) ** 2, 0) / values.length;
  }

  /**
   * 计算区间分布
   */
  private calculateZoneDistribution(): Map<HeartRateZone, number> {
    const distribution = new Map<HeartRateZone, number>();

    if (this.totalDuration === 0) {
      Object.values(HeartRateZone).forEach(zone => {
        distribution.set(zone, 0);
      });
      return distribution;
    }

    Object.values(HeartRateZone).forEach(zone => {
      const duration = this.zoneDurations.get(zone) ?? 0;
      distribution.set(zone, Math.round((duration / this.totalDuration) * 100));
    });

    return distribution;
  }

  /**
   * 通知数据回调
   */
  private notifyDataCallbacks(heartRate: number, zone: HeartRateZone): void {
    for (const callback of this.dataCallbacks) {
      try {
        callback(heartRate, zone);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Data callback error: %{public}s', JSON.stringify(error));
      }
    }
  }

  /**
   * 通知异常回调
   */
  private notifyAnomalyCallbacks(anomaly: HeartRateAnomaly, heartRate: number): void {
    hilog.warn(DOMAIN, TAG, 'Heart rate anomaly: %{public}s, hr: %{public}d',
      anomaly, heartRate);

    for (const callback of this.anomalyCallbacks) {
      try {
        callback(anomaly, heartRate);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Anomaly callback error: %{public}s', JSON.stringify(error));
      }
    }
  }
}

// 导出单例
export default new HeartRateService();

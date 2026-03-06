/**
 * RideRecord 手表端性能监控服务
 * 功能: 监控启动时间、动作检测延迟、电池消耗、GPS精度等指标
 * SRS引用: NFR-001
 */

import {
  PerformanceMetric,
  PerformanceReport,
  NfrThreshold,
  MetricType,
  MetricUnit
} from '../../../../shared/types';

/**
 * NFR 阈值配置 (手表端)
 */
const NFR_THRESHOLDS: NfrThreshold[] = [
  { id: 'NFR-001-01', type: 'startup', platform: ['watch'], maxValue: 3000, unit: 'ms', description: '应用启动时间 < 3秒' },
  { id: 'NFR-001-02', type: 'action', platform: ['watch'], maxValue: 3, unit: 'second', description: '动作检测响应时间 < 3秒' },
  { id: 'NFR-001-03', type: 'gps', platform: ['watch'], maxValue: 10, unit: 'meter', description: 'GPS定位精度 < 10米' },
  { id: 'NFR-001-06', type: 'memory', platform: ['watch'], maxValue: 100, unit: 'MB', description: '内存占用 < 100MB (手表端更低)' },
  { id: 'NFR-001-07', type: 'battery', platform: ['watch'], maxValue: 10, unit: 'percent', description: '电池消耗 < 10%/小时' }
];

/**
 * 手表端性能监控服务
 */
export class PerformanceMonitor {
  private static instance: PerformanceMonitor;
  private metrics: PerformanceMetric[] = [];
  private startTime: number = 0;
  private batteryStartLevel: number = -1;
  private batteryStartTime: number = 0;
  private actionDetectionStartTime: number = 0;
  private isInitialized: boolean = false;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }

  /**
   * 初始化监控
   */
  initialize(): void {
    if (this.isInitialized) {
      return;
    }
    this.startTime = Date.now();
    this.isInitialized = true;
  }

  /**
   * 测量启动时间
   * @returns 启动耗时指标
   */
  measureStartup(): PerformanceMetric {
    const startupTime = Date.now() - this.startTime;
    const threshold = this.getThreshold('startup');

    const metric: PerformanceMetric = {
      id: `startup-${Date.now()}`,
      type: 'startup',
      platform: 'watch',
      value: startupTime,
      unit: 'ms',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 3000,
      passed: startupTime < (threshold?.maxValue || 3000),
      metadata: {
        coldStart: true
      }
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 开始动作检测计时
   */
  startActionDetectionTimer(): void {
    this.actionDetectionStartTime = Date.now();
  }

  /**
   * 结束动作检测计时
   * @param detected 是否检测到动作
   * @returns 动作检测延迟指标
   */
  endActionDetectionTimer(detected: boolean = true): PerformanceMetric {
    const latencyMs = Date.now() - this.actionDetectionStartTime;
    const latencySeconds = latencyMs / 1000;
    const threshold = this.getThreshold('action');

    const metric: PerformanceMetric = {
      id: `action-${Date.now()}`,
      type: 'action',
      platform: 'watch',
      value: latencySeconds,
      unit: 'second',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 3,
      passed: latencySeconds < (threshold?.maxValue || 3),
      metadata: {
        latencyMs,
        detected
      }
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 测量动作检测延迟
   * @param detectionCallback 检测回调函数
   * @returns 动作检测延迟指标
   */
  async measureActionDetectionLatency(
    detectionCallback: () => Promise<boolean>
  ): Promise<PerformanceMetric> {
    const startTime = Date.now();

    const detected = await detectionCallback();

    const latencyMs = Date.now() - startTime;
    const latencySeconds = latencyMs / 1000;
    const threshold = this.getThreshold('action');

    const metric: PerformanceMetric = {
      id: `action-${Date.now()}`,
      type: 'action',
      platform: 'watch',
      value: latencySeconds,
      unit: 'second',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 3,
      passed: latencySeconds < (threshold?.maxValue || 3),
      metadata: {
        latencyMs,
        detected
      }
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 开始电池追踪
   */
  startBatteryTracking(): void {
    this.batteryStartLevel = this.getBatteryLevel();
    this.batteryStartTime = Date.now();
  }

  /**
   * 结束电池追踪
   * @returns 电池消耗指标
   */
  endBatteryTracking(): PerformanceMetric | null {
    if (this.batteryStartLevel === -1) {
      return null;
    }

    const endLevel = this.getBatteryLevel();
    const durationMs = Date.now() - this.batteryStartTime;
    const durationHours = durationMs / (1000 * 60 * 60);

    // 计算每小时消耗百分比
    const consumptionPercent = durationHours > 0
      ? ((this.batteryStartLevel - endLevel) / durationHours)
      : 0;

    const threshold = this.getThreshold('battery');

    const metric: PerformanceMetric = {
      id: `battery-${Date.now()}`,
      type: 'battery',
      platform: 'watch',
      value: Math.max(0, consumptionPercent),
      unit: 'percent',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 10,
      passed: consumptionPercent < (threshold?.maxValue || 10),
      metadata: {
        durationMs,
        startLevel: this.batteryStartLevel,
        endLevel
      }
    };

    this.metrics.push(metric);
    this.batteryStartLevel = -1;
    return metric;
  }

  /**
   * 获取电池电量
   * 注: 实际实现需要使用 @ohos.batteryInfo
   */
  private getBatteryLevel(): number {
    // 模拟实现 - 实际应使用 @ohos.batteryInfo.getBatteryLevel()
    return 90; // 返回模拟值
  }

  /**
   * 记录内存使用
   */
  recordMemoryUsage(): PerformanceMetric {
    // HarmonyOS 内存获取API (模拟实现)
    const memoryMB = this.getApproximateMemoryMB();
    const threshold = this.getThreshold('memory');

    const metric: PerformanceMetric = {
      id: `memory-${Date.now()}`,
      type: 'memory',
      platform: 'watch',
      value: memoryMB,
      unit: 'MB',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 100,
      passed: memoryMB < (threshold?.maxValue || 100)
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 获取近似内存使用 (MB)
   * 注: 手表端内存限制更严格
   */
  private getApproximateMemoryMB(): number {
    // 模拟实现 - 手表端内存占用通常更低
    const baseMemory = 30;
    const dataMemory = this.metrics.length * 0.05;
    return Math.round(baseMemory + dataMemory + Math.random() * 10);
  }

  /**
   * 验证GPS精度
   * @param knownLocation 已知位置
   * @param measuredLocation 测量位置
   * @returns GPS精度指标
   */
  verifyGpsAccuracy(
    knownLocation: { latitude: number; longitude: number },
    measuredLocation: { latitude: number; longitude: number }
  ): PerformanceMetric {
    const distance = this.calculateDistance(
      knownLocation.latitude,
      knownLocation.longitude,
      measuredLocation.latitude,
      measuredLocation.longitude
    );

    const threshold = this.getThreshold('gps');

    const metric: PerformanceMetric = {
      id: `gps-${Date.now()}`,
      type: 'gps',
      platform: 'watch',
      value: distance,
      unit: 'meter',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 10,
      passed: distance < (threshold?.maxValue || 10),
      metadata: {
        knownLocation,
        measuredLocation
      }
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 计算两点间距离 (Haversine公式)
   */
  private calculateDistance(
    lat1: number, lon1: number,
    lat2: number, lon2: number
  ): number {
    const R = 6371000; // 地球半径 (米)
    const dLat = this.toRad(lat2 - lat1);
    const dLon = this.toRad(lon2 - lon1);

    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(this.toRad(lat1)) * Math.cos(this.toRad(lat2)) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private toRad(deg: number): number {
    return deg * (Math.PI / 180);
  }

  /**
   * 获取阈值配置
   */
  private getThreshold(type: MetricType): NfrThreshold | undefined {
    return NFR_THRESHOLDS.find(t => t.type === type && t.platform.includes('watch'));
  }

  /**
   * 生成性能报告
   */
  generateReport(): PerformanceReport {
    const passed = this.metrics.filter(m => m.passed).length;
    const failed = this.metrics.filter(m => !m.passed).length;
    const total = this.metrics.length;

    const recommendations = this.generateRecommendations();

    return {
      generatedAt: Date.now(),
      platform: 'watch',
      version: '0.1.0',
      metrics: [...this.metrics],
      summary: {
        passed,
        failed,
        total,
        passRate: total > 0 ? (passed / total) * 100 : 0
      },
      recommendations
    };
  }

  /**
   * 生成优化建议
   */
  private generateRecommendations(): string[] {
    const recommendations: string[] = [];

    const failedMetrics = this.metrics.filter(m => !m.passed);

    for (const metric of failedMetrics) {
      switch (metric.type) {
        case 'startup':
          recommendations.push('建议: 优化启动时间 - 延迟加载历史数据、最小化启动初始化');
          break;
        case 'action':
          recommendations.push('建议: 优化动作检测 - 减少特征计算复杂度、使用轻量级模型');
          break;
        case 'memory':
          recommendations.push('建议: 优化内存占用 - 减少数据缓存、使用流式处理');
          break;
        case 'battery':
          recommendations.push('建议: 优化电池消耗 - 降低传感器采样频率、使用低功耗GPS模式');
          break;
        case 'gps':
          recommendations.push('建议: 优化GPS精度 - 等待GPS信号稳定、使用卡尔曼滤波');
          break;
      }
    }

    return [...new Set(recommendations)];
  }

  /**
   * 清除所有指标
   */
  clearMetrics(): void {
    this.metrics = [];
  }

  /**
   * 获取所有指标
   */
  getMetrics(): PerformanceMetric[] {
    return [...this.metrics];
  }
}

// 导出单例
export default PerformanceMonitor.getInstance();

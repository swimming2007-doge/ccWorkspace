/**
 * RideRecord 手机端性能监控服务
 * 功能: 监控启动时间、内存占用、电池消耗、GPS精度、同步延迟等指标
 * SRS引用: NFR-001
 */

import {
  PerformanceMetric,
  PerformanceReport,
  NfrThreshold,
  MetricType,
  MetricUnit
} from '../../../shared/types';

/**
 * NFR 阈值配置
 */
const NFR_THRESHOLDS: NfrThreshold[] = [
  { id: 'NFR-001-01', type: 'startup', platform: ['phone'], maxValue: 3000, unit: 'ms', description: '应用启动时间 < 3秒' },
  { id: 'NFR-001-03', type: 'gps', platform: ['phone'], maxValue: 10, unit: 'meter', description: 'GPS定位精度 < 10米' },
  { id: 'NFR-001-04', type: 'sync', platform: ['phone'], maxValue: 30, unit: 'second', description: '数据同步延迟 < 30秒' },
  { id: 'NFR-001-05', type: 'navigation', platform: ['phone'], maxValue: 5, unit: 'second', description: '导航路径计算时间 < 5秒' },
  { id: 'NFR-001-06', type: 'memory', platform: ['phone'], maxValue: 200, unit: 'MB', description: '内存占用 < 200MB' },
  { id: 'NFR-001-07', type: 'battery', platform: ['phone'], maxValue: 15, unit: 'percent', description: '电池消耗 < 15%/小时' }
];

/**
 * 性能监控服务
 */
export class PerformanceMonitor {
  private static instance: PerformanceMonitor;
  private metrics: PerformanceMetric[] = [];
  private startTime: number = 0;
  private memorySamplingTimer: number = -1;
  private batteryStartLevel: number = -1;
  private batteryStartTime: number = 0;
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
   * @returns 启动耗时 (ms)
   */
  measureStartup(): PerformanceMetric {
    const startupTime = Date.now() - this.startTime;
    const threshold = this.getThreshold('startup');

    const metric: PerformanceMetric = {
      id: `startup-${Date.now()}`,
      type: 'startup',
      platform: 'phone',
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
   * 开始内存采样
   * @param intervalMs 采样间隔 (毫秒)
   */
  startMemorySampling(intervalMs: number = 5000): void {
    this.stopMemorySampling();

    this.memorySamplingTimer = setInterval(() => {
      this.recordMemoryUsage();
    }, intervalMs) as number;
  }

  /**
   * 停止内存采样
   */
  stopMemorySampling(): void {
    if (this.memorySamplingTimer !== -1) {
      clearInterval(this.memorySamplingTimer);
      this.memorySamplingTimer = -1;
    }
  }

  /**
   * 记录内存使用
   */
  private recordMemoryUsage(): PerformanceMetric {
    // HarmonyOS 内存获取API (模拟实现)
    // 实际实现需要使用 @ohos.app.ability.AbilityConstant 或性能分析工具
    const memoryMB = this.getApproximateMemoryMB();
    const threshold = this.getThreshold('memory');

    const metric: PerformanceMetric = {
      id: `memory-${Date.now()}`,
      type: 'memory',
      platform: 'phone',
      value: memoryMB,
      unit: 'MB',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 200,
      passed: memoryMB < (threshold?.maxValue || 200)
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 获取近似内存使用 (MB)
   * 注: 实际实现需要使用 HarmonyOS 性能分析 API
   */
  private getApproximateMemoryMB(): number {
    // 模拟实现 - 实际应使用 @ohos.hiAppEvent 或性能分析工具
    // 这里返回一个估算值
    const baseMemory = 50; // 基础内存
    const dataMemory = this.metrics.length * 0.1; // 数据内存估算
    return Math.round(baseMemory + dataMemory + Math.random() * 20);
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
      platform: 'phone',
      value: Math.max(0, consumptionPercent),
      unit: 'percent',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 15,
      passed: consumptionPercent < (threshold?.maxValue || 15),
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
    return 85; // 返回模拟值
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
      platform: 'phone',
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
   * 记录同步延迟
   * @param durationMs 同步耗时 (毫秒)
   */
  recordSyncLatency(durationMs: number): PerformanceMetric {
    const durationSeconds = durationMs / 1000;
    const threshold = this.getThreshold('sync');

    const metric: PerformanceMetric = {
      id: `sync-${Date.now()}`,
      type: 'sync',
      platform: 'phone',
      value: durationSeconds,
      unit: 'second',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 30,
      passed: durationSeconds < (threshold?.maxValue || 30),
      metadata: {
        durationMs
      }
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 记录导航计算时间
   * @param durationMs 计算耗时 (毫秒)
   */
  recordNavigationLatency(durationMs: number): PerformanceMetric {
    const durationSeconds = durationMs / 1000;
    const threshold = this.getThreshold('navigation');

    const metric: PerformanceMetric = {
      id: `navigation-${Date.now()}`,
      type: 'navigation',
      platform: 'phone',
      value: durationSeconds,
      unit: 'second',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 5,
      passed: durationSeconds < (threshold?.maxValue || 5),
      metadata: {
        durationMs
      }
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 获取阈值配置
   */
  private getThreshold(type: MetricType): NfrThreshold | undefined {
    return NFR_THRESHOLDS.find(t => t.type === type && t.platform.includes('phone'));
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
      platform: 'phone',
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
          recommendations.push('建议: 优化应用启动 - 使用懒加载、延迟初始化非关键服务');
          break;
        case 'memory':
          recommendations.push('建议: 优化内存占用 - 减少缓存数据、及时释放资源');
          break;
        case 'battery':
          recommendations.push('建议: 优化电池消耗 - 降低传感器采样频率、使用低功耗模式');
          break;
        case 'gps':
          recommendations.push('建议: 优化GPS精度 - 检查GPS信号、使用多源数据融合');
          break;
        case 'sync':
          recommendations.push('建议: 优化同步延迟 - 使用增量同步、压缩传输数据');
          break;
        case 'navigation':
          recommendations.push('建议: 优化导航计算 - 缓存路线数据、简化计算算法');
          break;
      }
    }

    return [...new Set(recommendations)]; // 去重
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

  /**
   * 导出指标为JSON
   */
  exportToJson(): string {
    return JSON.stringify(this.generateReport(), null, 2);
  }
}

// 导出单例
export default PerformanceMonitor.getInstance();

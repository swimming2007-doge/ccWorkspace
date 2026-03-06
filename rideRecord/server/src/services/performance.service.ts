/**
 * RideRecord 服务端性能监控服务
 * 功能: 监控API响应时间、内存占用、同步吞吐量等指标
 * SRS引用: NFR-001
 */

import { Request, Response, NextFunction, RequestHandler } from 'express';
import {
  PerformanceMetric,
  PerformanceReport,
  NfrThreshold,
  MetricType
} from '../../shared/types';

/**
 * NFR 阈值配置 (服务端)
 */
const NFR_THRESHOLDS: NfrThreshold[] = [
  { id: 'NFR-001-04', type: 'sync', platform: ['server'], maxValue: 30, unit: 'second', description: '数据同步延迟 < 30秒' },
  { id: 'NFR-001-06', type: 'memory', platform: ['server'], maxValue: 200, unit: 'MB', description: '内存占用 < 200MB' },
  { id: 'NFR-API-01', type: 'api', platform: ['server'], maxValue: 500, unit: 'ms', description: 'API响应时间 < 500ms' }
];

interface ApiLatencyRecord {
  route: string;
  method: string;
  duration: number;
  timestamp: number;
  statusCode: number;
}

/**
 * 服务端性能监控服务
 */
export class PerformanceService {
  private static instance: PerformanceService;
  private metrics: PerformanceMetric[] = [];
  private apiLatencies: ApiLatencyRecord[] = [];
  private startTime: number;

  private constructor() {
    this.startTime = Date.now();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): PerformanceService {
    if (!PerformanceService.instance) {
      PerformanceService.instance = new PerformanceService();
    }
    return PerformanceService.instance;
  }

  /**
   * 性能监控中间件
   * 自动记录API响应时间
   */
  middleware(): RequestHandler {
    return (req: Request, res: Response, next: NextFunction): void => {
      const startTime = Date.now();
      const route = req.route?.path || req.path;
      const method = req.method;

      // 响应完成后记录
      res.on('finish', () => {
        const duration = Date.now() - startTime;
        this.recordApiLatency(route, method, duration, res.statusCode);
      });

      next();
    };
  }

  /**
   * 记录API响应时间
   */
  recordApiLatency(route: string, method: string, duration: number, statusCode: number = 200): PerformanceMetric {
    // 保存详细记录
    this.apiLatencies.push({
      route,
      method,
      duration,
      timestamp: Date.now(),
      statusCode
    });

    const threshold = this.getThreshold('api');

    const metric: PerformanceMetric = {
      id: `api-${Date.now()}`,
      type: 'api',
      platform: 'server',
      value: duration,
      unit: 'ms',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 500,
      passed: duration < (threshold?.maxValue || 500),
      metadata: {
        route,
        method,
        statusCode
      }
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 记录同步延迟
   */
  recordSyncLatency(durationMs: number, operation: 'upload' | 'download'): PerformanceMetric {
    const durationSeconds = durationMs / 1000;
    const threshold = this.getThreshold('sync');

    const metric: PerformanceMetric = {
      id: `sync-${Date.now()}`,
      type: 'sync',
      platform: 'server',
      value: durationSeconds,
      unit: 'second',
      timestamp: Date.now(),
      threshold: threshold?.maxValue || 30,
      passed: durationSeconds < (threshold?.maxValue || 30),
      metadata: {
        durationMs,
        operation
      }
    };

    this.metrics.push(metric);
    return metric;
  }

  /**
   * 记录内存使用
   */
  recordMemoryUsage(): PerformanceMetric {
    const memoryMB = this.getMemoryUsageMB();
    const threshold = this.getThreshold('memory');

    const metric: PerformanceMetric = {
      id: `memory-${Date.now()}`,
      type: 'memory',
      platform: 'server',
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
   * 获取内存使用 (MB)
   */
  private getMemoryUsageMB(): number {
    const usage = process.memoryUsage();
    return Math.round(usage.heapUsed / 1024 / 1024);
  }

  /**
   * 获取API统计
   */
  getApiStats(): {
    totalRequests: number;
    avgLatency: number;
    maxLatency: number;
    minLatency: number;
    errorRate: number;
    routeStats: Map<string, { count: number; avgLatency: number }>;
  } {
    const latencies = this.apiLatencies;

    if (latencies.length === 0) {
      return {
        totalRequests: 0,
        avgLatency: 0,
        maxLatency: 0,
        minLatency: 0,
        errorRate: 0,
        routeStats: new Map()
      };
    }

    const durations = latencies.map(l => l.duration);
    const errors = latencies.filter(l => l.statusCode >= 400);

    // 路由统计
    const routeStats = new Map<string, { count: number; avgLatency: number }>();
    const routeGroups = new Map<string, number[]>();

    for (const latency of latencies) {
      const key = `${latency.method} ${latency.route}`;
      if (!routeGroups.has(key)) {
        routeGroups.set(key, []);
      }
      routeGroups.get(key)!.push(latency.duration);
    }

    for (const [route, durations] of routeGroups) {
      routeStats.set(route, {
        count: durations.length,
        avgLatency: durations.reduce((a, b) => a + b, 0) / durations.length
      });
    }

    return {
      totalRequests: latencies.length,
      avgLatency: durations.reduce((a, b) => a + b, 0) / durations.length,
      maxLatency: Math.max(...durations),
      minLatency: Math.min(...durations),
      errorRate: (errors.length / latencies.length) * 100,
      routeStats
    };
  }

  /**
   * 获取阈值配置
   */
  private getThreshold(type: MetricType): NfrThreshold | undefined {
    return NFR_THRESHOLDS.find(t => t.type === type && t.platform.includes('server'));
  }

  /**
   * 生成性能报告
   */
  generateReport(): PerformanceReport {
    const passed = this.metrics.filter(m => m.passed).length;
    const failed = this.metrics.filter(m => !m.passed).length;
    const total = this.metrics.length;

    const recommendations = this.generateRecommendations();
    const apiStats = this.getApiStats();

    return {
      generatedAt: Date.now(),
      platform: 'server',
      version: '0.1.0',
      metrics: [...this.metrics],
      summary: {
        passed,
        failed,
        total,
        passRate: total > 0 ? (passed / total) * 100 : 0
      },
      recommendations: [
        ...recommendations,
        `API统计: 总请求数 ${apiStats.totalRequests}, 平均延迟 ${apiStats.avgLatency.toFixed(2)}ms, 错误率 ${apiStats.errorRate.toFixed(2)}%`
      ]
    };
  }

  /**
   * 生成优化建议
   */
  private generateRecommendations(): string[] {
    const recommendations: string[] = [];

    const failedMetrics = this.metrics.filter(m => !m.passed);

    // 按类型分组
    const failedByType = new Map<MetricType, number>();
    for (const metric of failedMetrics) {
      failedByType.set(metric.type, (failedByType.get(metric.type) || 0) + 1);
    }

    for (const [type, count] of failedByType) {
      switch (type) {
        case 'api':
          recommendations.push(`建议: 优化API响应 - 发现 ${count} 次慢请求，考虑添加缓存、优化查询`);
          break;
        case 'memory':
          recommendations.push(`建议: 优化内存使用 - 发现 ${count} 次内存超标，检查内存泄漏、优化数据结构`);
          break;
        case 'sync':
          recommendations.push(`建议: 优化同步性能 - 发现 ${count} 次同步延迟，考虑分片传输、压缩数据`);
          break;
      }
    }

    return recommendations;
  }

  /**
   * 清除历史数据
   */
  clearHistory(): void {
    this.metrics = [];
    this.apiLatencies = [];
  }

  /**
   * 获取所有指标
   */
  getMetrics(): PerformanceMetric[] {
    return [...this.metrics];
  }

  /**
   * 健康检查端点处理器
   */
  healthCheckHandler(req: Request, res: Response): void {
    const report = this.generateReport();
    const isHealthy = report.summary.passRate >= 80;

    res.status(isHealthy ? 200 : 503).json({
      status: isHealthy ? 'healthy' : 'degraded',
      timestamp: report.generatedAt,
      uptime: Date.now() - this.startTime,
      summary: report.summary,
      memory: this.getMemoryUsageMB()
    });
  }

  /**
   * 性能报告端点处理器
   */
  reportHandler(req: Request, res: Response): void {
    const report = this.generateReport();
    res.json(report);
  }
}

// 导出单例
export default PerformanceService.getInstance();

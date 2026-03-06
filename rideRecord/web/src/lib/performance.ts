/**
 * RideRecord Web端性能监控服务
 * 功能: 监控Web Vitals、包大小、页面渲染时间等指标
 * SRS引用: NFR-001
 */

import {
  PerformanceMetric,
  PerformanceReport,
  NfrThreshold,
  WebVitals,
  MetricType
} from '../../../shared/types';

/**
 * NFR 阈值配置 (Web端)
 */
const NFR_THRESHOLDS: NfrThreshold[] = [
  { id: 'NFR-001-01', type: 'startup', platform: ['web'], maxValue: 3000, unit: 'ms', description: '页面加载时间 < 3秒' },
  { id: 'NFR-WEB-01', type: 'memory', platform: ['web'], maxValue: 200, unit: 'MB', description: '内存占用 < 200MB' },
  { id: 'NFR-WEB-02', type: 'api', platform: ['web'], maxValue: 1000, unit: 'ms', description: 'API响应时间 < 1秒' }
];

/**
 * Web Vitals 阈值 (Google标准)
 */
const WEB_VITALS_THRESHOLDS = {
  lcp: { good: 2500, needsImprovement: 4000 },  // ms
  fid: { good: 100, needsImprovement: 300 },    // ms
  cls: { good: 0.1, needsImprovement: 0.25 },   // score
  fcp: { good: 1800, needsImprovement: 3000 },  // ms
  ttfb: { good: 800, needsImprovement: 1800 }   // ms
};

/**
 * Web端性能监控服务
 */
export class WebPerformanceMonitor {
  private static instance: WebPerformanceMonitor;
  private metrics: PerformanceMetric[] = [];
  private startTime: number;
  private isInitialized: boolean = false;

  private constructor() {
    this.startTime = Date.now();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): WebPerformanceMonitor {
    if (!WebPerformanceMonitor.instance) {
      WebPerformanceMonitor.instance = new WebPerformanceMonitor();
    }
    return WebPerformanceMonitor.instance;
  }

  /**
   * 初始化监控
   */
  initialize(): void {
    if (this.isInitialized || typeof window === 'undefined') {
      return;
    }

    this.isInitialized = true;
    this.measureWebVitals();
  }

  /**
   * 测量 Web Vitals
   */
  async measureWebVitals(): Promise<WebVitals> {
    if (typeof window === 'undefined' || !('performance' in window)) {
      return this.getDefaultWebVitals();
    }

    // 使用 Performance API 获取指标
    const navigation = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    const paint = performance.getEntriesByType('paint');

    // TTFB (Time to First Byte)
    const ttfb = navigation?.responseStart - navigation?.requestStart || 0;

    // FCP (First Contentful Paint)
    const fcpEntry = paint.find(entry => entry.name === 'first-contentful-paint');
    const fcp = fcpEntry?.startTime || 0;

    // LCP 需要使用 PerformanceObserver
    const lcp = await this.observeLCP();

    // FID 需要用户交互
    const fid = await this.observeFID();

    // CLS (Cumulative Layout Shift)
    const cls = await this.observeCLS();

    const webVitals: WebVitals = {
      lcp,
      fid,
      cls,
      fcp,
      ttfb
    };

    // 记录指标
    this.recordWebVitalsMetrics(webVitals);

    return webVitals;
  }

  /**
   * 获取默认Web Vitals值
   */
  private getDefaultWebVitals(): WebVitals {
    return {
      lcp: 0,
      fid: 0,
      cls: 0,
      fcp: 0,
      ttfb: 0
    };
  }

  /**
   * 观察 LCP (Largest Contentful Paint)
   */
  private observeLCP(): Promise<number> {
    return new Promise((resolve) => {
      if (!('PerformanceObserver' in window)) {
        resolve(0);
        return;
      }

      try {
        const observer = new PerformanceObserver((list) => {
          const entries = list.getEntries();
          const lastEntry = entries[entries.length - 1];
          resolve(lastEntry.startTime);
          observer.disconnect();
        });

        observer.observe({ type: 'largest-contentful-paint', buffered: true });

        // 超时处理
        setTimeout(() => {
          observer.disconnect();
          resolve(0);
        }, 5000);
      } catch {
        resolve(0);
      }
    });
  }

  /**
   * 观察 FID (First Input Delay)
   */
  private observeFID(): Promise<number> {
    return new Promise((resolve) => {
      if (!('PerformanceObserver' in window)) {
        resolve(0);
        return;
      }

      try {
        const observer = new PerformanceObserver((list) => {
          const entries = list.getEntries();
          const firstEntry = entries[0] as PerformanceEventTiming;
          resolve(firstEntry.processingStart - firstEntry.startTime);
          observer.disconnect();
        });

        observer.observe({ type: 'first-input', buffered: true });

        // 超时处理
        setTimeout(() => {
          observer.disconnect();
          resolve(0);
        }, 10000);
      } catch {
        resolve(0);
      }
    });
  }

  /**
   * 观察 CLS (Cumulative Layout Shift)
   */
  private observeCLS(): Promise<number> {
    return new Promise((resolve) => {
      if (!('PerformanceObserver' in window)) {
        resolve(0);
        return;
      }

      let clsValue = 0;

      try {
        const observer = new PerformanceObserver((list) => {
          for (const entry of list.getEntries()) {
            if (!(entry as any).hadRecentInput) {
              clsValue += (entry as any).value;
            }
          }
        });

        observer.observe({ type: 'layout-shift', buffered: true });

        // 超时处理
        setTimeout(() => {
          observer.disconnect();
          resolve(clsValue);
        }, 5000);
      } catch {
        resolve(0);
      }
    });
  }

  /**
   * 记录 Web Vitals 指标
   */
  private recordWebVitalsMetrics(webVitals: WebVitals): void {
    // LCP
    this.metrics.push({
      id: `lcp-${Date.now()}`,
      type: 'startup',
      platform: 'web',
      value: webVitals.lcp,
      unit: 'ms',
      timestamp: Date.now(),
      threshold: WEB_VITALS_THRESHOLDS.lcp.good,
      passed: webVitals.lcp < WEB_VITALS_THRESHOLDS.lcp.good,
      metadata: { metric: 'LCP' }
    });

    // FCP
    this.metrics.push({
      id: `fcp-${Date.now()}`,
      type: 'startup',
      platform: 'web',
      value: webVitals.fcp,
      unit: 'ms',
      timestamp: Date.now(),
      threshold: WEB_VITALS_THRESHOLDS.fcp.good,
      passed: webVitals.fcp < WEB_VITALS_THRESHOLDS.fcp.good,
      metadata: { metric: 'FCP' }
    });

    // TTFB
    this.metrics.push({
      id: `ttfb-${Date.now()}`,
      type: 'api',
      platform: 'web',
      value: webVitals.ttfb,
      unit: 'ms',
      timestamp: Date.now(),
      threshold: WEB_VITALS_THRESHOLDS.ttfb.good,
      passed: webVitals.ttfb < WEB_VITALS_THRESHOLDS.ttfb.good,
      metadata: { metric: 'TTFB' }
    });
  }

  /**
   * 测量页面渲染时间
   */
  measurePageRender(pageName: string): number {
    if (typeof performance === 'undefined') {
      return 0;
    }

    const startMark = `${pageName}-start`;
    const endMark = `${pageName}-end`;

    try {
      performance.mark(endMark);
      const measure = performance.measure(pageName, startMark, endMark);
      const duration = measure.duration;

      const threshold = this.getThreshold('startup');

      this.metrics.push({
        id: `render-${pageName}-${Date.now()}`,
        type: 'startup',
        platform: 'web',
        value: duration,
        unit: 'ms',
        timestamp: Date.now(),
        threshold: threshold?.maxValue || 3000,
        passed: duration < (threshold?.maxValue || 3000),
        metadata: { pageName }
      });

      return duration;
    } catch {
      return 0;
    }
  }

  /**
   * 标记页面开始渲染
   */
  markPageStart(pageName: string): void {
    if (typeof performance === 'undefined') {
      return;
    }
    performance.mark(`${pageName}-start`);
  }

  /**
   * 分析包大小
   */
  async analyzeBundleSize(): Promise<{ jsSize: number; cssSize: number; totalSize: number }> {
    if (typeof performance === 'undefined') {
      return { jsSize: 0, cssSize: 0, totalSize: 0 };
    }

    const resources = performance.getEntriesByType('resource') as PerformanceResourceTiming[];

    let jsSize = 0;
    let cssSize = 0;

    for (const resource of resources) {
      const name = resource.name.toLowerCase();

      if (name.endsWith('.js') || name.includes('.js?')) {
        jsSize += (resource as any).transferSize || (resource as any).encodedBodySize || 0;
      } else if (name.endsWith('.css') || name.includes('.css?')) {
        cssSize += (resource as any).transferSize || (resource as any).encodedBodySize || 0;
      }
    }

    const totalSize = jsSize + cssSize;

    // 记录指标
    this.metrics.push({
      id: `bundle-${Date.now()}`,
      type: 'memory',
      platform: 'web',
      value: Math.round(totalSize / 1024 / 1024 * 100) / 100, // MB
      unit: 'MB',
      timestamp: Date.now(),
      threshold: 5, // 建议包大小 < 5MB
      passed: totalSize < 5 * 1024 * 1024,
      metadata: { jsSize, cssSize, totalSize }
    });

    return { jsSize, cssSize, totalSize };
  }

  /**
   * 获取阈值配置
   */
  private getThreshold(type: MetricType): NfrThreshold | undefined {
    return NFR_THRESHOLDS.find(t => t.type === type && t.platform.includes('web'));
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
      platform: 'web',
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
      const metadata = metric.metadata as Record<string, string>;

      if (metadata?.metric === 'LCP') {
        recommendations.push('建议: 优化LCP - 减少服务器响应时间、使用CDN、预加载关键资源');
      } else if (metadata?.metric === 'FCP') {
        recommendations.push('建议: 优化FCP - 内联关键CSS、延迟非关键JavaScript、优化字体加载');
      } else if (metadata?.metric === 'TTFB') {
        recommendations.push('建议: 优化TTFB - 使用CDN、启用缓存、优化服务器响应');
      } else if (metric.type === 'startup') {
        recommendations.push('建议: 优化页面加载 - 代码分割、懒加载、压缩资源');
      } else if (metric.type === 'memory') {
        recommendations.push('建议: 优化包大小 - Tree shaking、移除未使用代码、压缩资源');
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
export default WebPerformanceMonitor.getInstance();

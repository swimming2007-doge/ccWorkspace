/**
 * 轨迹平滑算法
 *
 * 功能说明：
 * - 卡尔曼滤波平滑GPS轨迹
 * - 道格拉斯-普克算法简化轨迹
 * - GPS信号丢失插值
 * - 异常点过滤
 */
import hilog from '@ohos.hilog';
import { Coordinate, TrackPoint } from './Types';

const TAG = '[TrackSmoother]';
const DOMAIN = 0xFF00;

/**
 * 卡尔曼滤波器
 * 用于平滑GPS轨迹
 */
export class KalmanFilter {
  // 状态变量
  private lat: number = 0;
  private lon: number = 0;
  private velocityLat: number = 0;
  private velocityLon: number = 0;

  // 协方差矩阵
  private P: number[][] = [
    [1, 0, 0, 0],
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1]
  ];

  // 过程噪声
  private Q: number = 0.001;

  // 测量噪声（根据GPS精度动态调整）
  private R: number = 10;

  // 初始化标志
  private initialized: boolean = false;

  // 上一次更新时间
  private lastTime: number = 0;

  /**
   * 更新滤波器
   * @param lat 纬度
   * @param lon 经度
   * @param accuracy GPS精度 (米)
   * @param timestamp 时间戳
   */
  update(lat: number, lon: number, accuracy: number, timestamp: number): { lat: number; lon: number } {
    // 根据精度调整测量噪声
    this.R = accuracy * accuracy / 10000;

    if (!this.initialized) {
      this.lat = lat;
      this.lon = lon;
      this.lastTime = timestamp;
      this.initialized = true;
      return { lat, lon };
    }

    // 计算时间间隔
    const dt = (timestamp - this.lastTime) / 1000;
    this.lastTime = timestamp;

    if (dt <= 0) {
      return { lat: this.lat, lon: this.lon };
    }

    // 预测步骤
    const predictedLat = this.lat + this.velocityLat * dt;
    const predictedLon = this.lon + this.velocityLon * dt;
    const predictedVelocityLat = this.velocityLat;
    const predictedVelocityLon = this.velocityLon;

    // 预测协方差
    const A = [
      [1, 0, dt, 0],
      [0, 1, 0, dt],
      [0, 0, 1, 0],
      [0, 0, 0, 1]
    ];

    const At = this.transpose(A);
    const Ppredicted = this.addMatrix(
      this.multiplyMatrix(this.multiplyMatrix(A, this.P), At),
      this.scalarMultiply(this.identity(4), this.Q)
    );

    // 更新步骤
    const H = [
      [1, 0, 0, 0],
      [0, 1, 0, 0]
    ];

    const Ht = this.transpose(H);
    const Rmatrix = [
      [this.R, 0],
      [0, this.R]
    ];

    // 卡尔曼增益
    const S = this.addMatrix(
      this.multiplyMatrix(this.multiplyMatrix(H, Ppredicted), Ht),
      Rmatrix
    );
    const Sinv = this.inverse2x2(S);
    const K = this.multiplyMatrix(
      this.multiplyMatrix(Ppredicted, Ht),
      Sinv
    );

    // 测量值
    const z = [[lat], [lon]];

    // 预测值
    const predicted = [[predictedLat], [predictedLon], [predictedVelocityLat], [predictedVelocityLon]];

    // 残差
    const y = this.subtractMatrix(z, this.multiplyMatrix(H, predicted));

    // 更新状态
    const updated = this.addMatrix(predicted, this.multiplyMatrix(K, y));

    this.lat = updated[0][0];
    this.lon = updated[1][0];
    this.velocityLat = updated[2][0];
    this.velocityLon = updated[3][0];

    // 更新协方差
    const I = this.identity(4);
    const KH = this.multiplyMatrix(K, H);
    this.P = this.multiplyMatrix(this.subtractMatrix(I, KH), Ppredicted);

    return { lat: this.lat, lon: this.lon };
  }

  /**
   * 重置滤波器
   */
  reset(): void {
    this.initialized = false;
    this.P = [
      [1, 0, 0, 0],
      [0, 1, 0, 0],
      [0, 0, 1, 0],
      [0, 0, 0, 1]
    ];
  }

  // ==================== 矩阵运算辅助方法 ====================

  private transpose(m: number[][]): number[][] {
    const rows = m.length;
    const cols = m[0].length;
    const result: number[][] = [];
    for (let i = 0; i < cols; i++) {
      result[i] = [];
      for (let j = 0; j < rows; j++) {
        result[i][j] = m[j][i];
      }
    }
    return result;
  }

  private multiplyMatrix(a: number[][], b: number[][]): number[][] {
    const rowsA = a.length;
    const colsA = a[0].length;
    const colsB = b[0].length;
    const result: number[][] = [];
    for (let i = 0; i < rowsA; i++) {
      result[i] = [];
      for (let j = 0; j < colsB; j++) {
        let sum = 0;
        for (let k = 0; k < colsA; k++) {
          sum += a[i][k] * b[k][j];
        }
        result[i][j] = sum;
      }
    }
    return result;
  }

  private addMatrix(a: number[][], b: number[][]): number[][] {
    const result: number[][] = [];
    for (let i = 0; i < a.length; i++) {
      result[i] = [];
      for (let j = 0; j < a[0].length; j++) {
        result[i][j] = a[i][j] + b[i][j];
      }
    }
    return result;
  }

  private subtractMatrix(a: number[][], b: number[][]): number[][] {
    const result: number[][] = [];
    for (let i = 0; i < a.length; i++) {
      result[i] = [];
      for (let j = 0; j < a[0].length; j++) {
        result[i][j] = a[i][j] - b[i][j];
      }
    }
    return result;
  }

  private scalarMultiply(m: number[][], s: number): number[][] {
    const result: number[][] = [];
    for (let i = 0; i < m.length; i++) {
      result[i] = [];
      for (let j = 0; j < m[0].length; j++) {
        result[i][j] = m[i][j] * s;
      }
    }
    return result;
  }

  private identity(n: number): number[][] {
    const result: number[][] = [];
    for (let i = 0; i < n; i++) {
      result[i] = [];
      for (let j = 0; j < n; j++) {
        result[i][j] = i === j ? 1 : 0;
      }
    }
    return result;
  }

  private inverse2x2(m: number[][]): number[][] {
    const det = m[0][0] * m[1][1] - m[0][1] * m[1][0];
    return [
      [m[1][1] / det, -m[0][1] / det],
      [-m[1][0] / det, m[0][0] / det]
    ];
  }
}

/**
 * 轨迹平滑器
 */
export class TrackSmoother {
  private kalmanFilter: KalmanFilter = new KalmanFilter();

  // 异常点检测阈值
  private readonly MAX_SPEED_THRESHOLD = 150; // 最大速度 150 km/h
  private readonly MAX_ACCELERATION = 10; // 最大加速度 m/s²

  /**
   * 平滑轨迹点
   */
  smooth(point: TrackPoint): TrackPoint {
    const smoothed = this.kalmanFilter.update(
      point.coordinate.latitude,
      point.coordinate.longitude,
      point.coordinate.accuracy ?? 10,
      point.timestamp
    );

    return {
      ...point,
      coordinate: {
        ...point.coordinate,
        latitude: smoothed.lat,
        longitude: smoothed.lon
      }
    };
  }

  /**
   * 批量平滑轨迹
   */
  smoothTrack(points: TrackPoint[]): TrackPoint[] {
    this.kalmanFilter.reset();
    return points.map(p => this.smooth(p));
  }

  /**
   * 过滤异常点
   */
  filterOutliers(points: TrackPoint[]): TrackPoint[] {
    if (points.length < 3) {
      return points;
    }

    const result: TrackPoint[] = [points[0]];

    for (let i = 1; i < points.length; i++) {
      const prev = result[result.length - 1];
      const curr = points[i];

      // 计算速度
      const distance = this.calculateDistance(prev.coordinate, curr.coordinate);
      const timeDiff = (curr.timestamp - prev.timestamp) / 1000;

      if (timeDiff <= 0) {
        continue;
      }

      const speed = (distance / timeDiff) * 3.6; // km/h

      // 过滤超速点
      if (speed > this.MAX_SPEED_THRESHOLD) {
        hilog.warn(DOMAIN, TAG, 'Filtered outlier: speed=%{public}f km/h', speed);
        continue;
      }

      // 过滤跳跃点（如果精度很差且距离很大）
      const accuracy = curr.coordinate.accuracy ?? 10;
      if (accuracy > 50 && distance > accuracy * 2) {
        hilog.warn(DOMAIN, TAG, 'Filtered jump point: distance=%{public}f m', distance);
        continue;
      }

      result.push(curr);
    }

    return result;
  }

  /**
   * 道格拉斯-普克算法简化轨迹
   * @param points 轨迹点
   * @param epsilon 容差 (米)
   */
  douglasPeucker(points: TrackPoint[], epsilon: number): TrackPoint[] {
    if (points.length <= 2) {
      return points;
    }

    // 找到距离最大的点
    let maxDistance = 0;
    let maxIndex = 0;

    for (let i = 1; i < points.length - 1; i++) {
      const distance = this.perpendicularDistance(
        points[i],
        points[0],
        points[points.length - 1]
      );

      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // 如果最大距离大于容差，递归简化
    if (maxDistance > epsilon) {
      const left = this.douglasPeucker(points.slice(0, maxIndex + 1), epsilon);
      const right = this.douglasPeucker(points.slice(maxIndex), epsilon);

      return [...left.slice(0, -1), ...right];
    }

    // 否则返回端点
    return [points[0], points[points.length - 1]];
  }

  /**
   * GPS信号丢失插值
   */
  interpolate(points: TrackPoint[]): TrackPoint[] {
    if (points.length < 2) {
      return points;
    }

    const result: TrackPoint[] = [points[0]];

    for (let i = 1; i < points.length; i++) {
      const prev = points[i - 1];
      const curr = points[i];

      const timeDiff = (curr.timestamp - prev.timestamp) / 1000;

      // 如果时间间隔超过10秒，进行插值
      if (timeDiff > 10) {
        const numPoints = Math.floor(timeDiff / 2); // 每2秒插入一个点

        for (let j = 1; j <= numPoints; j++) {
          const ratio = j / (numPoints + 1);
          const interpolated: TrackPoint = {
            coordinate: {
              latitude: prev.coordinate.latitude + ratio * (curr.coordinate.latitude - prev.coordinate.latitude),
              longitude: prev.coordinate.longitude + ratio * (curr.coordinate.longitude - prev.coordinate.longitude),
              altitude: prev.coordinate.altitude ?? 0 + ratio * ((curr.coordinate.altitude ?? 0) - (prev.coordinate.altitude ?? 0)),
              accuracy: 50, // 插值点精度较低
              timestamp: prev.timestamp + ratio * (curr.timestamp - prev.timestamp)
            },
            timestamp: prev.timestamp + ratio * (curr.timestamp - prev.timestamp),
            speed: prev.speed + ratio * (curr.speed - prev.speed),
            heartRate: prev.heartRate + ratio * (curr.heartRate - prev.heartRate),
            elevation: prev.elevation + ratio * (curr.elevation - prev.elevation),
            distance: 0
          };
          result.push(interpolated);
        }
      }

      result.push(curr);
    }

    return result;
  }

  /**
   * 重置平滑器
   */
  reset(): void {
    this.kalmanFilter.reset();
  }

  // ==================== 辅助方法 ====================

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

  private perpendicularDistance(point: TrackPoint, lineStart: TrackPoint, lineEnd: TrackPoint): number {
    // 将经纬度转换为平面坐标（简化计算）
    const x0 = point.coordinate.longitude;
    const y0 = point.coordinate.latitude;
    const x1 = lineStart.coordinate.longitude;
    const y1 = lineStart.coordinate.latitude;
    const x2 = lineEnd.coordinate.longitude;
    const y2 = lineEnd.coordinate.latitude;

    const dx = x2 - x1;
    const dy = y2 - y1;

    const lineLengthSquared = dx * dx + dy * dy;

    if (lineLengthSquared === 0) {
      return this.calculateDistance(point.coordinate, lineStart.coordinate);
    }

    // 计算垂直距离
    const t = Math.max(0, Math.min(1, ((x0 - x1) * dx + (y0 - y1) * dy) / lineLengthSquared));
    const nearestX = x1 + t * dx;
    const nearestY = y1 + t * dy;

    // 转换为米
    const latDiff = (y0 - nearestY) * 111000; // 纬度1度约111km
    const lonDiff = (x0 - nearestX) * 111000 * Math.cos(y0 * Math.PI / 180);

    return Math.sqrt(latDiff * latDiff + lonDiff * lonDiff);
  }
}

// 导出单例
export default new TrackSmoother();

/**
 * RideRecord 共享工具函数
 */

import {
  Coordinate,
  TrackPoint,
  RiskFactors,
  RISK_WEIGHTS,
  SPEED_CONVERSION,
  DISTANCE_CONVERSION,
} from '../types';

// ===========================================
// 地理计算工具
// ===========================================

/**
 * 计算两点之间的距离 (Haversine公式)
 * @param p1 点1
 * @param p2 点2
 * @returns 距离 (米)
 */
export function calculateDistance(p1: Coordinate, p2: Coordinate): number {
  const R = 6371000; // 地球半径 (米)
  const dLat = toRadians(p2.latitude - p1.latitude);
  const dLng = toRadians(p2.longitude - p1.longitude);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(p1.latitude)) *
      Math.cos(toRadians(p2.latitude)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * 计算轨迹总距离
 * @param points 轨迹点数组
 * @returns 总距离 (米)
 */
export function calculateTotalDistance(points: TrackPoint[]): number {
  if (points.length < 2) return 0;

  let totalDistance = 0;
  for (let i = 1; i < points.length; i++) {
    totalDistance += calculateDistance(
      { latitude: points[i - 1].latitude, longitude: points[i - 1].longitude },
      { latitude: points[i].latitude, longitude: points[i].longitude }
    );
  }
  return totalDistance;
}

/**
 * 计算两点之间的方位角
 * @param from 起点
 * @param to 终点
 * @returns 方位角 (度, 0-360)
 */
export function calculateBearing(from: Coordinate, to: Coordinate): number {
  const dLng = toRadians(to.longitude - from.longitude);
  const lat1 = toRadians(from.latitude);
  const lat2 = toRadians(to.latitude);

  const y = Math.sin(dLng) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);

  let bearing = toDegrees(Math.atan2(y, x));
  return (bearing + 360) % 360;
}

/**
 * 计算总爬升
 * @param points 轨迹点数组
 * @returns 总爬升 (米)
 */
export function calculateElevationGain(points: TrackPoint[]): number {
  if (points.length < 2) return 0;

  let gain = 0;
  let prevAlt = points[0].altitude;

  if (prevAlt === undefined) return 0;

  for (let i = 1; i < points.length; i++) {
    const alt = points[i].altitude;
    if (alt !== undefined && alt > prevAlt) {
      gain += alt - prevAlt;
    }
    if (alt !== undefined) {
      prevAlt = alt;
    }
  }
  return gain;
}

// ===========================================
// 数学计算工具
// ===========================================

/**
 * 角度转弧度
 */
export function toRadians(degrees: number): number {
  return degrees * (Math.PI / 180);
}

/**
 * 弧度转角度
 */
export function toDegrees(radians: number): number {
  return radians * (180 / Math.PI);
}

/**
 * 计算数组平均值
 */
export function mean(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

/**
 * 计算数组标准差
 */
export function stdDev(values: number[]): number {
  if (values.length === 0) return 0;
  const avg = mean(values);
  const squareDiffs = values.map(v => Math.pow(v - avg, 2));
  return Math.sqrt(mean(squareDiffs));
}

/**
 * 计算数组最大值
 */
export function max(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.max(...values);
}

/**
 * 计算数组最小值
 */
export function min(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.min(...values);
}

/**
 * 线性插值
 */
export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

/**
 * 限制数值在范围内
 */
export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

// ===========================================
// 速度和单位转换
// ===========================================

/**
 * m/s 转 km/h
 */
export function msToKmh(ms: number): number {
  return ms * SPEED_CONVERSION.MS_TO_KMH;
}

/**
 * m/s 转 mph
 */
export function msToMph(ms: number): number {
  return ms * SPEED_CONVERSION.MS_TO_MPH;
}

/**
 * 米转公里
 */
export function mToKm(m: number): number {
  return m * DISTANCE_CONVERSION.M_TO_KM;
}

/**
 * 米转英里
 */
export function mToMi(m: number): number {
  return m * DISTANCE_CONVERSION.M_TO_MI;
}

/**
 * 格式化速度显示
 * @param speed 速度 (m/s)
 * @param unit 单位制
 */
export function formatSpeed(speed: number, unit: 'metric' | 'imperial' = 'metric'): string {
  if (unit === 'imperial') {
    return `${msToMph(speed).toFixed(1)} mph`;
  }
  return `${msToKmh(speed).toFixed(1)} km/h`;
}

/**
 * 格式化距离显示
 * @param distance 距离 (米)
 * @param unit 单位制
 */
export function formatDistance(distance: number, unit: 'metric' | 'imperial' = 'metric'): string {
  if (unit === 'imperial') {
    const miles = mToMi(distance);
    if (miles < 1) {
      return `${(miles * 5280).toFixed(0)} ft`;
    }
    return `${miles.toFixed(2)} mi`;
  }

  if (distance < 1000) {
    return `${distance.toFixed(0)} m`;
  }
  return `${mToKm(distance).toFixed(2)} km`;
}

/**
 * 格式化时间显示
 * @param seconds 秒数
 */
export function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);

  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
  return `${minutes}:${secs.toString().padStart(2, '0')}`;
}

// ===========================================
// 冒险指数计算
// ===========================================

/**
 * 计算冒险指数
 * @param factors 风险因素
 * @returns 冒险指数 (1-5)
 */
export function calculateRiskIndex(factors: RiskFactors): number {
  const weights = RISK_WEIGHTS;
  const weightedSum =
    weights.SURFACE * factors.surface +
    weights.SLOPE * factors.slope +
    weights.TRAFFIC * factors.traffic +
    weights.SIGNAL * factors.signal +
    weights.SUPPLY * factors.supply +
    weights.WEATHER * factors.weather;

  const totalWeight =
    weights.SURFACE +
    weights.SLOPE +
    weights.TRAFFIC +
    weights.SIGNAL +
    weights.SUPPLY +
    weights.WEATHER;

  return clamp(weightedSum / totalWeight, 1, 5);
}

/**
 * 获取冒险等级标签
 * @param index 冒险指数
 */
export function getRiskLevelLabel(index: number): string {
  if (index <= 1.5) return '安全';
  if (index <= 2.5) return '低风险';
  if (index <= 3.5) return '中等风险';
  if (index <= 4.5) return '高风险';
  return '极高风险';
}

/**
 * 获取冒险等级颜色
 * @param index 冒险指数
 */
export function getRiskLevelColor(index: number): string {
  if (index <= 1.5) return '#4CAF50';
  if (index <= 2.5) return '#8BC34A';
  if (index <= 3.5) return '#FF9800';
  if (index <= 4.5) return '#F44336';
  return '#B71C1C';
}

// ===========================================
// 心率计算
// ===========================================

/**
 * 计算最大心率 (220 - 年龄)
 * @param age 年龄
 */
export function calculateMaxHeartRate(age: number): number {
  return 220 - age;
}

/**
 * 计算心率区间边界
 * @param maxHr 最大心率
 */
export function calculateHeartRateZones(maxHr: number): Record<string, { min: number; max: number }> {
  return {
    zone1: { min: Math.round(maxHr * 0.5), max: Math.round(maxHr * 0.6) },
    zone2: { min: Math.round(maxHr * 0.6), max: Math.round(maxHr * 0.7) },
    zone3: { min: Math.round(maxHr * 0.7), max: Math.round(maxHr * 0.8) },
    zone4: { min: Math.round(maxHr * 0.8), max: Math.round(maxHr * 0.9) },
    zone5: { min: Math.round(maxHr * 0.9), max: maxHr },
  };
}

/**
 * 获取心率区间
 * @param hr 心率
 * @param zones 心率区间
 */
export function getHeartRateZone(hr: number, zones: Record<string, { min: number; max: number }>): number {
  for (let i = 1; i <= 5; i++) {
    const zone = zones[`zone${i}`];
    if (hr >= zone.min && hr <= zone.max) {
      return i;
    }
  }
  return hr > zones.zone5.max ? 5 : 1;
}

// ===========================================
// 时间和日期工具
// ===========================================

/**
 * 格式化日期
 * @param date 日期
 * @param format 格式
 */
export function formatDate(date: Date | string, format: string = 'YYYY-MM-DD'): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const year = d.getFullYear();
  const month = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  const hours = d.getHours().toString().padStart(2, '0');
  const minutes = d.getMinutes().toString().padStart(2, '0');
  const seconds = d.getSeconds().toString().padStart(2, '0');

  return format
    .replace('YYYY', year.toString())
    .replace('MM', month)
    .replace('DD', day)
    .replace('HH', hours)
    .replace('mm', minutes)
    .replace('ss', seconds);
}

/**
 * 检查是否为同一天
 */
export function isSameDay(d1: Date, d2: Date): boolean {
  return (
    d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth() &&
    d1.getDate() === d2.getDate()
  );
}

// ===========================================
// ID 生成
// ===========================================

/**
 * 生成唯一ID
 */
export function generateId(): string {
  return `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * 生成骑行记录ID
 */
export function generateRideId(): string {
  return `ride_${generateId()}`;
}

/**
 * 生成轨迹点ID
 */
export function generateTrackPointId(): string {
  return `tp_${generateId()}`;
}

// ===========================================
// 数据验证
// ===========================================

/**
 * 验证坐标有效性
 */
export function isValidCoordinate(coord: Coordinate): boolean {
  return (
    typeof coord.latitude === 'number' &&
    typeof coord.longitude === 'number' &&
    coord.latitude >= -90 &&
    coord.latitude <= 90 &&
    coord.longitude >= -180 &&
    coord.longitude <= 180
  );
}

/**
 * 验证速度有效性
 */
export function isValidSpeed(speed: number): boolean {
  return typeof speed === 'number' && speed >= 0 && speed <= 100; // 最大100 m/s (360 km/h)
}

/**
 * 验证心率有效性
 */
export function isValidHeartRate(hr: number): boolean {
  return typeof hr === 'number' && hr >= 30 && hr <= 220;
}

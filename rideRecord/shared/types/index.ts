/**
 * RideRecord 共享类型定义
 * 用于手机端、手表端、服务端、Web端共享
 */

// ===========================================
// 基础类型
// ===========================================

/** 坐标点 */
export interface Coordinate {
  latitude: number;
  longitude: number;
  altitude?: number;
  timestamp?: number;
}

/** 地理边界 */
export interface BoundingBox {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
}

// ===========================================
// 用户相关类型
// ===========================================

/** 用户信息 */
export interface User {
  id: string;
  nickname: string;
  avatar?: string;
  height?: number;        // 身高 (cm)
  weight?: number;        // 体重 (kg)
  maxHeartRate?: number;  // 最大心率
  createdAt: string;
  updatedAt: string;
}

/** 用户设置 */
export interface UserSettings {
  userId: string;
  // 骑行偏好
  defaultNavigationMode: NavigationMode;
  adventureRatio: number;       // 探险比例 0-1
  maxRiskIndex: number;         // 最大冒险指数 1-5
  unitSystem: 'metric' | 'imperial';
  voiceNavigation: boolean;

  // 动作检测设置
  autoStartStop: boolean;
  detectionSensitivity: 'low' | 'medium' | 'high';
  pauseTimeout: number;         // 暂停超时 (分钟)
  endConfirmMode: 'auto' | 'manual';

  // 同步设置
  cloudSyncEnabled: boolean;
  autoSyncOnWifi: boolean;
  stravaSyncEnabled: boolean;

  // 隐私设置
  hideLocationInShare: boolean;
  hideSpeedInShare: boolean;
}

/** 心率区间配置 */
export interface HeartRateZones {
  zone1: { min: number; max: number };  // 热身区
  zone2: { min: number; max: number };  // 燃脂区
  zone3: { min: number; max: number };  // 有氧区
  zone4: { min: number; max: number };  // 无氧区
  zone5: { min: number; max: number };  // 极限区
}

// ===========================================
// 骑行记录类型
// ===========================================

/** 骑行记录 */
export interface RideRecord {
  id: string;
  userId: string;
  title?: string;
  note?: string;

  // 时间信息
  startTime: string;
  endTime?: string;
  duration: number;         // 总时长 (秒)
  movingTime: number;       // 移动时长 (秒)
  pauseCount: number;       // 暂停次数

  // 距离和速度
  distance: number;         // 总距离 (米)
  avgSpeed: number;         // 平均速度 (m/s)
  maxSpeed: number;         // 最高速度 (m/s)

  // 心率数据
  avgHeartRate?: number;
  maxHeartRate?: number;
  heartRateZones?: HeartRateZoneSummary;

  // 海拔数据
  elevationGain: number;    // 爬升 (米)
  elevationLoss: number;    // 下降 (米)
  minAltitude?: number;
  maxAltitude?: number;

  // 热量消耗
  calories: number;

  // 探险相关
  adventurePercentage?: number;  // 探险路段占比
  avgRiskIndex?: number;         // 平均冒险指数

  // 轨迹信息
  trackPointCount: number;
  trackUrl?: string;        // OBS 存储地址

  // 照片
  photoCount: number;

  // 天气
  weather?: WeatherInfo;

  // 元数据
  deviceId?: string;        // 记录设备ID
  source: 'watch' | 'phone' | 'manual';
  status: RideStatus;

  createdAt: string;
  updatedAt: string;
}

/** 骑行状态 */
export type RideStatus =
  | 'recording'   // 记录中
  | 'paused'      // 已暂停
  | 'completed'   // 已完成
  | 'discarded';  // 已丢弃

/** 心率区间统计 */
export interface HeartRateZoneSummary {
  zone1: number;  // 时间 (秒)
  zone2: number;
  zone3: number;
  zone4: number;
  zone5: number;
}

/** 轨迹点 */
export interface TrackPoint {
  id: string;
  rideId: string;
  timestamp: string;

  // 位置
  latitude: number;
  longitude: number;
  altitude?: number;
  accuracy?: number;  // GPS 精度 (米)

  // 速度
  speed?: number;     // m/s
  bearing?: number;   // 方位角

  // 心率
  heartRate?: number;

  // 其他传感器数据
  cadence?: number;   // 踏频 (RPM)
  power?: number;     // 功率 (瓦特)

  // 状态
  state: 'moving' | 'paused' | 'stopped';
}

/** 路段 */
export interface Segment {
  id: string;
  rideId: string;
  type: 'road' | 'trail' | 'mixed';
  startIndex: number;
  endIndex: number;
  distance: number;
  duration: number;
  avgSpeed: number;
  riskIndex?: number;
  surfaceType?: string;
}

/** 天气信息 */
export interface WeatherInfo {
  temperature: number;  // 温度 (摄氏度)
  humidity: number;     // 湿度 (%)
  windSpeed: number;    // 风速 (m/s)
  windDirection: number; // 风向 (度)
  condition: 'sunny' | 'cloudy' | 'rainy' | 'snowy' | 'foggy';
}

// ===========================================
// 导航相关类型
// ===========================================

/** 导航模式 */
export type NavigationMode = 'road' | 'adventure' | 'mixed';

/** 路线规划请求 */
export interface RoutePlanRequest {
  origin: Coordinate;
  destination: Coordinate;
  waypoints?: Coordinate[];
  mode: NavigationMode;
  adventureRatio?: number;    // 探险比例 0-1
  maxRiskIndex?: number;      // 最大冒险指数 1-5
}

/** 路线 */
export interface Route {
  id: string;
  name?: string;
  distance: number;
  duration: number;
  avgRiskIndex?: number;
  adventurePercentage?: number;
  segments: RouteSegment[];
  instructions: NavigationInstruction[];
}

/** 路线路段 */
export interface RouteSegment {
  type: 'road' | 'trail';
  distance: number;
  duration: number;
  riskIndex?: number;
  surfaceType?: string;
  trafficLevel?: 'low' | 'medium' | 'high';
  coordinates: Coordinate[];
}

/** 导航指令 */
export interface NavigationInstruction {
  type: 'turn_left' | 'turn_right' | 'straight' | 'merge' | 'exit' | 'arrive' | 'warning';
  distance: number;
  text: string;
  coordinate: Coordinate;
  roadName?: string;
}

/** 冒险指数因素 */
export interface RiskFactors {
  surface: number;      // 路面状况 1-5
  slope: number;        // 坡度 1-5
  traffic: number;      // 交通流量 1-5
  signal: number;       // 信号覆盖 1-5
  supply: number;       // 补给距离 1-5
  weather: number;      // 天气条件 1-5
}

// ===========================================
// 传感器数据类型
// ===========================================

/** 传感器数据 */
export interface SensorData {
  timestamp: number;

  // 加速度 (m/s²)
  accX: number;
  accY: number;
  accZ: number;

  // 角速度 (rad/s)
  gyroX: number;
  gyroY: number;
  gyroZ: number;

  // GPS
  latitude?: number;
  longitude?: number;
  altitude?: number;
  speed?: number;
  accuracy?: number;

  // 心率
  heartRate?: number;
}

/** 动作类型 */
export type ActionType =
  | 'MOUNT'      // 上车
  | 'DISMOUNT'   // 下车
  | 'PEDALING'   // 踩踏
  | 'COASTING'   // 滑行
  | 'STOPPED'    // 停止
  | 'OTHER';     // 其他

/** 骑行状态机状态 */
export type RideState =
  | 'IDLE'     // 空闲
  | 'RIDING'   // 骑行中
  | 'PAUSED'   // 暂停
  | 'ENDING';  // 等待确认结束

/** 动作检测结果 */
export interface ActionDetectionResult {
  action: ActionType;
  confidence: number;  // 置信度 0-1
  timestamp: number;
}

// ===========================================
// 同步相关类型
// ===========================================

/** 同步状态 */
export interface SyncStatus {
  lastSyncTime?: string;
  pendingUpload: number;   // 待上传数量
  pendingDownload: number; // 待下载数量
  syncEnabled: boolean;
  lastSyncError?: string;
}

/** 同步记录 */
export interface SyncRecord {
  id: string;
  rideId: string;
  userId: string;
  syncTime: string;
  direction: 'upload' | 'download';
  status: 'pending' | 'success' | 'failed';
  fileSize?: number;
  errorMessage?: string;
}

// ===========================================
// 统计相关类型
// ===========================================

/** 统计概览 */
export interface StatsSummary {
  totalRides: number;
  totalDistance: number;   // 米
  totalDuration: number;   // 秒
  totalCalories: number;
  avgSpeed: number;        // m/s
  maxSpeed: number;        // m/s
  maxDistance: number;     // 单次最长距离
  maxDuration: number;     // 单次最长时间
  totalElevationGain: number;
  adventurePercentage: number;
}

/** 周期统计 */
export interface PeriodStats {
  period: 'day' | 'week' | 'month' | 'year';
  startDate: string;
  endDate: string;
  rides: number;
  distance: number;
  duration: number;
  calories: number;
  avgSpeed: number;
}

// ===========================================
// API 响应类型
// ===========================================

/** API 分页请求 */
export interface PaginationParams {
  page?: number;
  pageSize?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

/** API 分页响应 */
export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

/** API 错误响应 */
export interface ApiError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

// ===========================================
// 设备相关类型
// ===========================================

/** 设备信息 */
export interface Device {
  id: string;
  userId: string;
  name: string;
  type: 'phone' | 'watch';
  model?: string;
  osVersion?: string;
  appVersion?: string;
  lastSyncTime?: string;
  status: 'active' | 'inactive';
  createdAt: string;
}

/** BLE 数据包 */
export interface BleDataPacket {
  type: 'sensor' | 'ride' | 'sync' | 'control';
  sequence: number;
  total: number;
  data: string;  // Base64 编码的数据
  checksum: number;
}

// ===========================================
// 性能监控类型
// ===========================================

/** 性能指标类型 */
export type MetricType =
  | 'startup'       // 启动时间
  | 'memory'        // 内存占用
  | 'battery'       // 电池消耗
  | 'gps'           // GPS精度
  | 'sync'          // 同步延迟
  | 'action'        // 动作检测延迟
  | 'navigation'    // 导航计算时间
  | 'api';          // API响应时间

/** 性能指标单位 */
export type MetricUnit = 'ms' | 'MB' | 'percent' | 'meter' | 'second';

/** 性能指标数据 */
export interface PerformanceMetric {
  id: string;
  type: MetricType;
  platform: 'phone' | 'watch' | 'server' | 'web';
  value: number;
  unit: MetricUnit;
  timestamp: number;
  threshold: number;      // 目标阈值
  passed: boolean;        // 是否达标
  metadata?: Record<string, unknown>;
}

/** NFR 目标配置 */
export interface NfrThreshold {
  id: string;
  type: MetricType;
  platform: ('phone' | 'watch' | 'server' | 'web')[];
  maxValue: number;
  unit: MetricUnit;
  description: string;
}

/** 性能报告 */
export interface PerformanceReport {
  generatedAt: number;
  platform: string;
  version: string;
  metrics: PerformanceMetric[];
  summary: {
    passed: number;
    failed: number;
    total: number;
    passRate: number;
  };
  recommendations: string[];
}

/** Web Vitals 指标 */
export interface WebVitals {
  lcp: number;    // Largest Contentful Paint (ms)
  fid: number;    // First Input Delay (ms)
  cls: number;    // Cumulative Layout Shift
  fcp: number;    // First Contentful Paint (ms)
  ttfb: number;   // Time to First Byte (ms)
}

/** 性能监控配置 */
export interface PerformanceMonitorConfig {
  enabled: boolean;
  samplingInterval: number;   // 采样间隔 (ms)
  reportInterval: number;     // 报告间隔 (ms)
  thresholds: NfrThreshold[];
}

/**
 * RideRecord 共享常量定义
 */

// ===========================================
// 应用信息
// ===========================================

export const APP_NAME = 'RideRecord';
export const APP_VERSION = '0.1.0';

// ===========================================
// 传感器配置
// ===========================================

/** 传感器采样频率 (Hz) */
export const SENSOR_SAMPLING_RATE = {
  ACCELEROMETER: 50,     // 加速度计
  GYROSCOPE: 50,         // 陀螺仪
  GPS: 1,                // GPS
  HEART_RATE: 1,         // 心率
} as const;

/** 数据缓冲窗口大小 (样本数) */
export const SENSOR_WINDOW_SIZE = 250;  // 5秒 * 50Hz

/** 动作检测置信度阈值 */
export const ACTION_DETECTION_THRESHOLD = 0.8;

// ===========================================
// 骑行状态配置
// ===========================================

/** 自动暂停触发条件 */
export const AUTO_PAUSE_CONFIG = {
  SPEED_THRESHOLD: 2,        // 速度阈值 (km/h)
  DURATION_THRESHOLD: 5,     // 持续时间 (秒)
  HEART_RATE_DROP: 10,       // 心率下降幅度
} as const;

/** 自动结束骑行超时时间 (毫秒) */
export const AUTO_END_TIMEOUT = 30 * 60 * 1000;  // 30分钟

/** 开始记录确认超时 (毫秒) */
export const START_CONFIRM_TIMEOUT = 10 * 1000;  // 10秒

// ===========================================
// GPS 配置
// ===========================================

/** GPS 精度阈值 (米) */
export const GPS_ACCURACY_THRESHOLD = 10;

/** GPS 信号丢失恢复时间 (秒) */
export const GPS_RECOVERY_TIME = 30;

/** 轨迹平滑窗口大小 */
export const TRACK_SMOOTHING_WINDOW = 5;

// ===========================================
// 导航配置
// ===========================================

/** 冒险指数权重 */
export const RISK_WEIGHTS = {
  SURFACE: 0.25,      // 路面状况
  SLOPE: 0.20,        // 坡度
  TRAFFIC: 0.15,      // 交通流量
  SIGNAL: 0.15,       // 信号覆盖
  SUPPLY: 0.15,       // 补给距离
  WEATHER: 0.10,      // 天气条件
} as const;

/** 冒险等级范围 */
export const RISK_LEVELS = {
  SAFE: { min: 1.0, max: 1.5, color: '#4CAF50', label: '安全' },
  LOW: { min: 1.5, max: 2.5, color: '#8BC34A', label: '低风险' },
  MEDIUM: { min: 2.5, max: 3.5, color: '#FF9800', label: '中等风险' },
  HIGH: { min: 3.5, max: 4.5, color: '#F44336', label: '高风险' },
  EXTREME: { min: 4.5, max: 5.0, color: '#B71C1C', label: '极高风险' },
} as const;

/** 路面类型 */
export const SURFACE_TYPES = {
  PAVED: { value: 1, label: '铺装路面' },
  GRAVEL: { value: 2, label: '砂石路' },
  DIRT: { value: 3, label: '土路' },
  ROUGH: { value: 4, label: '崎岖路面' },
  VERY_ROUGH: { value: 5, label: '极端崎岖' },
} as const;

// ===========================================
// 心率区间配置
// ===========================================

/** 默认心率区间 (基于最大心率百分比) */
export const DEFAULT_HEART_RATE_ZONES = {
  zone1: { min: 50, max: 60, label: '热身区' },
  zone2: { min: 60, max: 70, label: '燃脂区' },
  zone3: { min: 70, max: 80, label: '有氧区' },
  zone4: { min: 80, max: 90, label: '无氧区' },
  zone5: { min: 90, max: 100, label: '极限区' },
} as const;

/** 默认最大心率计算公式: 220 - 年龄 */
export const MAX_HEART_RATE_FORMULA_AGE = 220;

// ===========================================
// 数据存储配置
// ===========================================

/** 数据库文件名 */
export const DB_FILE_NAME = 'ride_record.db';

/** 轨迹点分表月数间隔 */
export const TRACK_POINT_TABLE_MONTHS = 1;

/** 本地存储配额 (字节) */
export const LOCAL_STORAGE_QUOTA = {
  TRACK_POINTS: 100 * 1024 * 1024,   // 100MB
  PHOTOS: 500 * 1024 * 1024,         // 500MB
  OFFLINE_MAPS: 2 * 1024 * 1024 * 1024,  // 2GB
} as const;

/** 云端存储配额 (字节) */
export const CLOUD_STORAGE_QUOTA = 10 * 1024 * 1024 * 1024;  // 10GB

// ===========================================
// 同步配置
// ===========================================

/** 同步重试次数 */
export const SYNC_MAX_RETRIES = 3;

/** 同步重试间隔 (毫秒) */
export const SYNC_RETRY_INTERVAL = 5000;

/** 上传分块大小 (字节) */
export const UPLOAD_CHUNK_SIZE = 1024 * 1024;  // 1MB

// ===========================================
// BLE 配置
// ===========================================

/** BLE 服务 UUID */
export const BLE_SERVICE_UUID = '0000FFE0-0000-1000-8000-00805F9B34FB';

/** BLE 特征 UUID */
export const BLE_CHARACTERISTIC_UUID = '0000FFE1-0000-1000-8000-00805F9B34FB';

/** BLE MTU 大小 */
export const BLE_MTU_SIZE = 512;

/** BLE 数据包超时 (毫秒) */
export const BLE_PACKET_TIMEOUT = 5000;

/** BLE 重连间隔 (毫秒) */
export const BLE_RECONNECT_INTERVAL = 3000;

/** BLE 最大重连次数 */
export const BLE_MAX_RECONNECT_ATTEMPTS = 5;

// ===========================================
// API 配置
// ===========================================

/** API 基础路径 */
export const API_BASE_PATH = '/v1';

/** API 请求超时 (毫秒) */
export const API_TIMEOUT = 30000;

/** API 分页默认大小 */
export const API_DEFAULT_PAGE_SIZE = 20;

/** API 最大分页大小 */
export const API_MAX_PAGE_SIZE = 100;

// ===========================================
// 性能指标 (NFR)
// ===========================================

/** 性能目标 */
export const PERFORMANCE_TARGETS = {
  APP_START_TIME: 3000,           // 应用启动时间 (毫秒)
  ACTION_DETECTION_DELAY: 3000,   // 动作检测延迟 (毫秒)
  GPS_ACCURACY: 10,               // GPS 精度 (米)
  SYNC_DELAY: 30000,              // 同步延迟 (毫秒)
  ROUTE_CALCULATION: 5000,        // 路线计算时间 (毫秒)
  MEMORY_USAGE: 200,              // 内存占用 (MB)
  BATTERY_USAGE_PHONE: 15,        // 手机电池消耗 (%/小时)
  BATTERY_USAGE_WATCH: 10,        // 手表电池消耗 (%/小时)
} as const;

/** 可靠性目标 */
export const RELIABILITY_TARGETS = {
  CRASH_RATE: 0.001,      // 崩溃率 0.1%
  DATA_LOSS_RATE: 0.0001, // 数据丢失率 0.01%
} as const;

// ===========================================
// UI 配置
// ===========================================

/** 速度单位换算 */
export const SPEED_CONVERSION = {
  MS_TO_KMH: 3.6,     // m/s 到 km/h
  MS_TO_MPH: 2.237,   // m/s 到 mph
} as const;

/** 距离单位换算 */
export const DISTANCE_CONVERSION = {
  M_TO_KM: 0.001,     // 米到公里
  M_TO_MI: 0.000621371,  // 米到英里
} as const;

/** 图表颜色 */
export const CHART_COLORS = {
  PRIMARY: '#2196F3',
  SECONDARY: '#FF9800',
  SUCCESS: '#4CAF50',
  WARNING: '#FFC107',
  DANGER: '#F44336',
  HEART_RATE: '#E91E63',
  SPEED: '#2196F3',
  ELEVATION: '#795548',
} as const;

// ===========================================
// 错误码
// ===========================================

/** 错误码定义 */
export const ERROR_CODES = {
  // 通用错误
  UNKNOWN: 'ERR_UNKNOWN',
  INVALID_PARAM: 'ERR_INVALID_PARAM',
  NOT_FOUND: 'ERR_NOT_FOUND',

  // 认证错误
  UNAUTHORIZED: 'ERR_UNAUTHORIZED',
  TOKEN_EXPIRED: 'ERR_TOKEN_EXPIRED',
  INVALID_TOKEN: 'ERR_INVALID_TOKEN',

  // 骑行记录错误
  RIDE_NOT_FOUND: 'ERR_RIDE_NOT_FOUND',
  RIDE_ALREADY_ENDED: 'ERR_RIDE_ALREADY_ENDED',
  RIDE_IN_PROGRESS: 'ERR_RIDE_IN_PROGRESS',

  // 同步错误
  SYNC_FAILED: 'ERR_SYNC_FAILED',
  NETWORK_ERROR: 'ERR_NETWORK_ERROR',
  STORAGE_FULL: 'ERR_STORAGE_FULL',

  // 设备错误
  DEVICE_NOT_CONNECTED: 'ERR_DEVICE_NOT_CONNECTED',
  SENSOR_ERROR: 'ERR_SENSOR_ERROR',
  GPS_UNAVAILABLE: 'ERR_GPS_UNAVAILABLE',

  // 第三方服务错误
  STRAVA_AUTH_FAILED: 'ERR_STRAVA_AUTH_FAILED',
  WECHAT_SHARE_FAILED: 'ERR_WECHAT_SHARE_FAILED',
} as const;

// ===========================================
// 导出类型
// ===========================================

export type RiskLevelKey = keyof typeof RISK_LEVELS;
export type SurfaceTypeKey = keyof typeof SURFACE_TYPES;
export type ErrorCodeKey = keyof typeof ERROR_CODES;

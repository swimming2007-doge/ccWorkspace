/**
 * 手表端类型定义
 *
 * 包含所有传感器数据、动作检测、骑行状态相关的类型
 */

/**
 * 坐标点
 */
export interface Coordinate {
  latitude: number;      // 纬度
  longitude: number;     // 经度
  altitude?: number;     // 海拔 (米)
  accuracy?: number;     // 精度 (米)
  timestamp?: number;    // 时间戳
}

/**
 * 传感器数据
 */
export interface SensorData {
  timestamp: number;     // 时间戳 (毫秒)
  accX: number;          // 加速度 X (m/s²)
  accY: number;          // 加速度 Y (m/s²)
  accZ: number;          // 加速度 Z (m/s²)
  gyroX: number;         // 角速度 X (rad/s)
  gyroY: number;         // 角速度 Y (rad/s)
  gyroZ: number;         // 角速度 Z (rad/s)
  speed: number;         // 速度 (km/h)
  heartRate: number;     // 心率 (bpm)
}

/**
 * 心率数据
 */
export interface HeartRateData {
  timestamp: number;     // 时间戳 (毫秒)
  heartRate: number;     // 心率 (bpm)
  confidence: number;    // 置信度 (0-1)
}

/**
 * 特征向量
 */
export interface FeatureVector {
  accMagnitude: number;      // 合成加速度均值
  gyroMagnitude: number;     // 合成角速度均值
  accStdDev: number;         // 加速度标准差
  gyroStdDev: number;        // 角速度标准差
  peakCount: number;         // 峰值计数
  zeroCrossingRate: number;  // 过零率
  dominantFreq: number;      // 主频率 (Hz)
  speed: number;             // GPS速度
}

/**
 * 动作类型
 */
export enum ActionType {
  MOUNT = 'MOUNT',           // 上车
  DISMOUNT = 'DISMOUNT',     // 下车
  PEDALING = 'PEDALING',     // 踩踏
  COASTING = 'COASTING',     // 滑行
  STOPPED = 'STOPPED',       // 停止
  OTHER = 'OTHER'            // 其他
}

/**
 * 骑行状态
 */
export enum RideState {
  IDLE = 'IDLE',             // 空闲
  RIDING = 'RIDING',         // 骑行中
  PAUSED = 'PAUSED',         // 暂停
  ENDING = 'ENDING'          // 等待确认结束
}

/**
 * 动作检测结果
 */
export interface ActionDetectionResult {
  timestamp: number;         // 检测时间戳
  action: ActionType;        // 检测到的动作
  confidence: number;        // 置信度 (0-1)
  features: FeatureVector;   // 特征向量
}

/**
 * 状态转换事件
 */
export enum RideEvent {
  RIDE_START = 'RIDE_START',           // 开始骑行
  RIDE_PAUSE = 'RIDE_PAUSE',           // 暂停骑行
  RIDE_RESUME = 'RIDE_RESUME',         // 恢复骑行
  RIDE_END_REQUEST = 'RIDE_END_REQUEST', // 请求结束
  RIDE_END_CONFIRMED = 'RIDE_END_CONFIRMED', // 确认结束
  RIDE_CONTINUE = 'RIDE_CONTINUE'      // 继续骑行
}

/**
 * 状态转换回调
 */
export type StateTransitionCallback = (event: RideEvent) => void;

/**
 * 骑行会话数据
 */
export interface RideSession {
  id: string;                // 会话ID
  startTime: number;         // 开始时间
  endTime?: number;          // 结束时间
  totalDistance: number;     // 总距离 (米)
  totalDuration: number;     // 总时长 (秒)
  movingDuration: number;    // 移动时长 (秒)
  avgSpeed: number;          // 平均速度 (km/h)
  maxSpeed: number;          // 最大速度 (km/h)
  avgHeartRate: number;      // 平均心率
  maxHeartRate: number;      // 最大心率
  calories: number;          // 消耗热量 (kcal)
  elevationGain: number;     // 爬升高度 (米)
  trackPoints: TrackPoint[]; // 轨迹点
}

/**
 * 轨迹点
 */
export interface TrackPoint {
  coordinate: Coordinate;    // 坐标
  timestamp: number;         // 时间戳
  speed?: number;            // 速度
  heartRate?: number;        // 心率
  elevation?: number;        // 海拔
}

/**
 * 动作检测器配置
 */
export interface ActionDetectorConfig {
  windowSize: number;        // 数据窗口大小 (样本数)
  confidenceThreshold: number; // 置信度阈值
  sampleRate: number;        // 采样率 (Hz)
}

/**
 * 决策树节点
 */
export interface DecisionTreeNode {
  feature?: string;          // 特征名称
  threshold?: number;        // 阈值
  left?: DecisionTreeNode;   // 左子节点
  right?: DecisionTreeNode;  // 右子节点
  label?: ActionType;        // 叶节点的标签
}

// ==================== BLE 通信协议 ====================

/**
 * BLE 服务 UUID
 */
export const BLE_SERVICE_UUID = '0000FFE0-0000-1000-8000-00805F9B34FB';

/**
 * BLE 特征 UUID
 */
export const BLE_CHARACTERISTIC_UUID = '0000FFE1-0000-1000-8000-00805F9B34FB';

/**
 * BLE 数据包类型
 */
export enum BlePacketType {
  HEARTBEAT = 0x01,          // 心跳包
  SENSOR_DATA = 0x02,        // 传感器数据
  RIDE_STATE = 0x03,         // 骑行状态
  SYNC_REQUEST = 0x04,       // 同步请求
  SYNC_RESPONSE = 0x05,      // 同步响应
  TRACK_POINT = 0x06,        // 轨迹点
  RIDE_SUMMARY = 0x07,       // 骑行总结
  ACK = 0x08,                // 确认包
  ERROR = 0xFF               // 错误包
}

/**
 * BLE 连接状态
 */
export enum ConnectionState {
  DISCONNECTED = 'DISCONNECTED',
  CONNECTING = 'CONNECTING',
  CONNECTED = 'CONNECTED',
  DISCONNECTING = 'DISCONNECTING'
}

/**
 * BLE 设备信息
 */
export interface BleDeviceInfo {
  deviceId: string;
  deviceName: string;
  rssi: number;
  serviceUuids: string[];
}

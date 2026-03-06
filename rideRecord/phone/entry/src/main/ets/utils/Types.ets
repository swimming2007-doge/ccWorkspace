/**
 * 手机端类型定义
 *
 * 包含BLE通信、骑行数据、传感器数据相关的类型
 */

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
 * BLE 数据包头部
 */
export interface BlePacketHeader {
  type: BlePacketType;       // 包类型
  sequence: number;          // 序列号
  totalLength: number;       // 总长度
  fragmentIndex: number;     // 分片索引
  fragmentTotal: number;     // 总分片数
}

/**
 * BLE 数据包
 */
export interface BlePacket {
  header: BlePacketHeader;
  payload: Uint8Array;
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

// ==================== 骑行状态 ====================

/**
 * 骑行状态
 */
export enum RideState {
  IDLE = 'IDLE',
  RIDING = 'RIDING',
  PAUSED = 'PAUSED',
  ENDING = 'ENDING'
}

/**
 * 骑行事件
 */
export enum RideEvent {
  RIDE_START = 'RIDE_START',
  RIDE_PAUSE = 'RIDE_PAUSE',
  RIDE_RESUME = 'RIDE_RESUME',
  RIDE_END_REQUEST = 'RIDE_END_REQUEST',
  RIDE_END_CONFIRMED = 'RIDE_END_CONFIRMED',
  RIDE_CONTINUE = 'RIDE_CONTINUE'
}

// ==================== 传感器数据 ====================

/**
 * 坐标点
 */
export interface Coordinate {
  latitude: number;
  longitude: number;
  altitude?: number;
  accuracy?: number;
  timestamp?: number;
}

/**
 * 传感器数据（从手表接收）
 */
export interface SensorDataFromWatch {
  timestamp: number;
  heartRate: number;
  speed: number;
  distance: number;
  rideState: string;
}

/**
 * 轨迹点
 */
export interface TrackPoint {
  coordinate: Coordinate;
  timestamp: number;
  speed: number;
  heartRate: number;
  elevation: number;
  distance: number;
}

/**
 * 骑行记录
 */
export interface RideRecord {
  id: string;
  startTime: number;
  endTime: number;
  totalDistance: number;
  totalDuration: number;
  movingDuration: number;
  avgSpeed: number;
  maxSpeed: number;
  avgHeartRate: number;
  maxHeartRate: number;
  calories: number;
  elevationGain: number;
  elevationLoss: number;
  trackPoints: TrackPoint[];
}

/**
 * 骑行统计
 */
export interface RideStatistics {
  totalRides: number;
  totalDistance: number;
  totalDuration: number;
  totalCalories: number;
  avgSpeed: number;
  longestRide: number;
  fastestSpeed: number;
}

// ==================== 用户设置 ====================

/**
 * 用户设置
 */
export interface UserSettings {
  // 个人信息
  nickname: string;
  weight: number;          // kg
  height: number;          // cm
  age: number;
  maxHeartRate: number;

  // 骑行设置
  autoStart: boolean;      // 自动开始
  autoPause: boolean;      // 自动暂停
  voicePrompt: boolean;    // 语音提示

  // 显示设置
  speedUnit: 'km/h' | 'mph';
  distanceUnit: 'km' | 'mile';

  // 同步设置
  autoSync: boolean;
  syncWifiOnly: boolean;

  // 心率区间
  heartRateZones: {
    z1: number;  // 恢复区
    z2: number;  // 有氧区
    z3: number;  // 强化区
    z4: number;  // 阈值区
    z5: number;  // 极限区
  };
}

// ==================== 回调类型 ====================

export type ConnectionCallback = (state: string, device?: BleDeviceInfo) => void;
export type DataReceivedCallback = (data: any) => void;
export type StateChangeCallback = (event: RideEvent) => void;

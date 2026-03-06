/**
 * 手表端 BLE 服务
 *
 * 功能说明：
 * - 作为 BLE 外围设备，等待手机连接
 * - 提供传感器数据服务
 * - 接收手机端指令
 * - 发送骑行数据到手机
 *
 * 技术栈：
 * - @ohos.bluetooth BLE API
 */
import bluetooth from '@ohos.bluetooth';
import hilog from '@ohos.hilog';
import {
  BlePacketType,
  ConnectionState,
  BleDeviceInfo,
  BLE_SERVICE_UUID,
  BLE_CHARACTERISTIC_UUID,
  SensorData,
  RideState
} from '../utils/Types';

const TAG = '[BleService]';
const DOMAIN = 0xFF00;

// 广播配置
const ADVERTISE_NAME = 'RideRecord Watch';
const ADVERTISE_INTERVAL = 160; // 100ms 单位

/**
 * 手表端 BLE 服务类
 */
export class BleService {
  private isAdvertising: boolean = false;
  private isConnected: boolean = false;
  private connectedDeviceId: string = '';
  private sequenceNumber: number = 0;

  // 回调
  private onConnectionCallback?: (connected: boolean, deviceId?: string) => void;
  private onDataCallback?: (type: BlePacketType, data: Uint8Array) => void;

  /**
   * 启动 BLE 服务
   */
  async start(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Starting BLE service');

    try {
      // 启用蓝牙
      await this.enableBluetooth();

      // 开始广播
      await this.startAdvertising();

      // 设置连接状态监听
      this.setupConnectionListener();

      hilog.info(DOMAIN, TAG, 'BLE service started successfully');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start BLE service: %{public}s',
        JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 停止 BLE 服务
   */
  async stop(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Stopping BLE service');

    try {
      // 停止广播
      await this.stopAdvertising();

      // 断开连接
      if (this.isConnected) {
        await this.disconnect();
      }

      hilog.info(DOMAIN, TAG, 'BLE service stopped');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to stop BLE service: %{public}s',
        JSON.stringify(error));
    }
  }

  /**
   * 启用蓝牙
   */
  private async enableBluetooth(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        // 检查蓝牙是否已启用
        const isEnabled = bluetooth.isBluetoothEnabled();
        if (isEnabled) {
          hilog.info(DOMAIN, TAG, 'Bluetooth already enabled');
          resolve();
          return;
        }

        // 请求启用蓝牙
        bluetooth.enableBluetooth();
        setTimeout(() => {
          if (bluetooth.isBluetoothEnabled()) {
            resolve();
          } else {
            reject(new Error('Failed to enable Bluetooth'));
          }
        }, 1000);
      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * 开始广播
   */
  private async startAdvertising(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        // 配置广播参数
        const advertiseData: bluetooth.AdvertiseData = {
          serviceUuids: [BLE_SERVICE_UUID],
          manufactureData: [],
          serviceData: [],
          includeDeviceName: true,
          includeTxPower: false
        };

        const advertiseParams: bluetooth.AdvertiseParams = {
          interval: ADVERTISE_INTERVAL,
          txPower: 0,
          duration: 0  // 持续广播
        };

        // 开始广播
        bluetooth.startAdvertising(advertiseData, advertiseParams, (err) => {
          if (err) {
            hilog.error(DOMAIN, TAG, 'Start advertising failed: %{public}s', JSON.stringify(err));
            reject(err);
            return;
          }
          this.isAdvertising = true;
          hilog.info(DOMAIN, TAG, 'Advertising started');
          resolve();
        });
      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * 停止广播
   */
  private async stopAdvertising(): Promise<void> {
    return new Promise((resolve) => {
      if (!this.isAdvertising) {
        resolve();
        return;
      }

      try {
        bluetooth.stopAdvertising();
        this.isAdvertising = false;
        hilog.info(DOMAIN, TAG, 'Advertising stopped');
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'Stop advertising error: %{public}s', JSON.stringify(error));
      }
      resolve();
    });
  }

  /**
   * 设置连接状态监听
   */
  private setupConnectionListener(): void {
    // 监听 BLE 连接状态变化
    bluetooth.on('bleConnectionStateChange', (data) => {
      hilog.info(DOMAIN, TAG, 'BLE connection state changed: %{public}s', JSON.stringify(data));

      if (data.state === 2) { // 已连接
        this.isConnected = true;
        this.connectedDeviceId = data.deviceId;
        if (this.onConnectionCallback) {
          this.onConnectionCallback(true, data.deviceId);
        }
      } else if (data.state === 0) { // 已断开
        this.isConnected = false;
        const deviceId = this.connectedDeviceId;
        this.connectedDeviceId = '';
        if (this.onConnectionCallback) {
          this.onConnectionCallback(false, deviceId);
        }
      }
    });
  }

  /**
   * 发送传感器数据
   */
  sendSensorData(data: SensorData): void {
    if (!this.isConnected) {
      hilog.warn(DOMAIN, TAG, 'Not connected, cannot send data');
      return;
    }

    // 封装数据
    const payload = this.encodeSensorData(data);
    const packets = this.createPackets(BlePacketType.SENSOR_DATA, payload);

    // 发送数据包
    for (const packet of packets) {
      this.writeCharacteristic(packet);
    }
  }

  /**
   * 发送骑行状态
   */
  sendRideState(state: RideState): void {
    if (!this.isConnected) {
      return;
    }

    const payload = new Uint8Array([this.stateToNumber(state)]);
    const packets = this.createPackets(BlePacketType.RIDE_STATE, payload);

    for (const packet of packets) {
      this.writeCharacteristic(packet);
    }
  }

  /**
   * 发送心跳包
   */
  sendHeartbeat(): void {
    if (!this.isConnected) {
      return;
    }

    const payload = new Uint8Array([0x00]);
    const packets = this.createPackets(BlePacketType.HEARTBEAT, payload);

    for (const packet of packets) {
      this.writeCharacteristic(packet);
    }
  }

  /**
   * 写入特征值
   */
  private writeCharacteristic(data: Uint8Array): void {
    try {
      // 在实际实现中，这里需要使用 GATT 服务写入特征值
      // bluetooth.writeCharacteristicValue(...)
      hilog.debug(DOMAIN, TAG, 'Writing characteristic: %{public}d bytes', data.length);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Write characteristic failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<void> {
    if (!this.isConnected || !this.connectedDeviceId) {
      return;
    }

    try {
      bluetooth.disconnect(this.connectedDeviceId);
      hilog.info(DOMAIN, TAG, 'Disconnected from %{public}s', this.connectedDeviceId);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Disconnect failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 设置连接回调
   */
  onConnection(callback: (connected: boolean, deviceId?: string) => void): void {
    this.onConnectionCallback = callback;
  }

  /**
   * 设置数据接收回调
   */
  onData(callback: (type: BlePacketType, data: Uint8Array) => void): void {
    this.onDataCallback = callback;
  }

  /**
   * 获取连接状态
   */
  getConnectionState(): ConnectionState {
    return this.isConnected ? ConnectionState.CONNECTED : ConnectionState.DISCONNECTED;
  }

  // ==================== 辅助方法 ====================

  /**
   * 编码传感器数据
   */
  private encodeSensorData(data: SensorData): Uint8Array {
    const buffer = new ArrayBuffer(24);
    const view = new DataView(buffer);

    // 时间戳 (4 bytes)
    view.setInt32(0, data.timestamp, true);

    // 心率 (1 byte)
    view.setUint8(4, data.heartRate);

    // 速度 (4 bytes float)
    view.setFloat32(5, data.speed, true);

    // 加速度 X, Y, Z (各 4 bytes float)
    view.setFloat32(9, data.accX, true);
    view.setFloat32(13, data.accY, true);
    view.setFloat32(17, data.accZ, true);

    // 陀螺仪 X (预留)
    view.setFloat32(21, data.gyroX, true);

    return new Uint8Array(buffer);
  }

  /**
   * 创建数据包
   */
  private createPackets(type: BlePacketType, payload: Uint8Array): Uint8Array[] {
    const MTU = 20;
    const HEADER_SIZE = 2;
    const MAX_PAYLOAD = MTU - HEADER_SIZE;

    const packets: Uint8Array[] = [];
    const totalPackets = Math.ceil(payload.length / MAX_PAYLOAD);

    for (let i = 0; i < totalPackets; i++) {
      const start = i * MAX_PAYLOAD;
      const end = Math.min(start + MAX_PAYLOAD, payload.length);
      const chunk = payload.slice(start, end);

      const packet = new Uint8Array(HEADER_SIZE + chunk.length);
      packet[0] = (type & 0x0F) | (0xAA << 4);
      packet[1] = ((this.nextSequence() & 0x0F) << 4) | ((i + 1) & 0x0F);
      packet.set(chunk, 2);

      packets.push(packet);
    }

    return packets;
  }

  /**
   * 获取下一个序列号
   */
  private nextSequence(): number {
    this.sequenceNumber = (this.sequenceNumber + 1) % 16;
    return this.sequenceNumber;
  }

  /**
   * 状态转数字
   */
  private stateToNumber(state: RideState): number {
    switch (state) {
      case RideState.IDLE: return 0;
      case RideState.RIDING: return 1;
      case RideState.PAUSED: return 2;
      case RideState.ENDING: return 3;
      default: return 0;
    }
  }
}

// 导出单例
export default new BleService();

/**
 * 手机端 BLE 客户端
 *
 * 功能说明：
 * - 扫描并连接手表设备
 * - 接收手表传感器数据
 * - 发送控制指令
 * - 处理断线重连
 *
 * 技术栈：
 * - @ohos.bluetooth BLE API
 */
import bluetooth from '@ohos.bluetooth';
import hilog from '@ohos.hilog';
import {
  ConnectionState,
  BleDeviceInfo,
  BlePacketType,
  BLE_SERVICE_UUID,
  BLE_CHARACTERISTIC_UUID,
  SensorDataFromWatch,
  ConnectionCallback,
  DataReceivedCallback
} from '../utils/Types';
import { BleProtocol } from '../utils/BleProtocol';

const TAG = '[BleClient]';
const DOMAIN = 0xFF00;

// 扫描超时
const SCAN_TIMEOUT = 30000; // 30秒
// 重连间隔
const RECONNECT_INTERVAL = 5000; // 5秒
// 最大重连次数
const MAX_RECONNECT_ATTEMPTS = 3;

/**
 * 手机端 BLE 客户端类
 */
export class BleClient {
  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  private connectedDevice: BleDeviceInfo | null = null;
  private scanTimer: number = -1;
  private reconnectAttempts: number = 0;
  private isManualDisconnect: boolean = false;

  // 协议处理器
  private protocol: BleProtocol = new BleProtocol();

  // 回调
  private connectionCallbacks: ConnectionCallback[] = [];
  private dataCallbacks: DataReceivedCallback[] = [];

  /**
   * 开始扫描设备
   */
  async startScan(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Starting BLE scan');

    if (this.connectionState === ConnectionState.CONNECTED) {
      hilog.warn(DOMAIN, TAG, 'Already connected');
      return;
    }

    this.updateConnectionState(ConnectionState.CONNECTING);

    try {
      // 启用蓝牙
      await this.enableBluetooth();

      // 设置扫描过滤器
      const scanFilter: bluetooth.ScanFilter = {
        serviceUuid: BLE_SERVICE_UUID
      };

      // 扫描配置
      const scanOptions: bluetooth.ScanOptions = {
        interval: 500,
        reportDelay: 0,
        dutyMode: bluetooth.ScanDuty.SCAN_MODE_LOW_POWER
      };

      // 开始扫描
      bluetooth.on('bluetoothDeviceFind', (data) => {
        this.onDeviceFound(data);
      });

      bluetooth.startBluetoothDiscovery();

      // 设置扫描超时
      this.scanTimer = setTimeout(() => {
        this.stopScan();
        hilog.warn(DOMAIN, TAG, 'Scan timeout');
      }, SCAN_TIMEOUT);

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Start scan failed: %{public}s', JSON.stringify(error));
      this.updateConnectionState(ConnectionState.DISCONNECTED);
      throw error;
    }
  }

  /**
   * 停止扫描
   */
  async stopScan(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Stopping scan');

    if (this.scanTimer !== -1) {
      clearTimeout(this.scanTimer);
      this.scanTimer = -1;
    }

    try {
      bluetooth.off('bluetoothDeviceFind');
      bluetooth.stopBluetoothDiscovery();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Stop scan error: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 连接设备
   */
  async connect(deviceId: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Connecting to device: %{public}s', deviceId);

    this.updateConnectionState(ConnectionState.CONNECTING);

    try {
      // 设置连接状态监听
      bluetooth.on('bleConnectionStateChange', (data) => {
        this.onConnectionStateChange(data);
      });

      // 发起连接
      bluetooth.connect(deviceId);

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Connect failed: %{public}s', JSON.stringify(error));
      this.updateConnectionState(ConnectionState.DISCONNECTED);
      throw error;
    }
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Disconnecting');

    this.isManualDisconnect = true;

    if (this.connectedDevice) {
      try {
        bluetooth.disconnect(this.connectedDevice.deviceId);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Disconnect failed: %{public}s', JSON.stringify(error));
      }
    }

    this.updateConnectionState(ConnectionState.DISCONNECTED);
    this.connectedDevice = null;
  }

  /**
   * 发送数据
   */
  async sendData(type: BlePacketType, payload: Uint8Array): Promise<void> {
    if (this.connectionState !== ConnectionState.CONNECTED || !this.connectedDevice) {
      hilog.warn(DOMAIN, TAG, 'Not connected, cannot send data');
      return;
    }

    const packets = this.protocol.encapsulate(type, payload);

    for (const packet of packets) {
      await this.writeCharacteristic(packet);
    }
  }

  /**
   * 发送同步请求
   */
  async requestSync(): Promise<void> {
    const payload = new Uint8Array([0x01]);
    await this.sendData(BlePacketType.SYNC_REQUEST, payload);
  }

  /**
   * 发送确认结束
   */
  async confirmRideEnd(): Promise<void> {
    const payload = new Uint8Array([0x01]);
    await this.sendData(BlePacketType.ACK, payload);
  }

  /**
   * 获取连接状态
   */
  getConnectionState(): ConnectionState {
    return this.connectionState;
  }

  /**
   * 获取已连接设备
   */
  getConnectedDevice(): BleDeviceInfo | null {
    return this.connectedDevice;
  }

  /**
   * 注册连接状态回调
   */
  onConnectionStateChange(callback: ConnectionCallback): void {
    this.connectionCallbacks.push(callback);
  }

  /**
   * 注册数据接收回调
   */
  onDataReceived(callback: DataReceivedCallback): void {
    this.dataCallbacks.push(callback);
  }

  // ==================== 私有方法 ====================

  /**
   * 启用蓝牙
   */
  private async enableBluetooth(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        const isEnabled = bluetooth.isBluetoothEnabled();
        if (isEnabled) {
          resolve();
          return;
        }

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
   * 设备发现回调
   */
  private onDeviceFound(data: any): void {
    hilog.debug(DOMAIN, TAG, 'Device found: %{public}s', JSON.stringify(data));

    for (const device of data) {
      // 检查是否是目标设备
      if (this.isTargetDevice(device)) {
        hilog.info(DOMAIN, TAG, 'Target device found: %{public}s', device.deviceName);

        // 停止扫描
        this.stopScan();

        // 自动连接
        this.connect(device.deviceId);
        break;
      }
    }
  }

  /**
   * 检查是否是目标设备
   */
  private isTargetDevice(device: any): boolean {
    // 检查设备名称
    if (device.deviceName && device.deviceName.includes('RideRecord')) {
      return true;
    }

    // 检查服务UUID
    if (device.serviceUuids && device.serviceUuids.includes(BLE_SERVICE_UUID)) {
      return true;
    }

    return false;
  }

  /**
   * 连接状态变化回调
   */
  private onConnectionStateChange(data: any): void {
    hilog.info(DOMAIN, TAG, 'Connection state changed: %{public}s', JSON.stringify(data));

    if (data.state === 2) { // 已连接
      this.onConnected(data.deviceId);
    } else if (data.state === 0) { // 已断开
      this.onDisconnected(data.deviceId);
    }
  }

  /**
   * 连接成功处理
   */
  private onConnected(deviceId: string): void {
    hilog.info(DOMAIN, TAG, 'Connected to device: %{public}s', deviceId);

    this.connectedDevice = {
      deviceId: deviceId,
      deviceName: 'RideRecord Watch',
      rssi: 0,
      serviceUuids: [BLE_SERVICE_UUID]
    };

    this.updateConnectionState(ConnectionState.CONNECTED);
    this.reconnectAttempts = 0;
    this.isManualDisconnect = false;

    // 发现服务
    this.discoverServices(deviceId);
  }

  /**
   * 断开连接处理
   */
  private onDisconnected(deviceId: string): void {
    hilog.info(DOMAIN, TAG, 'Disconnected from device: %{public}s', deviceId);

    this.connectedDevice = null;
    this.updateConnectionState(ConnectionState.DISCONNECTED);

    // 自动重连
    if (!this.isManualDisconnect && this.reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      this.scheduleReconnect();
    }
  }

  /**
   * 发现服务
   */
  private discoverServices(deviceId: string): void {
    try {
      // 发现服务后设置特征通知
      bluetooth.on('BLECharacteristicChange', (data) => {
        this.onCharacteristicChanged(data);
      });

      // 启用通知
      // bluetooth.notifyCharacteristicChanged(...)
      hilog.info(DOMAIN, TAG, 'Services discovered');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Discover services failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 特征值变化回调
   */
  private onCharacteristicChanged(data: any): void {
    hilog.debug(DOMAIN, TAG, 'Characteristic changed: %{public}s', JSON.stringify(data));

    // 解析数据
    const result = this.protocol.decapsulate(new Uint8Array(data.data));

    if (result) {
      this.handleReceivedData(result.type, result.payload);
    }
  }

  /**
   * 处理接收到的数据
   */
  private handleReceivedData(type: BlePacketType, payload: Uint8Array): void {
    hilog.debug(DOMAIN, TAG, 'Received data, type: %{public}d', type);

    let data: any = null;

    switch (type) {
      case BlePacketType.SENSOR_DATA:
        data = this.parseSensorData(payload);
        break;

      case BlePacketType.RIDE_STATE:
        data = this.parseRideState(payload);
        break;

      case BlePacketType.TRACK_POINT:
        data = this.protocol.parseTrackPoint(payload);
        break;

      case BlePacketType.HEARTBEAT:
        data = { timestamp: Date.now() };
        break;
    }

    // 通知回调
    if (data) {
      for (const callback of this.dataCallbacks) {
        callback({ type, data });
      }
    }
  }

  /**
   * 写入特征值
   */
  private async writeCharacteristic(data: Uint8Array): Promise<void> {
    if (!this.connectedDevice) {
      return;
    }

    try {
      // 在实际实现中，这里需要写入特征值
      // bluetooth.writeCharacteristicValue(...)
      hilog.debug(DOMAIN, TAG, 'Write characteristic: %{public}d bytes', data.length);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Write characteristic failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 安排重连
   */
  private scheduleReconnect(): void {
    this.reconnectAttempts++;
    hilog.info(DOMAIN, TAG, 'Scheduling reconnect, attempt %{public}d', this.reconnectAttempts);

    setTimeout(() => {
      if (this.connectionState === ConnectionState.DISCONNECTED) {
        this.startScan();
      }
    }, RECONNECT_INTERVAL);
  }

  /**
   * 更新连接状态
   */
  private updateConnectionState(state: ConnectionState): void {
    this.connectionState = state;

    for (const callback of this.connectionCallbacks) {
      callback(state, this.connectedDevice || undefined);
    }
  }

  /**
   * 解析传感器数据
   */
  private parseSensorData(payload: Uint8Array): SensorDataFromWatch | null {
    if (payload.length < 16) {
      return null;
    }

    const dataView = new DataView(payload.buffer, payload.byteOffset);

    return {
      timestamp: dataView.getInt32(0, true),
      heartRate: payload[4],
      speed: dataView.getFloat32(5, true),
      distance: dataView.getFloat32(9, true),
      rideState: payload[13].toString()
    };
  }

  /**
   * 解析骑行状态
   */
  private parseRideState(payload: Uint8Array): any {
    if (payload.length < 1) {
      return null;
    }

    const stateMap = ['IDLE', 'RIDING', 'PAUSED', 'ENDING'];
    return {
      state: stateMap[payload[0]] || 'IDLE'
    };
  }
}

export default new BleClient();

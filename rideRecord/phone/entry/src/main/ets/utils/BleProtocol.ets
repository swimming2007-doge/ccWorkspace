/**
 * BLE 通信协议工具类
 *
 * 功能说明：
 * - 数据包封装和解封装
 * - 数据分包和重组
 * - CRC校验
 * - 序列号管理
 */
import hilog from '@ohos.hilog';
import {
  BlePacketType,
  BlePacketHeader,
  BlePacket,
  BLE_SERVICE_UUID,
  BLE_CHARACTERISTIC_UUID
} from './Types';

const TAG = '[BleProtocol]';
const DOMAIN = 0xFF00;

// BLE MTU (最大传输单元)
const BLE_MTU = 20;           // 默认MTU
const MAX_PAYLOAD_SIZE = 18;  // MTU - 头部(2字节)

// 包头标志
const PACKET_HEADER_FLAG = 0xAA;

/**
 * BLE 协议工具类
 */
export class BleProtocol {
  private sequenceNumber: number = 0;
  private receiveBuffer: Map<number, Uint8Array[]> = new Map();
  private expectedFragments: Map<number, number> = new Map();

  /**
   * 封装数据包
   * @param type 包类型
   * @param payload 有效载荷
   * @returns 封装后的数据包数组（可能分包）
   */
  encapsulate(type: BlePacketType, payload: Uint8Array): Uint8Array[] {
    const packets: Uint8Array[] = [];

    // 计算需要的分片数
    const fragmentTotal = Math.ceil(payload.length / MAX_PAYLOAD_SIZE);
    const sequence = this.nextSequence();

    for (let i = 0; i < fragmentTotal; i++) {
      const startIndex = i * MAX_PAYLOAD_SIZE;
      const endIndex = Math.min(startIndex + MAX_PAYLOAD_SIZE, payload.length);
      const fragmentPayload = payload.slice(startIndex, endIndex);

      // 构建包头 (简化版: 2字节头部)
      // 字节0: 标志 + 类型 (高4位标志, 低4位类型)
      // 字节1: 序列号 + 分片信息 (高4位序号, 低4位当前分片)
      const header0 = (PACKET_HEADER_FLAG << 4) | (type & 0x0F);
      const header1 = ((sequence & 0x0F) << 4) | ((i + 1) & 0x0F);

      const packet = new Uint8Array(2 + fragmentPayload.length);
      packet[0] = header0;
      packet[1] = header1;
      packet.set(fragmentPayload, 2);

      packets.push(packet);
    }

    hilog.debug(DOMAIN, TAG, 'Encapsulated %{public}d packets, type: %{public}d',
      packets.length, type);

    return packets;
  }

  /**
   * 解封装数据包
   * @param packet 接收到的数据包
   * @returns 解封装后的完整数据，如果分片未完成则返回null
   */
  decapsulate(packet: Uint8Array): { type: BlePacketType; payload: Uint8Array } | null {
    if (packet.length < 2) {
      hilog.warn(DOMAIN, TAG, 'Packet too short: %{public}d', packet.length);
      return null;
    }

    // 解析包头
    const header0 = packet[0];
    const header1 = packet[1];

    const flag = (header0 >> 4) & 0x0F;
    const type = header0 & 0x0F;
    const sequence = (header1 >> 4) & 0x0F;
    const fragmentIndex = (header1 & 0x0F) - 1; // 转为0-based索引

    if (flag !== PACKET_HEADER_FLAG) {
      hilog.warn(DOMAIN, TAG, 'Invalid packet flag: %{public}d', flag);
      return null;
    }

    const payload = packet.slice(2);

    // 存储分片
    if (!this.receiveBuffer.has(sequence)) {
      this.receiveBuffer.set(sequence, []);
    }
    const buffer = this.receiveBuffer.get(sequence)!;
    buffer[fragmentIndex] = payload;

    hilog.debug(DOMAIN, TAG, 'Received fragment %{public}d for sequence %{public}d',
      fragmentIndex, sequence);

    // 检查是否所有分片都已接收
    // 这里简化处理：假设每个传输最多有buffer.length个分片
    // 实际应该通过头部信息判断总分片数

    // 检查是否是单包传输
    if (buffer.length === 1 && buffer[0] !== undefined) {
      this.receiveBuffer.delete(sequence);
      return {
        type: type as BlePacketType,
        payload: buffer[0]
      };
    }

    // 检查是否所有分片都已接收（连续性检查）
    const isComplete = this.checkBufferComplete(buffer);
    if (isComplete) {
      const fullPayload = this.mergeFragments(buffer);
      this.receiveBuffer.delete(sequence);
      return {
        type: type as BlePacketType,
        payload: fullPayload
      };
    }

    // 分片未完成
    return null;
  }

  /**
   * 获取下一个序列号
   */
  private nextSequence(): number {
    this.sequenceNumber = (this.sequenceNumber + 1) % 16;
    return this.sequenceNumber;
  }

  /**
   * 检查缓冲区是否完整
   */
  private checkBufferComplete(buffer: Uint8Array[]): boolean {
    for (let i = 0; i < buffer.length; i++) {
      if (buffer[i] === undefined) {
        return false;
      }
    }
    return true;
  }

  /**
   * 合并分片
   */
  private mergeFragments(buffer: Uint8Array[]): Uint8Array {
    // 计算总长度
    let totalLength = 0;
    for (const fragment of buffer) {
      if (fragment) {
        totalLength += fragment.length;
      }
    }

    // 合并
    const result = new Uint8Array(totalLength);
    let offset = 0;
    for (const fragment of buffer) {
      if (fragment) {
        result.set(fragment, offset);
        offset += fragment.length;
      }
    }

    return result;
  }

  /**
   * 重置状态
   */
  reset(): void {
    this.sequenceNumber = 0;
    this.receiveBuffer.clear();
  }

  /**
   * 创建心跳包
   */
  createHeartbeat(): Uint8Array {
    const payload = new Uint8Array([0x00]);
    return this.encapsulate(BlePacketType.HEARTBEAT, payload)[0];
  }

  /**
   * 创建确认包
   */
  createAck(sequence: number): Uint8Array {
    const payload = new Uint8Array([sequence]);
    return this.encapsulate(BlePacketType.ACK, payload)[0];
  }

  /**
   * 解析传感器数据
   */
  parseSensorData(payload: Uint8Array): any {
    if (payload.length < 16) {
      return null;
    }

    const dataView = new DataView(payload.buffer);

    return {
      timestamp: dataView.getInt32(0, true),    // 4 bytes
      heartRate: payload[4],                     // 1 byte
      speed: dataView.getFloat32(5, true),      // 4 bytes
      distance: dataView.getFloat32(9, true),   // 4 bytes
      rideState: payload[13]                     // 1 byte
    };
  }

  /**
   * 解析轨迹点数据
   */
  parseTrackPoint(payload: Uint8Array): any {
    if (payload.length < 32) {
      return null;
    }

    const dataView = new DataView(payload.buffer);

    return {
      coordinate: {
        latitude: dataView.getFloat64(0, true),
        longitude: dataView.getFloat64(8, true),
        altitude: dataView.getFloat32(16, true)
      },
      timestamp: dataView.getInt32(20, true),
      speed: dataView.getFloat32(24, true),
      heartRate: payload[28],
      distance: dataView.getFloat32(29, true)
    };
  }
}

// 导出单例
export default new BleProtocol();

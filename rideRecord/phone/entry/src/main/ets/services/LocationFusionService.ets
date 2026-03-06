/**
 * GPS信号丢失处理和数据融合服务
 *
 * 功能说明：
 * - GPS信号状态监测
 * - 信号丢失时的位置估计
 * - 手机+手表GPS数据融合
 * - 网络定位备选
 */
import hilog from '@ohos.hilog';
import { Coordinate, TrackPoint } from '../utils/Types';

const TAG = '[SignalLostHandler]';
const DOMAIN = 0xFF00;

// 信号丢失阈值
const SIGNAL_LOST_THRESHOLD = 15000; // 15秒无有效GPS视为信号丢失
const MAX_EXTRAPOLATION_COUNT = 5; // 最大外推次数

/**
 * 信号状态
 */
export enum SignalStatus {
  GOOD = 'GOOD',           // GPS正常
  DEGRADED = 'DEGRADED',   // GPS降级
  LOST = 'LOST'            // GPS丢失
}

/**
 * 数据源
 */
export enum DataSource {
  PHONE_GPS = 'PHONE_GPS',
  WATCH_GPS = 'WATCH_GPS',
  FUSED = 'FUSED',
  EXTRAPOLATED = 'EXTRAPOLATED',
  NETWORK = 'NETWORK'
}

/**
 * 融合位置数据
 */
export interface FusedLocation {
  coordinate: Coordinate;
  timestamp: number;
  accuracy: number;
  source: DataSource;
  confidence: number; // 0-1
}

/**
 * 数据源位置数据
 */
export interface SourceLocation {
  coordinate: Coordinate;
  timestamp: number;
  accuracy: number;
  source: DataSource;
}

/**
 * GPS信号丢失处理和数据融合类
 */
export class SignalLostHandler {
  // 信号状态
  private signalStatus: SignalStatus = SignalStatus.GOOD;
  private lastValidTime: number = 0;
  private extrapolationCount: number = 0;

  // 历史数据用于外推
  private recentLocations: TrackPoint[] = [];
  private maxHistorySize: number = 10;

  // 速度和方向估计
  private estimatedSpeed: number = 0;
  private estimatedBearing: number = 0;

  // 数据源权重
  private readonly PHONE_GPS_WEIGHT = 0.6;
  private readonly WATCH_GPS_WEIGHT = 0.4;

  /**
   * 处理新的位置数据
   */
  processLocation(location: TrackPoint, source: DataSource): FusedLocation {
    const now = Date.now();

    // 更新信号状态
    this.lastValidTime = now;
    this.extrapolationCount = 0;
    this.signalStatus = SignalStatus.GOOD;

    // 更新历史数据
    this.updateHistory(location);

    // 更新速度和方向估计
    this.updateEstimates();

    return {
      coordinate: location.coordinate,
      timestamp: location.timestamp,
      accuracy: location.coordinate.accuracy ?? 10,
      source: source,
      confidence: this.calculateConfidence(location.coordinate.accuracy ?? 10)
    };
  }

  /**
   * 融合手机和手表GPS数据
   */
  fuseLocations(phoneLocation: SourceLocation | null, watchLocation: SourceLocation | null): FusedLocation | null {
    if (!phoneLocation && !watchLocation) {
      return null;
    }

    if (!phoneLocation) {
      return {
        ...watchLocation!,
        confidence: this.calculateConfidence(watchLocation!.accuracy) * this.WATCH_GPS_WEIGHT
      };
    }

    if (!watchLocation) {
      return {
        ...phoneLocation,
        confidence: this.calculateConfidence(phoneLocation!.accuracy) * this.PHONE_GPS_WEIGHT
      };
    }

    // 加权融合
    const phoneWeight = this.PHONE_GPS_WEIGHT / (phoneLocation.accuracy + 1);
    const watchWeight = this.WATCH_GPS_WEIGHT / (watchLocation.accuracy + 1);
    const totalWeight = phoneWeight + watchWeight;

    const fusedLat = (phoneLocation.coordinate.latitude * phoneWeight +
      watchLocation.coordinate.latitude * watchWeight) / totalWeight;

    const fusedLon = (phoneLocation.coordinate.longitude * phoneWeight +
      watchLocation.coordinate.longitude * watchWeight) / totalWeight;

    const fusedAlt = ((phoneLocation.coordinate.altitude ?? 0) * phoneWeight +
      (watchLocation.coordinate.altitude ?? 0) * watchWeight) / totalWeight;

    // 融合后的精度估算
    const fusedAccuracy = Math.sqrt(
      (phoneLocation.accuracy * phoneWeight / totalWeight) ** 2 +
      (watchLocation.accuracy * watchWeight / totalWeight) ** 2
    );

    return {
      coordinate: {
        latitude: fusedLat,
        longitude: fusedLon,
        altitude: fusedAlt,
        accuracy: fusedAccuracy,
        timestamp: Date.now()
      },
      timestamp: Date.now(),
      accuracy: fusedAccuracy,
      source: DataSource.FUSED,
      confidence: this.calculateConfidence(fusedAccuracy)
    };
  }

  /**
   * 处理信号丢失情况
   */
  handleSignalLost(): FusedLocation | null {
    const now = Date.now();
    const timeSinceLastValid = now - this.lastValidTime;

    // 检查信号状态
    if (timeSinceLastValid > SIGNAL_LOST_THRESHOLD) {
      if (this.signalStatus !== SignalStatus.LOST) {
        this.signalStatus = SignalStatus.LOST;
        hilog.warn(DOMAIN, TAG, 'GPS signal lost');
      }
    } else if (timeSinceLastValid > SIGNAL_LOST_THRESHOLD / 2) {
      this.signalStatus = SignalStatus.DEGRADED;
    }

    // 尝试外推位置
    if (this.extrapolationCount < MAX_EXTRAPOLATION_COUNT && this.recentLocations.length >= 2) {
      this.extrapolationCount++;
      const extrapolated = this.extrapolatePosition();

      if (extrapolated) {
        hilog.info(DOMAIN, TAG, 'Extrapolated position, count: %{public}d', this.extrapolationCount);
        return extrapolated;
      }
    }

    return null;
  }

  /**
   * 外推位置
   */
  private extrapolatePosition(): FusedLocation | null {
    if (this.recentLocations.length < 2) {
      return null;
    }

    const last = this.recentLocations[this.recentLocations.length - 1];
    const now = Date.now();
    const timeDiff = (now - last.timestamp) / 1000; // 秒

    // 根据速度和方向外推
    const distance = this.estimatedSpeed * timeDiff; // 米

    // 将距离转换为经纬度偏移
    const earthRadius = 6371000; // 米
    const latRad = last.coordinate.latitude * Math.PI / 180;
    const bearingRad = this.estimatedBearing * Math.PI / 180;

    const deltaLat = distance * Math.cos(bearingRad) / earthRadius;
    const deltaLon = distance * Math.sin(bearingRad) / (earthRadius * Math.cos(latRad));

    const newLat = last.coordinate.latitude + deltaLat * 180 / Math.PI;
    const newLon = last.coordinate.longitude + deltaLon * 180 / Math.PI;

    // 精度随外推次数增加而降低
    const extrapolatedAccuracy = 20 + this.extrapolationCount * 10;

    return {
      coordinate: {
        latitude: newLat,
        longitude: newLon,
        altitude: last.coordinate.altitude,
        accuracy: extrapolatedAccuracy,
        timestamp: now
      },
      timestamp: now,
      accuracy: extrapolatedAccuracy,
      source: DataSource.EXTRAPOLATED,
      confidence: Math.max(0.1, 0.5 - this.extrapolationCount * 0.1)
    };
  }

  /**
   * 获取当前信号状态
   */
  getSignalStatus(): SignalStatus {
    return this.signalStatus;
  }

  /**
   * 检查是否需要网络定位
   */
  needsNetworkLocation(): boolean {
    return this.signalStatus === SignalStatus.LOST ||
      this.extrapolationCount >= MAX_EXTRAPOLATION_COUNT;
  }

  /**
   * 使用网络定位作为备选
   */
  useNetworkLocation(networkLocation: Coordinate): FusedLocation {
    return {
      coordinate: networkLocation,
      timestamp: Date.now(),
      accuracy: networkLocation.accuracy ?? 1000,
      source: DataSource.NETWORK,
      confidence: 0.2
    };
  }

  // ==================== 私有方法 ====================

  /**
   * 更新历史数据
   */
  private updateHistory(location: TrackPoint): void {
    this.recentLocations.push(location);
    if (this.recentLocations.length > this.maxHistorySize) {
      this.recentLocations.shift();
    }
  }

  /**
   * 更新速度和方向估计
   */
  private updateEstimates(): void {
    if (this.recentLocations.length < 2) {
      return;
    }

    const last = this.recentLocations[this.recentLocations.length - 1];
    const prev = this.recentLocations[this.recentLocations.length - 2];

    // 计算速度
    const distance = this.calculateDistance(prev.coordinate, last.coordinate);
    const timeDiff = (last.timestamp - prev.timestamp) / 1000;

    if (timeDiff > 0) {
      this.estimatedSpeed = distance / timeDiff; // m/s
    }

    // 计算方向
    this.estimatedBearing = this.calculateBearing(prev.coordinate, last.coordinate);
  }

  /**
   * 计算两点间距离
   */
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

  /**
   * 计算方位角
   */
  private calculateBearing(p1: Coordinate, p2: Coordinate): number {
    const lat1 = p1.latitude * Math.PI / 180;
    const lat2 = p2.latitude * Math.PI / 180;
    const deltaLon = (p2.longitude - p1.longitude) * Math.PI / 180;

    const y = Math.sin(deltaLon) * Math.cos(lat2);
    const x = Math.cos(lat1) * Math.sin(lat2) -
      Math.sin(lat1) * Math.cos(lat2) * Math.cos(deltaLon);

    const bearing = Math.atan2(y, x) * 180 / Math.PI;
    return (bearing + 360) % 360;
  }

  /**
   * 计算置信度
   */
  private calculateConfidence(accuracy: number): number {
    // 精度越好，置信度越高
    if (accuracy <= 5) return 0.95;
    if (accuracy <= 10) return 0.85;
    if (accuracy <= 20) return 0.7;
    if (accuracy <= 50) return 0.5;
    return 0.3;
  }

  /**
   * 重置状态
   */
  reset(): void {
    this.signalStatus = SignalStatus.GOOD;
    this.lastValidTime = 0;
    this.extrapolationCount = 0;
    this.recentLocations = [];
    this.estimatedSpeed = 0;
    this.estimatedBearing = 0;
  }
}

// 导出单例
export default new SignalLostHandler();

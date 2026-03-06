/**
 * 骑行记录存储服务
 *
 * 功能说明：
 * - 骑行记录 CRUD 操作
 * - 轨迹点存储优化 (按月分表)
 * - 照片存储管理
 * - 数据统计查询
 *
 * 依赖：
 * - DatabaseService: 数据库操作
 */
import relationalStore from '@ohos.data.relationalStore';
import hilog from '@ohos.hilog';
import { TrackPoint, RideRecord } from '../utils/Types';
import DatabaseService from './DatabaseService';

const TAG = '[RideStorageService]';
const DOMAIN = 0xFF00;

/**
 * 骑行记录数据库模型
 */
export interface RideRecordEntity {
  id: string;
  user_id: string;
  title: string | null;
  note: string | null;
  start_time: string;
  end_time: string | null;
  duration: number;
  moving_time: number;
  distance: number;
  avg_speed: number;
  max_speed: number;
  avg_heart_rate: number | null;
  max_heart_rate: number | null;
  hr_zone1_time: number;
  hr_zone2_time: number;
  hr_zone3_time: number;
  hr_zone4_time: number;
  hr_zone5_time: number;
  elevation_gain: number;
  elevation_loss: number;
  min_altitude: number | null;
  max_altitude: number | null;
  calories: number;
  track_point_count: number;
  status: string;
  created_at: string;
  updated_at: string;
}

/**
 * 轨迹点数据库模型
 */
export interface TrackPointEntity {
  id: string;
  ride_id: string;
  timestamp: string;
  latitude: number;
  longitude: number;
  altitude: number | null;
  accuracy: number | null;
  speed: number | null;
  bearing: number | null;
  heart_rate: number | null;
  state: string;
  created_at: string;
}

/**
 * 查询选项
 */
export interface RideQueryOptions {
  userId?: string;
  status?: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
  offset?: number;
  orderBy?: string;
  orderDirection?: 'ASC' | 'DESC';
}

/**
 * 骑行统计
 */
export interface RideSummary {
  totalRides: number;
  totalDistance: number;
  totalDuration: number;
  totalMovingTime: number;
  totalCalories: number;
  totalElevationGain: number;
  avgSpeed: number;
  maxSpeed: number;
  longestRide: number;
}

/**
 * 骑行记录存储服务类
 */
export class RideStorageService {
  // 默认用户ID (单用户模式)
  private readonly DEFAULT_USER_ID = 'default_user';

  /**
   * 保存骑行记录
   */
  async saveRide(ride: RideRecord): Promise<string> {
    const now = new Date().toISOString();

    // 插入骑行记录
    const rideValues: relationalStore.ValuesBucket = {
      id: ride.id,
      user_id: this.DEFAULT_USER_ID,
      title: null,
      note: null,
      start_time: new Date(ride.startTime).toISOString(),
      end_time: new Date(ride.endTime).toISOString(),
      duration: ride.totalDuration,
      moving_time: ride.movingDuration,
      distance: ride.totalDistance,
      avg_speed: ride.avgSpeed,
      max_speed: ride.maxSpeed,
      avg_heart_rate: ride.avgHeartRate || null,
      max_heart_rate: ride.maxHeartRate || null,
      hr_zone1_time: 0,
      hr_zone2_time: 0,
      hr_zone3_time: 0,
      hr_zone4_time: 0,
      hr_zone5_time: 0,
      elevation_gain: ride.elevationGain,
      elevation_loss: ride.elevationLoss,
      min_altitude: null,
      max_altitude: null,
      calories: ride.calories,
      track_point_count: ride.trackPoints.length,
      status: 'completed',
      created_at: now,
      updated_at: now
    };

    await DatabaseService.insert('rides', rideValues);

    // 保存轨迹点
    if (ride.trackPoints.length > 0) {
      await this.saveTrackPoints(ride.id, ride.trackPoints);
    }

    hilog.info(DOMAIN, TAG, 'Ride saved: %{public}s, track points: %{public}d',
      ride.id, ride.trackPoints.length);

    return ride.id;
  }

  /**
   * 批量保存轨迹点
   */
  async saveTrackPoints(rideId: string, trackPoints: TrackPoint[]): Promise<void> {
    if (trackPoints.length === 0) return;

    // 确定使用的表名 (按月分表)
    const firstPoint = trackPoints[0];
    const date = new Date(firstPoint.timestamp);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const tableName = `track_points_${year}${String(month).padStart(2, '0')}`;

    // 确保表存在
    await DatabaseService.createTrackPointsTable(year, month);

    // 准备批量插入数据
    const valuesList: relationalStore.ValuesBucket[] = [];
    const now = new Date().toISOString();

    for (const point of trackPoints) {
      const values: relationalStore.ValuesBucket = {
        id: this.generateId(),
        ride_id: rideId,
        timestamp: new Date(point.timestamp).toISOString(),
        latitude: point.coordinate.latitude,
        longitude: point.coordinate.longitude,
        altitude: point.elevation || null,
        accuracy: point.coordinate.accuracy || null,
        speed: point.speed || null,
        bearing: null,
        heart_rate: point.heartRate || null,
        state: 'moving',
        created_at: now
      };
      valuesList.push(values);
    }

    // 批量插入
    try {
      await DatabaseService.batchInsert(tableName, valuesList);
      hilog.info(DOMAIN, TAG, 'Track points saved: %{public}d to %{public}s',
        valuesList.length, tableName);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to save track points: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 获取骑行记录列表
   */
  async getRides(options?: RideQueryOptions): Promise<RideRecordEntity[]> {
    const predicates = new relationalStore.RdbPredicates('rides');

    if (options?.userId) {
      predicates.equalTo('user_id', options.userId);
    } else {
      predicates.equalTo('user_id', this.DEFAULT_USER_ID);
    }

    if (options?.status) {
      predicates.equalTo('status', options.status);
    }

    if (options?.startDate) {
      predicates.greaterThanOrEqualTo('start_time', options.startDate);
    }

    if (options?.endDate) {
      predicates.lessThanOrEqualTo('end_time', options.endDate);
    }

    const orderBy = options?.orderBy || 'start_time';
    const orderDirection = options?.orderDirection || 'DESC';
    predicates.orderByDesc(orderBy);

    if (options?.limit) {
      predicates.limitAs(options.limit);
    }

    if (options?.offset) {
      predicates.offsetAs(options.offset);
    }

    const resultSet = await DatabaseService.query(predicates);
    const rides: RideRecordEntity[] = [];

    try {
      while (resultSet.goToNextRow()) {
        rides.push(this.parseRideRecord(resultSet));
      }
    } finally {
      resultSet.close();
    }

    return rides;
  }

  /**
   * 获取单个骑行记录
   */
  async getRideById(rideId: string): Promise<RideRecordEntity | null> {
    const predicates = new relationalStore.RdbPredicates('rides');
    predicates.equalTo('id', rideId);

    const resultSet = await DatabaseService.query(predicates);

    try {
      if (resultSet.goToNextRow()) {
        return this.parseRideRecord(resultSet);
      }
    } finally {
      resultSet.close();
    }

    return null;
  }

  /**
   * 获取骑行轨迹点
   */
  async getTrackPoints(rideId: string): Promise<TrackPointEntity[]> {
    // 查询骑行记录获取时间范围
    const ride = await this.getRideById(rideId);
    if (!ride) {
      return [];
    }

    const startTime = new Date(ride.start_time);
    const endTime = new Date(ride.end_time || ride.start_time);

    // 可能涉及多个月份的表
    const trackPoints: TrackPointEntity[] = [];

    let currentDate = new Date(startTime.getFullYear(), startTime.getMonth(), 1);
    const endDate = new Date(endTime.getFullYear(), endTime.getMonth(), 1);

    while (currentDate <= endDate) {
      const year = currentDate.getFullYear();
      const month = currentDate.getMonth() + 1;
      const tableName = `track_points_${year}${String(month).padStart(2, '0')}`;

      const sql = `SELECT * FROM ${tableName} WHERE ride_id = ? ORDER BY timestamp ASC`;
      const resultSet = await DatabaseService.querySql(sql, [rideId]);

      try {
        while (resultSet.goToNextRow()) {
          trackPoints.push(this.parseTrackPoint(resultSet));
        }
      } finally {
        resultSet.close();
      }

      // 移动到下个月
      currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1);
    }

    return trackPoints;
  }

  /**
   * 更新骑行记录
   */
  async updateRide(rideId: string, updates: Partial<RideRecordEntity>): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('rides');
    predicates.equalTo('id', rideId);

    const values: relationalStore.ValuesBucket = {
      ...updates,
      updated_at: new Date().toISOString()
    };

    await DatabaseService.update('rides', values, predicates);
    hilog.info(DOMAIN, TAG, 'Ride updated: %{public}s', rideId);
  }

  /**
   * 删除骑行记录
   */
  async deleteRide(rideId: string): Promise<void> {
    // 删除骑行记录 (级联删除轨迹点)
    const predicates = new relationalStore.RdbPredicates('rides');
    predicates.equalTo('id', rideId);

    await DatabaseService.delete('rides', predicates);
    hilog.info(DOMAIN, TAG, 'Ride deleted: %{public}s', rideId);
  }

  /**
   * 获取骑行统计
   */
  async getRideSummary(options?: RideQueryOptions): Promise<RideSummary> {
    const rides = await this.getRides(options);

    const summary: RideSummary = {
      totalRides: rides.length,
      totalDistance: 0,
      totalDuration: 0,
      totalMovingTime: 0,
      totalCalories: 0,
      totalElevationGain: 0,
      avgSpeed: 0,
      maxSpeed: 0,
      longestRide: 0
    };

    if (rides.length === 0) {
      return summary;
    }

    for (const ride of rides) {
      summary.totalDistance += ride.distance;
      summary.totalDuration += ride.duration;
      summary.totalMovingTime += ride.moving_time;
      summary.totalCalories += ride.calories;
      summary.totalElevationGain += ride.elevation_gain;

      if (ride.max_speed > summary.maxSpeed) {
        summary.maxSpeed = ride.max_speed;
      }

      if (ride.distance > summary.longestRide) {
        summary.longestRide = ride.distance;
      }
    }

    // 计算平均速度
    if (summary.totalMovingTime > 0) {
      summary.avgSpeed = (summary.totalDistance / 1000) / (summary.totalMovingTime / 3600);
    }

    return summary;
  }

  /**
   * 获取最近骑行
   */
  async getRecentRides(limit: number = 10): Promise<RideRecordEntity[]> {
    return this.getRides({
      status: 'completed',
      limit,
      orderBy: 'start_time',
      orderDirection: 'DESC'
    });
  }

  /**
   * 按月获取统计
   */
  async getMonthlyStats(year: number, month: number): Promise<RideSummary> {
    const startDate = new Date(year, month - 1, 1).toISOString();
    const endDate = new Date(year, month, 0, 23, 59, 59).toISOString();

    return this.getRideSummary({
      startDate,
      endDate,
      status: 'completed'
    });
  }

  // ==================== 私有方法 ====================

  /**
   * 解析骑行记录
   */
  private parseRideRecord(resultSet: relationalStore.ResultSet): RideRecordEntity {
    return {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      user_id: resultSet.getString(resultSet.getColumnIndex('user_id')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      note: resultSet.getString(resultSet.getColumnIndex('note')),
      start_time: resultSet.getString(resultSet.getColumnIndex('start_time')),
      end_time: resultSet.getString(resultSet.getColumnIndex('end_time')),
      duration: resultSet.getLong(resultSet.getColumnIndex('duration')),
      moving_time: resultSet.getLong(resultSet.getColumnIndex('moving_time')),
      distance: resultSet.getDouble(resultSet.getColumnIndex('distance')),
      avg_speed: resultSet.getDouble(resultSet.getColumnIndex('avg_speed')),
      max_speed: resultSet.getDouble(resultSet.getColumnIndex('max_speed')),
      avg_heart_rate: resultSet.isColumnNull(resultSet.getColumnIndex('avg_heart_rate'))
        ? null : resultSet.getLong(resultSet.getColumnIndex('avg_heart_rate')),
      max_heart_rate: resultSet.isColumnNull(resultSet.getColumnIndex('max_heart_rate'))
        ? null : resultSet.getLong(resultSet.getColumnIndex('max_heart_rate')),
      hr_zone1_time: resultSet.getLong(resultSet.getColumnIndex('hr_zone1_time')),
      hr_zone2_time: resultSet.getLong(resultSet.getColumnIndex('hr_zone2_time')),
      hr_zone3_time: resultSet.getLong(resultSet.getColumnIndex('hr_zone3_time')),
      hr_zone4_time: resultSet.getLong(resultSet.getColumnIndex('hr_zone4_time')),
      hr_zone5_time: resultSet.getLong(resultSet.getColumnIndex('hr_zone5_time')),
      elevation_gain: resultSet.getDouble(resultSet.getColumnIndex('elevation_gain')),
      elevation_loss: resultSet.getDouble(resultSet.getColumnIndex('elevation_loss')),
      min_altitude: resultSet.isColumnNull(resultSet.getColumnIndex('min_altitude'))
        ? null : resultSet.getDouble(resultSet.getColumnIndex('min_altitude')),
      max_altitude: resultSet.isColumnNull(resultSet.getColumnIndex('max_altitude'))
        ? null : resultSet.getDouble(resultSet.getColumnIndex('max_altitude')),
      calories: resultSet.getLong(resultSet.getColumnIndex('calories')),
      track_point_count: resultSet.getLong(resultSet.getColumnIndex('track_point_count')),
      status: resultSet.getString(resultSet.getColumnIndex('status')),
      created_at: resultSet.getString(resultSet.getColumnIndex('created_at')),
      updated_at: resultSet.getString(resultSet.getColumnIndex('updated_at'))
    };
  }

  /**
   * 解析轨迹点
   */
  private parseTrackPoint(resultSet: relationalStore.ResultSet): TrackPointEntity {
    return {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      ride_id: resultSet.getString(resultSet.getColumnIndex('ride_id')),
      timestamp: resultSet.getString(resultSet.getColumnIndex('timestamp')),
      latitude: resultSet.getDouble(resultSet.getColumnIndex('latitude')),
      longitude: resultSet.getDouble(resultSet.getColumnIndex('longitude')),
      altitude: resultSet.isColumnNull(resultSet.getColumnIndex('altitude'))
        ? null : resultSet.getDouble(resultSet.getColumnIndex('altitude')),
      accuracy: resultSet.isColumnNull(resultSet.getColumnIndex('accuracy'))
        ? null : resultSet.getDouble(resultSet.getColumnIndex('accuracy')),
      speed: resultSet.isColumnNull(resultSet.getColumnIndex('speed'))
        ? null : resultSet.getDouble(resultSet.getColumnIndex('speed')),
      bearing: resultSet.isColumnNull(resultSet.getColumnIndex('bearing'))
        ? null : resultSet.getDouble(resultSet.getColumnIndex('bearing')),
      heart_rate: resultSet.isColumnNull(resultSet.getColumnIndex('heart_rate'))
        ? null : resultSet.getLong(resultSet.getColumnIndex('heart_rate')),
      state: resultSet.getString(resultSet.getColumnIndex('state')),
      created_at: resultSet.getString(resultSet.getColumnIndex('created_at'))
    };
  }

  /**
   * 生成唯一ID
   */
  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substring(2, 9);
  }
}

// 导出单例
export default new RideStorageService();

/**
 * 同步服务
 *
 * 功能说明：
 * - 骑行数据上传处理
 * - 增量同步
 * - 断点续传管理
 * - 同步状态管理
 */

import { SyncDAO, RideDAO } from '../db/dao';
import obsService from './obs.service';
import { v4 as uuidv4 } from 'uuid';

// 上传数据结构
interface RideUploadData {
  ride: {
    id: string;
    title: string | null;
    note: string | null;
    startTime: string;
    endTime: string | null;
    duration: number;
    movingTime: number;
    distance: number;
    avgSpeed: number;
    maxSpeed: number;
    avgHeartRate: number | null;
    maxHeartRate: number | null;
    hrZone1Time: number;
    hrZone2Time: number;
    hrZone3Time: number;
    hrZone4Time: number;
    hrZone5Time: number;
    elevationGain: number;
    elevationLoss: number;
    calories: number;
    trackPointCount: number;
  };
  trackPoints: Array<{
    timestamp: string;
    latitude: number;
    longitude: number;
    altitude: number | null;
    speed: number | null;
    heartRate: number | null;
  }>;
  metadata: {
    appVersion: string;
    platform: string;
    uploadedAt: string;
  };
}

// 同步结果
interface SyncUploadResult {
  syncId: string;
  rideId: string;
  obsKey: string;
  size: number;
}

// 分片上传状态
interface MultipartUploadState {
  uploadId: string;
  key: string;
  parts: Array<{ partNumber: number; etag: string }>;
  totalSize: number;
  uploadedSize: number;
}

// 活跃的分片上传
const activeUploads = new Map<string, MultipartUploadState>();

/**
 * 同步服务类
 */
export class SyncService {
  /**
   * 上传骑行数据
   */
  async uploadRide(userId: string, data: RideUploadData): Promise<SyncUploadResult> {
    const rideId = data.ride.id;
    const syncId = uuidv4();

    // 1. 创建同步记录
    await SyncDAO.createWithUser(userId, {
      rideId,
      direction: 'upload',
      status: 'pending',
    });

    try {
      // 2. 序列化数据
      const jsonData = JSON.stringify(data);
      const buffer = Buffer.from(jsonData);
      const size = buffer.length;

      // 3. 上传到OBS
      const obsKey = `rides/${userId}/${rideId}.json`;
      const uploadResult = await obsService.upload({
        key: obsKey,
        body: buffer,
        contentType: 'application/json',
        metadata: {
          'user-id': userId,
          'ride-id': rideId,
          'sync-id': syncId,
          'uploaded-at': new Date().toISOString()
        }
      });

      // 4. 存储到数据库
      await this.storeRideData(userId, data);

      // 5. 更新同步状态
      await SyncDAO.markSuccess(syncId);
      await RideDAO.markSynced(rideId);

      return {
        syncId,
        rideId,
        obsKey,
        size
      };

    } catch (error) {
      // 标记失败
      await SyncDAO.markFailed(syncId, error instanceof Error ? error.message : String(error));
      throw error;
    }
  }

  /**
   * 初始化分片上传
   */
  async initMultipartUpload(userId: string, rideId: string): Promise<{ uploadId: string; key: string }> {
    const key = `rides/${userId}/${rideId}.json`;
    const uploadId = await obsService.initMultipartUpload(key, {
      'user-id': userId,
      'ride-id': rideId
    });

    // 保存状态
    activeUploads.set(uploadId, {
      uploadId,
      key,
      parts: [],
      totalSize: 0,
      uploadedSize: 0
    });

    return { uploadId, key };
  }

  /**
   * 上传分片
   */
  async uploadPart(
    uploadId: string,
    partNumber: number,
    data: Buffer
  ): Promise<{ etag: string; partNumber: number }> {
    const state = activeUploads.get(uploadId);
    if (!state) {
      throw new Error('Upload not found');
    }

    const result = await obsService.uploadPart(state.key, uploadId, partNumber, data);

    // 更新状态
    state.parts.push({
      partNumber: result.partNumber,
      etag: result.etag
    });
    state.uploadedSize += data.length;

    return result;
  }

  /**
   * 完成分片上传
   */
  async completeMultipartUpload(
    userId: string,
    rideId: string,
    uploadId: string
  ): Promise<SyncUploadResult> {
    const state = activeUploads.get(uploadId);
    if (!state) {
      throw new Error('Upload not found');
    }

    const syncId = uuidv4();

    try {
      // 完成OBS上传
      const result = await obsService.completeMultipartUpload(
        state.key,
        uploadId,
        state.parts
      );

      // 创建同步记录
      await SyncDAO.createWithUser(userId, {
        rideId,
        direction: 'upload',
        status: 'pending',
      });

      // 更新同步状态
      await SyncDAO.markSuccess(syncId);
      await RideDAO.markSynced(rideId);

      // 清理状态
      activeUploads.delete(uploadId);

      return {
        syncId,
        rideId,
        obsKey: state.key,
        size: state.uploadedSize
      };

    } catch (error) {
      await SyncDAO.markFailed(syncId, error instanceof Error ? error.message : String(error));
      activeUploads.delete(uploadId);
      throw error;
    }
  }

  /**
   * 获取增量同步数据
   */
  async getIncrementalSync(
    userId: string,
    lastSyncTime: Date,
    options?: { limit?: number }
  ): Promise<{
    rides: RideUploadData[];
    hasMore: boolean;
    nextSyncTime: string;
  }> {
    const limit = options?.limit || 50;

    // 查询更新的记录
    const rides = await RideDAO.findByUserId(userId, {
      updatedAfter: lastSyncTime,
      limit: limit + 1
    });

    const hasMore = rides.length > limit;
    const ridesToReturn = hasMore ? rides.slice(0, limit) : rides;

    // 转换为上传数据格式
    const rideDataList: RideUploadData[] = [];

    for (const ride of ridesToReturn) {
      // 获取轨迹点
      const trackPoints = await RideDAO.getTrackPoints(ride.id);

      rideDataList.push({
        ride: {
          id: ride.id,
          title: ride.title,
          note: ride.note,
          startTime: ride.startTime.toISOString(),
          endTime: ride.endTime?.toISOString() || null,
          duration: ride.duration,
          movingTime: ride.movingTime,
          distance: ride.distance,
          avgSpeed: ride.avgSpeed,
          maxSpeed: ride.maxSpeed,
          avgHeartRate: ride.avgHeartRate,
          maxHeartRate: ride.maxHeartRate,
          hrZone1Time: ride.hrZone1Time,
          hrZone2Time: ride.hrZone2Time,
          hrZone3Time: ride.hrZone3Time,
          hrZone4Time: ride.hrZone4Time,
          hrZone5Time: ride.hrZone5Time,
          elevationGain: ride.elevationGain,
          elevationLoss: ride.elevationLoss,
          calories: ride.calories,
          trackPointCount: ride.trackPointCount
        },
        trackPoints: trackPoints.map(tp => ({
          timestamp: tp.timestamp.toISOString(),
          latitude: tp.latitude,
          longitude: tp.longitude,
          altitude: tp.altitude,
          speed: tp.speed,
          heartRate: tp.heartRate
        })),
        metadata: {
          appVersion: '0.1.0',
          platform: 'server',
          uploadedAt: new Date().toISOString()
        }
      });
    }

    const nextSyncTime = ridesToReturn.length > 0
      ? ridesToReturn[ridesToReturn.length - 1].updatedAt.toISOString()
      : new Date().toISOString();

    return {
      rides: rideDataList,
      hasMore,
      nextSyncTime
    };
  }

  /**
   * 获取签名下载URL
   */
  getDownloadUrl(rideId: string, userId: string): string {
    const key = `rides/${userId}/${rideId}.json`;
    return obsService.getSignedUrl(key, 3600);
  }

  /**
   * 存储骑行数据到数据库
   */
  private async storeRideData(userId: string, data: RideUploadData): Promise<void> {
    // 检查是否存在
    const existing = await RideDAO.findById(data.ride.id);

    if (existing) {
      // 更新
      await RideDAO.update(data.ride.id, {
        title: data.ride.title,
        note: data.ride.note,
        distance: data.ride.distance,
        duration: data.ride.duration,
        movingTime: data.ride.movingTime,
        avgSpeed: data.ride.avgSpeed,
        maxSpeed: data.ride.maxSpeed,
        avgHeartRate: data.ride.avgHeartRate,
        maxHeartRate: data.ride.maxHeartRate,
        calories: data.ride.calories,
        elevationGain: data.ride.elevationGain,
        elevationLoss: data.ride.elevationLoss,
        synced: true
      });
    } else {
      // 创建
      await RideDAO.create({
        id: data.ride.id,
        userId,
        startTime: new Date(data.ride.startTime),
        endTime: data.ride.endTime ? new Date(data.ride.endTime) : null,
        duration: data.ride.duration,
        movingTime: data.ride.movingTime,
        distance: data.ride.distance,
        avgSpeed: data.ride.avgSpeed,
        maxSpeed: data.ride.maxSpeed,
        avgHeartRate: data.ride.avgHeartRate,
        maxHeartRate: data.ride.maxHeartRate,
        hrZone1Time: data.ride.hrZone1Time,
        hrZone2Time: data.ride.hrZone2Time,
        hrZone3Time: data.ride.hrZone3Time,
        hrZone4Time: data.ride.hrZone4Time,
        hrZone5Time: data.ride.hrZone5Time,
        elevationGain: data.ride.elevationGain,
        elevationLoss: data.ride.elevationLoss,
        calories: data.ride.calories,
        trackPointCount: data.ride.trackPointCount,
        synced: true
      });
    }

    // 存储轨迹点
    if (data.trackPoints.length > 0) {
      await RideDAO.insertTrackPoints(
        data.ride.id,
        data.trackPoints.map(tp => ({
          timestamp: new Date(tp.timestamp),
          latitude: tp.latitude,
          longitude: tp.longitude,
          altitude: tp.altitude,
          speed: tp.speed,
          heartRate: tp.heartRate
        }))
      );
    }
  }

  /**
   * 清理过期的分片上传
   */
  async cleanupExpiredUploads(): Promise<void> {
    // 清理超过24小时的上传
    const maxAge = 24 * 60 * 60 * 1000;
    const now = Date.now();

    for (const [uploadId, state] of activeUploads.entries()) {
      // 假设我们存储了开始时间，这里简化处理
      // 实际应该从数据库查询
    }
  }
}

// 导出单例
export const syncService = new SyncService();
export default syncService;

import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import { uploadRateLimiter } from '../middleware/rate-limit.middleware';
import { ApiError } from '../middleware/error.middleware';
import { SyncDAO, RideDAO } from '../db/dao';
import syncService from '../services/sync.service';

const router = Router();

// ===========================================
// Validation Schemas
// ===========================================

const syncUploadSchema = z.object({
  rideId: z.string(),
  ride: z.object({
    id: z.string(),
    title: z.string().nullable(),
    note: z.string().nullable(),
    startTime: z.string(),
    endTime: z.string().nullable(),
    duration: z.number(),
    movingTime: z.number(),
    distance: z.number(),
    avgSpeed: z.number(),
    maxSpeed: z.number(),
    avgHeartRate: z.number().nullable(),
    maxHeartRate: z.number().nullable(),
    hrZone1Time: z.number(),
    hrZone2Time: z.number(),
    hrZone3Time: z.number(),
    hrZone4Time: z.number(),
    hrZone5Time: z.number(),
    elevationGain: z.number(),
    elevationLoss: z.number(),
    calories: z.number(),
    trackPointCount: z.number(),
  }),
  trackPoints: z.array(z.object({
    timestamp: z.string(),
    latitude: z.number(),
    longitude: z.number(),
    altitude: z.number().nullable(),
    speed: z.number().nullable(),
    heartRate: z.number().nullable(),
  })),
  metadata: z.object({
    appVersion: z.string(),
    platform: z.string(),
    uploadedAt: z.string(),
  }),
});

const multipartInitSchema = z.object({
  rideId: z.string(),
  totalSize: z.number().optional(),
});

const uploadPartSchema = z.object({
  uploadId: z.string(),
  partNumber: z.number().int().min(1).max(10000),
});

const completeMultipartSchema = z.object({
  uploadId: z.string(),
  rideId: z.string(),
});

const incrementalSyncSchema = z.object({
  lastSyncTime: z.string().optional(),
  limit: z.number().int().min(1).max(100).optional(),
});

// ===========================================
// Routes
// ===========================================

/**
 * @swagger
 * /sync/status:
 *   get:
 *     summary: Get sync status
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Sync status retrieved
 */
router.get('/status', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const stats = await SyncDAO.getStats(req.user!.id);
    const pendingRides = await RideDAO.findPendingSync(10);

    // 获取最近同步时间
    const recentSyncs = await SyncDAO.findByUserId(req.user!.id, { take: 1 });
    const lastSyncTime = recentSyncs.length > 0 ? recentSyncs[0].createdAt : null;

    res.json({
      sync: {
        pendingUploads: stats.pending,
        completedSyncs: stats.success,
        failedSyncs: stats.failed,
        lastSyncTime,
      },
      pendingRides: pendingRides.slice(0, 5).map(r => ({
        id: r.id,
        startTime: r.startTime,
        distance: r.distance,
        duration: r.duration,
      })),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/upload:
 *   post:
 *     summary: Upload ride data
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               rideId:
 *                 type: string
 *               ride:
 *                 type: object
 *               trackPoints:
 *                 type: array
 *               metadata:
 *                 type: object
 *     responses:
 *       200:
 *         description: Upload successful
 */
router.post('/upload', authenticate, uploadRateLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = syncUploadSchema.parse(req.body);

    // 调用同步服务上传
    const result = await syncService.uploadRide(req.user!.id, data as any);

    res.json({
      message: 'Upload successful',
      syncId: result.syncId,
      rideId: result.rideId,
      size: result.size,
      obsKey: result.obsKey,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/multipart/init:
 *   post:
 *     summary: Initialize multipart upload
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               rideId:
 *                 type: string
 *               totalSize:
 *                 type: number
 *     responses:
 *       200:
 *         description: Multipart upload initialized
 */
router.post('/multipart/init', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { rideId } = multipartInitSchema.parse(req.body);

    const result = await syncService.initMultipartUpload(req.user!.id, rideId);

    res.json({
      uploadId: result.uploadId,
      key: result.key,
      message: 'Multipart upload initialized',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/multipart/part:
 *   put:
 *     summary: Upload a part
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/octet-stream:
 *           schema:
 *             type: string
 *             format: binary
 *     parameters:
 *       - in: query
 *         name: uploadId
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: partNumber
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Part uploaded
 */
router.put('/multipart/part', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { uploadId, partNumber } = uploadPartSchema.parse(req.query);

    // 获取请求体数据
    const chunks: Buffer[] = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    const data = Buffer.concat(chunks);

    const result = await syncService.uploadPart(uploadId, partNumber, data);

    res.json({
      etag: result.etag,
      partNumber: result.partNumber,
      size: data.length,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/multipart/complete:
 *   post:
 *     summary: Complete multipart upload
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               uploadId:
 *                 type: string
 *               rideId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Multipart upload completed
 */
router.post('/multipart/complete', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { uploadId, rideId } = completeMultipartSchema.parse(req.body);

    const result = await syncService.completeMultipartUpload(req.user!.id, rideId, uploadId);

    res.json({
      message: 'Multipart upload completed',
      syncId: result.syncId,
      rideId: result.rideId,
      size: result.size,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/incremental:
 *   get:
 *     summary: Get incremental sync data
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: lastSyncTime
 *         schema:
 *           type: string
 *           format: date-time
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *     responses:
 *       200:
 *         description: Incremental sync data
 */
router.get('/incremental', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { lastSyncTime, limit } = incrementalSyncSchema.parse(req.query);

    const lastSync = lastSyncTime ? new Date(lastSyncTime) : new Date(0);

    const result = await syncService.getIncrementalSync(req.user!.id, lastSync, {
      limit: limit || 50
    });

    res.json({
      rides: result.rides,
      hasMore: result.hasMore,
      nextSyncTime: result.nextSyncTime,
      count: result.rides.length,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/download/{rideId}:
 *   get:
 *     summary: Get download URL for a ride
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: rideId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Download URL generated
 */
router.get('/download/:rideId', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { rideId } = req.params;

    // 验证权限
    const ride = await RideDAO.findById(rideId);
    if (!ride) {
      throw ApiError.notFound('Ride not found');
    }

    if (ride.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    const downloadUrl = syncService.getDownloadUrl(rideId, req.user!.id);

    res.json({
      downloadUrl,
      expiresIn: 3600,
      rideId,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/history:
 *   get:
 *     summary: Get sync history
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: pageSize
 *         schema:
 *           type: integer
 *           default: 20
 *     responses:
 *       200:
 *         description: Sync history retrieved
 */
router.get('/history', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { page = 1, pageSize = 20 } = req.query;
    const skip = (Number(page) - 1) * Number(pageSize);

    const records = await SyncDAO.findByUserId(req.user!.id, {
      skip,
      take: Number(pageSize),
    });

    res.json({
      data: records.map(r => ({
        id: r.id,
        rideId: r.rideId,
        direction: r.direction,
        status: r.status,
        errorMessage: r.errorMessage,
        createdAt: r.createdAt,
        completedAt: r.completedAt,
      })),
      page: Number(page),
      pageSize: Number(pageSize),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/batch:
 *   post:
 *     summary: Batch sync rides
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               rideIds:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: Batch sync results
 */
router.post('/batch', authenticate, uploadRateLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { rideIds } = req.body;

    if (!Array.isArray(rideIds) || rideIds.length === 0) {
      throw ApiError.badRequest('rideIds must be a non-empty array');
    }

    if (rideIds.length > 100) {
      throw ApiError.badRequest('Maximum 100 rides per batch');
    }

    const results = [];

    for (const rideId of rideIds) {
      try {
        // 获取骑行数据
        const ride = await RideDAO.findById(rideId);
        if (!ride) {
          results.push({ rideId, success: false, error: 'Ride not found' });
          continue;
        }

        // 检查权限
        if (ride.userId !== req.user!.id) {
          results.push({ rideId, success: false, error: 'Access denied' });
          continue;
        }

        // 获取轨迹点
        const trackPoints = await RideDAO.getTrackPoints(rideId);

        // 上传
        const uploadData = {
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
            trackPointCount: ride.trackPointCount,
          },
          trackPoints: trackPoints.map(tp => ({
            timestamp: tp.timestamp.toISOString(),
            latitude: tp.latitude,
            longitude: tp.longitude,
            altitude: tp.altitude,
            speed: tp.speed,
            heartRate: tp.heartRate,
          })),
          metadata: {
            appVersion: '0.1.0',
            platform: 'server',
            uploadedAt: new Date().toISOString(),
          },
        };

        const result = await syncService.uploadRide(req.user!.id, uploadData as any);
        results.push({ rideId, success: true, syncId: result.syncId });

      } catch (error) {
        results.push({
          rideId,
          success: false,
          error: error instanceof Error ? error.message : String(error)
        });
      }
    }

    const successCount = results.filter(r => r.success).length;

    res.json({
      message: `Batch sync completed: ${successCount}/${rideIds.length} successful`,
      results,
      summary: {
        total: rideIds.length,
        successful: successCount,
        failed: rideIds.length - successCount,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/strava:
 *   post:
 *     summary: Sync ride to Strava
 *   tags: [Sync]
 *   security:
 *     - bearerAuth: []
 */
router.post('/strava', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { rideId } = req.body;

    if (!rideId) {
      throw ApiError.badRequest('rideId is required');
    }

    // TODO: Implement Strava sync
    res.json({
      message: 'Strava sync not yet implemented',
      rideId,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/wechat/share:
 *   post:
 *     summary: Share ride to WeChat
 *   tags: [Sync]
 *   security:
 *     - bearerAuth: []
 */
router.post('/wechat/share', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { rideId, shareType = 'friend' };

    if (!rideId) {
      throw ApiError.badRequest('rideId is required');
    }

    // TODO: Implement WeChat share
    res.json({
      message: 'WeChat share not yet implemented',
      rideId,
      shareType,
    });
  } catch (error) {
    next(error);
  }
});

export default router;

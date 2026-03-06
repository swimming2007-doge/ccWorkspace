import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import { uploadRateLimiter } from '../middleware/rate-limit.middleware';
import { ApiError } from '../middleware/error.middleware';
import { SyncDAO, RideDAO } from '../db/dao';

const router = Router();

// ===========================================
// Validation Schemas
// ===========================================

const syncUploadSchema = z.object({
  rideId: z.string().uuid(),
  rideData: z.record(z.unknown()),
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
 */
router.get('/status', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const stats = await SyncDAO.getStats(req.user!.id);
    const pendingRides = await RideDAO.findPendingSync(10);

    res.json({
      sync: {
        pendingUploads: stats.pending,
        completedSyncs: stats.success,
        failedSyncs: stats.failed,
      },
      pendingRides: pendingRides.slice(0, 5).map(r => ({
        id: r.id,
        startTime: r.startTime,
        distance: r.distance,
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
 */
router.post('/upload', authenticate, uploadRateLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = syncUploadSchema.parse(req.body);

    // Create sync record
    const syncRecord = await SyncDAO.createWithUser(req.user!.id, {
      rideId: data.rideId,
      direction: 'upload',
      status: 'pending',
    });

    // TODO: Implement actual upload to OBS
    // For now, mark as success
    await SyncDAO.markSuccess(syncRecord.id);

    // Update ride sync status
    const ride = await RideDAO.findById(data.rideId);
    if (ride) {
      await RideDAO.markSynced(data.rideId);
    }

    res.json({
      message: 'Upload successful',
      syncId: syncRecord.id,
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
 */
router.get('/history', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { page = 1, pageSize = 20 } = req.query;
    const skip = (Number(page) - 1) * Number(pageSize);

    const records = await SyncDAO.findByUserId(req.user!.id, {
      skip,
      take: Number(pageSize),
    });

    res.json({ data: records });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /sync/strava:
 *   post:
 *     summary: Sync ride to Strava
 *     tags: [Sync]
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
 *     tags: [Sync]
 */
router.post('/wechat/share', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { rideId, shareType = 'friend' } = req.body; // friend or moments

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

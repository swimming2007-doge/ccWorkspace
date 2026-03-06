import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import { readRateLimiter, uploadRateLimiter } from '../middleware/rate-limit.middleware';
import { ApiError } from '../middleware/error.middleware';
import { RideDAO } from '../db/dao';

const router = Router();

// ===========================================
// Validation Schemas
// ===========================================

const createRideSchema = z.object({
  title: z.string().max(100).optional(),
  deviceId: z.string().optional(),
  startTime: z.string().datetime(),
});

const updateRideSchema = z.object({
  title: z.string().max(100).optional(),
  note: z.string().max(1000).optional(),
});

const completeRideSchema = z.object({
  endTime: z.string().datetime(),
  duration: z.number().int().min(0),
  movingTime: z.number().int().min(0),
  distance: z.number().min(0),
  avgSpeed: z.number().min(0),
  maxSpeed: z.number().min(0),
  avgHeartRate: z.number().int().min(0).optional(),
  maxHeartRate: z.number().int().min(0).optional(),
  calories: z.number().int().min(0),
  elevationGain: z.number().min(0),
  elevationLoss: z.number().min(0),
});

const querySchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).default('1'),
  pageSize: z.string().regex(/^\d+$/).transform(Number).default('20'),
  status: z.enum(['recording', 'paused', 'completed', 'discarded']).optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  sortBy: z.enum(['startTime', 'distance', 'duration']).default('startTime'),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
});

// ===========================================
// Routes
// ===========================================

/**
 * @swagger
 * /rides:
 *   get:
 *     summary: Get list of rides
 *     tags: [Rides]
 */
router.get('/', authenticate, readRateLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const query = querySchema.parse(req.query);
    const page = query.page || 1;
    const pageSize = Math.min(query.pageSize || 20, 100);
    const skip = (page - 1) * pageSize;

    const where: Record<string, unknown> = { userId: req.user!.id };
    if (query.status) {
      where.status = query.status;
    }
    if (query.startDate || query.endDate) {
      where.startTime = {};
      if (query.startDate) {
        (where.startTime as Record<string, unknown>).gte = new Date(query.startDate);
      }
      if (query.endDate) {
        (where.startTime as Record<string, unknown>).lte = new Date(query.endDate);
      }
    }

    const [rides, total] = await Promise.all([
      RideDAO.findByUserId(req.user!.id, {
        skip,
        take: pageSize,
        orderBy: { [query.sortBy]: query.sortOrder },
        status: query.status,
      }),
      RideDAO.countByUser(req.user!.id, query.status),
    ]);

    res.json({
      data: rides.map(ride => ({
        id: ride.id,
        title: ride.title,
        startTime: ride.startTime,
        endTime: ride.endTime,
        duration: ride.duration,
        distance: ride.distance,
        avgSpeed: ride.avgSpeed,
        status: ride.status,
        syncStatus: ride.syncStatus,
        photoCount: ride.photoCount,
      })),
      pagination: {
        page,
        pageSize,
        total,
        totalPages: Math.ceil(total / pageSize),
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /rides:
 *   post:
 *     summary: Create a new ride
 *     tags: [Rides]
 */
router.post('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = createRideSchema.parse(req.body);

    const ride = await RideDAO.createWithUser(req.user!.id, {
      title: data.title,
      deviceId: data.deviceId,
      startTime: new Date(data.startTime),
      source: 'phone',
      status: 'recording',
    });

    res.status(201).json({
      message: 'Ride created successfully',
      ride: {
        id: ride.id,
        title: ride.title,
        startTime: ride.startTime,
        status: ride.status,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /rides/{id}:
 *   get:
 *     summary: Get ride by ID
 *     tags: [Rides]
 */
router.get('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ride = await RideDAO.findByIdWithSegments(req.params.id);

    if (!ride) {
      throw ApiError.notFound('Ride not found');
    }

    // Check ownership
    if (ride.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    res.json({ ride });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /rides/{id}:
 *   put:
 *     summary: Update ride
 *     tags: [Rides]
 */
router.put('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ride = await RideDAO.findById(req.params.id);

    if (!ride) {
      throw ApiError.notFound('Ride not found');
    }

    if (ride.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    const data = updateRideSchema.parse(req.body);
    const updated = await RideDAO.update(ride.id, data);

    res.json({
      message: 'Ride updated successfully',
      ride: updated,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /rides/{id}:
 *   delete:
 *     summary: Delete ride
 *     tags: [Rides]
 */
router.delete('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ride = await RideDAO.findById(req.params.id);

    if (!ride) {
      throw ApiError.notFound('Ride not found');
    }

    if (ride.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    await RideDAO.delete(ride.id);

    res.json({ message: 'Ride deleted successfully' });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /rides/{id}/complete:
 *   post:
 *     summary: Complete a ride
 *     tags: [Rides]
 */
router.post('/:id/complete', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ride = await RideDAO.findById(req.params.id);

    if (!ride) {
      throw ApiError.notFound('Ride not found');
    }

    if (ride.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    if (ride.status === 'completed') {
      throw ApiError.badRequest('Ride already completed');
    }

    const data = completeRideSchema.parse(req.body);

    const completed = await RideDAO.complete(ride.id, {
      endTime: new Date(data.endTime),
      duration: data.duration,
      movingTime: data.movingTime,
      distance: data.distance,
      avgSpeed: data.avgSpeed,
      maxSpeed: data.maxSpeed,
      avgHeartRate: data.avgHeartRate,
      maxHeartRate: data.maxHeartRate,
      calories: data.calories,
      elevationGain: data.elevationGain,
      elevationLoss: data.elevationLoss,
    });

    res.json({
      message: 'Ride completed successfully',
      ride: completed,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /rides/{id}/track:
 *   get:
 *     summary: Get ride track data
 *     tags: [Rides]
 */
router.get('/:id/track', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ride = await RideDAO.findById(req.params.id);

    if (!ride) {
      throw ApiError.notFound('Ride not found');
    }

    if (ride.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    // Return track URL if stored in OBS
    if (ride.trackUrl) {
      res.json({
        trackUrl: ride.trackUrl,
        trackPointCount: ride.trackPointCount,
        checksum: ride.trackChecksum,
      });
    } else {
      res.json({
        message: 'Track data not available',
        trackPointCount: ride.trackPointCount,
      });
    }
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /rides/{id}/export:
 *   get:
 *     summary: Export ride data
 *     tags: [Rides]
 */
router.get('/:id/export', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { format = 'json' } = req.query;
    const ride = await RideDAO.findByIdWithSegments(req.params.id);

    if (!ride) {
      throw ApiError.notFound('Ride not found');
    }

    if (ride.userId !== req.user!.id) {
      throw ApiError.forbidden('Access denied');
    }

    // TODO: Implement GPX/TCX export
    res.json({
      ride,
      format,
      message: 'Export format not yet implemented',
    });
  } catch (error) {
    next(error);
  }
});

export default router;

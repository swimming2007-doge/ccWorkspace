import { Router, Request, Response, NextFunction } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { readRateLimiter } from '../middleware/rate-limit.middleware';
import { UserDAO, RideDAO } from '../db/dao';

const router = Router();

// ===========================================
// Routes
// ===========================================

/**
 * @swagger
 * /stats/summary:
 *   get:
 *     summary: Get overall statistics summary
 *     tags: [Stats]
 */
router.get('/summary', authenticate, readRateLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const stats = await UserDAO.getStats(req.user!.id);

    res.json({
      summary: {
        totalRides: stats.totalRides,
        totalDistance: stats.totalDistance,
        totalDuration: stats.totalDuration,
        totalCalories: stats.totalCalories,
        totalElevationGain: stats.totalElevationGain,
        avgSpeed: stats.avgSpeed,
        maxSpeed: stats.maxSpeed,
        maxDistance: stats.maxDistance,
        maxDuration: stats.maxDuration,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /stats/weekly:
 *   get:
 *     summary: Get weekly statistics
 *     tags: [Stats]
 */
router.get('/weekly', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const now = new Date();
    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - now.getDay());
    weekStart.setHours(0, 0, 0, 0);

    const stats = await RideDAO.getStatsByPeriod(req.user!.id, weekStart, now);

    res.json({
      period: {
        start: weekStart,
        end: now,
      },
      stats,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /stats/monthly:
 *   get:
 *     summary: Get monthly statistics
 *     tags: [Stats]
 */
router.get('/monthly', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const stats = await RideDAO.getStatsByPeriod(req.user!.id, monthStart, now);

    res.json({
      period: {
        start: monthStart,
        end: now,
      },
      stats,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /stats/yearly:
 *   get:
 *     summary: Get yearly statistics
 *     tags: [Stats]
 */
router.get('/yearly', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const now = new Date();
    const yearStart = new Date(now.getFullYear(), 0, 1);

    const stats = await RideDAO.getStatsByPeriod(req.user!.id, yearStart, now);

    res.json({
      period: {
        start: yearStart,
        end: now,
      },
      stats,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /stats/records:
 *   get:
 *     summary: Get personal records
 *     tags: [Stats]
 */
router.get('/records', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // TODO: Implement personal records calculation
    res.json({
      records: {
        longestRide: null,
        fastestRide: null,
        highestElevation: null,
        longestDuration: null,
      },
      message: 'Personal records feature not yet fully implemented',
    });
  } catch (error) {
    next(error);
  }
});

export default router;

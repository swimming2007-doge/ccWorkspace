import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { authenticate, generateToken, generateRefreshToken, verifyRefreshToken } from '../middleware/auth.middleware';
import { authRateLimiter } from '../middleware/rate-limit.middleware';
import { ApiError } from '../middleware/error.middleware';
import { UserDAO } from '../db/dao';

const router = Router();

// ===========================================
// Validation Schemas
// ===========================================

const loginSchema = z.object({
  huaweiId: z.string().optional(),
  code: z.string().optional(), // OAuth authorization code
});

const updateUserSchema = z.object({
  nickname: z.string().min(1).max(50).optional(),
  avatar: z.string().url().optional(),
  height: z.number().min(50).max(250).optional(),
  weight: z.number().min(20).max(300).optional(),
  maxHeartRate: z.number().min(60).max(220).optional(),
  birthDate: z.string().optional(),
});

const updateSettingsSchema = z.object({
  defaultNavMode: z.enum(['road', 'adventure', 'mixed']).optional(),
  adventureRatio: z.number().min(0).max(1).optional(),
  maxRiskIndex: z.number().min(1).max(5).optional(),
  unitSystem: z.enum(['metric', 'imperial']).optional(),
  voiceNavigation: z.boolean().optional(),
  autoStartStop: z.boolean().optional(),
  detectionSensitivity: z.enum(['low', 'medium', 'high']).optional(),
  pauseTimeout: z.number().min(1).max(120).optional(),
  cloudSyncEnabled: z.boolean().optional(),
});

// ===========================================
// Routes
// ===========================================

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Login with Huawei OAuth
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               code:
 *                 type: string
 *                 description: OAuth authorization code
 *     responses:
 *       200:
 *         description: Login successful
 */
router.post('/login', authRateLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { code } = loginSchema.parse(req.body);

    if (!code) {
      throw ApiError.badRequest('Authorization code is required');
    }

    // TODO: Implement Huawei OAuth token exchange
    // For now, create a mock user for development
    let user = await UserDAO.findByHuaweiId('mock-huawei-id');

    if (!user) {
      user = await UserDAO.create({
        huaweiId: 'mock-huawei-id',
        nickname: 'Rider',
      });
    }

    // Update last login
    await UserDAO.updateLastLogin(user.id);

    // Generate tokens
    const accessToken = generateToken({ id: user.id, huaweiId: user.huaweiId || undefined });
    const refreshToken = generateRefreshToken({ id: user.id, huaweiId: user.huaweiId || undefined });

    res.json({
      message: 'Login successful',
      user: {
        id: user.id,
        nickname: user.nickname,
        avatar: user.avatar,
      },
      tokens: {
        accessToken,
        refreshToken,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     summary: Refresh access token
 *     tags: [Auth]
 */
router.post('/refresh', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      throw ApiError.badRequest('Refresh token is required');
    }

    const decoded = verifyRefreshToken(refreshToken);
    const user = await UserDAO.findById(decoded.id);

    if (!user) {
      throw ApiError.unauthorized('User not found');
    }

    const accessToken = generateToken({ id: user.id, huaweiId: user.huaweiId || undefined });
    const newRefreshToken = generateRefreshToken({ id: user.id, huaweiId: user.huaweiId || undefined });

    res.json({
      message: 'Token refreshed',
      tokens: {
        accessToken,
        refreshToken: newRefreshToken,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Logout user
 *   tags: [Auth]
 */
router.post('/logout', authenticate, (req: Request, res: Response) => {
  // In a stateless JWT system, logout is handled client-side
  // Optionally, add token to blacklist if needed
  res.json({ message: 'Logged out successfully' });
});

/**
 * @swagger
 * /auth/me:
 *   get:
 *     summary: Get current user info
 *     tags: [Auth]
 */
router.get('/me', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await UserDAO.findById(req.user!.id);

    if (!user) {
      throw ApiError.notFound('User not found');
    }

    res.json({
      user: {
        id: user.id,
        nickname: user.nickname,
        avatar: user.avatar,
        email: user.email,
        phone: user.phone,
        height: user.height,
        weight: user.weight,
        maxHeartRate: user.maxHeartRate,
        birthDate: user.birthDate,
        defaultNavMode: user.defaultNavMode,
        adventureRatio: user.adventureRatio,
        unitSystem: user.unitSystem,
        voiceNavigation: user.voiceNavigation,
        autoStartStop: user.autoStartStop,
        detectionSensitivity: user.detectionSensitivity,
        cloudSyncEnabled: user.cloudSyncEnabled,
        stravaConnected: user.stravaConnected,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /auth/me:
 *   put:
 *     summary: Update current user info
 *     tags: [Auth]
 */
router.put('/me', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = updateUserSchema.parse(req.body);

    const user = await UserDAO.update(req.user!.id, data);

    res.json({
      message: 'User updated successfully',
      user: {
        id: user.id,
        nickname: user.nickname,
        avatar: user.avatar,
        height: user.height,
        weight: user.weight,
        maxHeartRate: user.maxHeartRate,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /auth/settings:
 *   put:
 *     summary: Update user settings
 *     tags: [Auth]
 */
router.put('/settings', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = updateSettingsSchema.parse(req.body);

    const user = await UserDAO.update(req.user!.id, data);

    res.json({
      message: 'Settings updated successfully',
      settings: {
        defaultNavMode: user.defaultNavMode,
        adventureRatio: user.adventureRatio,
        maxRiskIndex: user.maxRiskIndex,
        unitSystem: user.unitSystem,
        voiceNavigation: user.voiceNavigation,
        autoStartStop: user.autoStartStop,
        detectionSensitivity: user.detectionSensitivity,
        pauseTimeout: user.pauseTimeout,
        cloudSyncEnabled: user.cloudSyncEnabled,
      },
    });
  } catch (error) {
    next(error);
  }
});

export default router;

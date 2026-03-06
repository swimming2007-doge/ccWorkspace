import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { authenticate, generateToken, generateRefreshToken, verifyRefreshToken } from '../middleware/auth.middleware';
import { authRateLimiter } from '../middleware/rate-limit.middleware';
import { ApiError } from '../middleware/error.middleware';
import { UserDAO } from '../db/dao';
import authService from '../services/auth.service';

const router = Router();

// ===========================================
// Validation Schemas
// ===========================================

const loginSchema = z.object({
  huaweiId: z.string().optional(),
  code: z.string().optional(), // OAuth authorization code
});

const huaweiCallbackSchema = z.object({
  code: z.string(),
  clientId: z.string().optional(),
});

const refreshTokenSchema = z.object({
  refreshToken: z.string(),
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
 * /auth/huawei/url:
 *   get:
 *     summary: Get Huawei OAuth authorization URL
 *     tags: [Auth]
 *     parameters:
 *       - in: query
 *         name: state
 *         schema:
 *           type: string
 *         description: State parameter for CSRF protection
 *     responses:
 *       200:
 *         description: Authorization URL generated
 */
router.get('/huawei/url', (req: Request, res: Response) => {
  const state = req.query.state as string || Math.random().toString(36).substring(7);
  const authUrl = authService.getHuaweiAuthUrl(state);

  res.json({
    authUrl,
    state,
    expiresIn: 300, // 5 minutes
  });
});

/**
 * @swagger
 * /auth/huawei/callback:
 *   post:
 *     summary: Handle Huawei OAuth callback
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
 *               clientId:
 *                 type: string
 *                 description: Client ID
 *     responses:
 *       200:
 *         description: Login successful
 */
router.post('/huawei/callback', authRateLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { code, clientId } = huaweiCallbackSchema.parse(req.body);

    // 使用认证服务处理回调
    const tokens = await authService.handleHuaweiCallback(code, clientId || 'riderecord_mobile');

    // 获取用户信息
    const payload = authService.verifyAccessToken(tokens.accessToken);

    let user = null;
    if (payload) {
      user = await UserDAO.findById(payload.userId);
    }

    res.json({
      message: 'Login successful',
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      tokenType: tokens.tokenType,
      user: user ? {
        id: user.id,
        huaweiId: user.huaweiId,
        nickname: user.nickname,
        avatar: user.avatar,
        email: user.email,
        phone: user.phone,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      } : null,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /auth/guest:
 *   post:
 *     summary: Create guest user (for testing)
 *     tags: [Auth]
 *     responses:
 *       200:
 *         description: Guest user created
 */
router.post('/guest', authRateLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { user, tokens } = await authService.createGuestUser();

    res.json({
      message: 'Guest user created',
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      tokenType: tokens.tokenType,
      user: {
        id: user.id,
        nickname: user.nickname,
        isGuest: user.isGuest,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    next(error);
  }
});

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

    // 使用认证服务处理登录
    const tokens = await authService.handleHuaweiCallback(code, 'riderecord_mobile');

    // 获取用户信息
    const payload = authService.verifyAccessToken(tokens.accessToken);

    let user = null;
    if (payload) {
      user = await UserDAO.findById(payload.userId);
      if (user) {
        await UserDAO.updateLastLogin(user.id);
      }
    }

    res.json({
      message: 'Login successful',
      user: user ? {
        id: user.id,
        nickname: user.nickname,
        avatar: user.avatar,
      } : null,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
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
    const { refreshToken } = refreshTokenSchema.parse(req.body);

    // 使用认证服务刷新Token
    const tokens = await authService.refreshAccessToken(refreshToken);

    if (!tokens) {
      throw ApiError.unauthorized('Invalid or expired refresh token');
    }

    res.json({
      message: 'Token refreshed',
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      tokenType: tokens.tokenType,
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
router.post('/logout', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      authService.revokeToken(refreshToken);
    }

    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /auth/me:
 *   get:
 *     summary: Get current user info
 *   tags: [Auth]
 */
router.get('/me', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await UserDAO.findById(req.user!.id);

    if (!user) {
      throw ApiError.notFound('User not found');
    }

    res.json({
      id: user.id,
      huaweiId: user.huaweiId,
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
      updatedAt: user.updatedAt,
      lastLoginAt: user.lastLoginAt,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /auth/me:
 *   patch:
 *     summary: Update current user info
 *   tags: [Auth]
 */
router.patch('/me', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = updateUserSchema.parse(req.body);

    const user = await UserDAO.update(req.user!.id, data);

    res.json({
      message: 'User updated successfully',
      id: user.id,
      nickname: user.nickname,
      avatar: user.avatar,
      height: user.height,
      weight: user.weight,
      maxHeartRate: user.maxHeartRate,
      updatedAt: user.updatedAt,
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
 *   tags: [Auth]
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

/**
 * @swagger
 * /auth/delete:
 *   delete:
 *     summary: Delete user account
 *   tags: [Auth]
 */
router.delete('/delete', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // TODO: 实现账户删除逻辑
    // 1. 删除用户数据
    // 2. 删除云端数据
    // 3. 注销账号

    res.json({
      message: 'Account deletion requested. Data will be removed within 30 days.',
    });
  } catch (error) {
    next(error);
  }
});

export default router;

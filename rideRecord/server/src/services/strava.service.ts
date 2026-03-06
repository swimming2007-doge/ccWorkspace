/**
 * Strava 同步服务 (服务端)
 *
 * 功能说明：
 * - Strava OAuth 回调处理
 * - Token 管理和验证
 * - 活动数据代理
 * - Webhook 事件处理
 *
 * SRS引用: FR-008-01
 */

import { Request, Response } from 'express';
import axios from 'axios';

const STRAVA_CONFIG = {
  CLIENT_ID: process.env.STRAVA_CLIENT_ID || '',
  CLIENT_SECRET: process.env.STRAVA_CLIENT_SECRET || '',
  REDIRECT_URI: process.env.STRAVA_REDIRECT_URI || 'http://localhost:3000/api/strava/callback',
  TOKEN_URL: 'https://www.strava.com/oauth/token',
  API_BASE_URL: 'https://www.strava.com/api/v3'
};

/**
 * Strava Token 信息
 */
interface StravaTokenInfo {
  userId: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  athleteId: number;
  createdAt: number;
  updatedAt: number;
}

/**
 * Strava 活动数据
 */
interface StravaActivity {
  id: number;
  name: string;
  type: string;
  start_date: string;
  distance: number;
  moving_time: number;
  elapsed_time: number;
  total_elevation_gain: number;
  average_speed: number;
  max_speed: number;
  average_heartrate?: number;
  max_heartrate?: number;
  calories?: number;
}

/**
 * Webhook 事件
 */
interface StravaWebhookEvent {
  object_type: 'activity' | 'athlete';
  object_id: number;
  aspect_type: 'create' | 'update' | 'delete';
  updates: Record<string, any>;
  owner_id: number;
  subscription_id: number;
  event_time: number;
}

// 模拟数据库存储
const tokenStore: Map<string, StravaTokenInfo> = new Map();

/**
 * Strava 服务类
 */
export class StravaService {
  /**
   * 获取授权URL
   */
  static getAuthorizationUrl(userId: string): string {
    const params = new URLSearchParams({
      client_id: STRAVA_CONFIG.CLIENT_ID,
      redirect_uri: STRAVA_CONFIG.REDIRECT_URI,
      response_type: 'code',
      scope: 'read,read_all,profile:read_all,activity:read,activity:read_all,activity:write',
      state: userId,
      approval_prompt: 'auto'
    });

    return `https://www.strava.com/oauth/authorize?${params.toString()}`;
  }

  /**
   * 处理 OAuth 回调
   */
  static async handleCallback(code: string, userId: string): Promise<StravaTokenInfo | null> {
    try {
      const response = await axios.post(STRAVA_CONFIG.TOKEN_URL, {
        client_id: STRAVA_CONFIG.CLIENT_ID,
        client_secret: STRAVA_CONFIG.CLIENT_SECRET,
        code: code,
        grant_type: 'authorization_code'
      });

      const { access_token, refresh_token, expires_at, athlete } = response.data;

      const tokenInfo: StravaTokenInfo = {
        userId,
        accessToken: access_token,
        refreshToken: refresh_token,
        expiresAt: expires_at,
        athleteId: athlete.id,
        createdAt: Date.now(),
        updatedAt: Date.now()
      };

      // 保存 token
      tokenStore.set(userId, tokenInfo);

      console.log(`[Strava] User ${userId} connected to Strava athlete ${athlete.id}`);

      return tokenInfo;

    } catch (error) {
      console.error('[Strava] OAuth callback error:', error);
      return null;
    }
  }

  /**
   * 刷新访问令牌
   */
  static async refreshToken(userId: string): Promise<StravaTokenInfo | null> {
    const tokenInfo = tokenStore.get(userId);
    if (!tokenInfo) {
      return null;
    }

    try {
      const response = await axios.post(STRAVA_CONFIG.TOKEN_URL, {
        client_id: STRAVA_CONFIG.CLIENT_ID,
        client_secret: STRAVA_CONFIG.CLIENT_SECRET,
        refresh_token: tokenInfo.refreshToken,
        grant_type: 'refresh_token'
      });

      const { access_token, refresh_token, expires_at } = response.data;

      const updatedToken: StravaTokenInfo = {
        ...tokenInfo,
        accessToken: access_token,
        refreshToken: refresh_token,
        expiresAt: expires_at,
        updatedAt: Date.now()
      };

      tokenStore.set(userId, updatedToken);

      console.log(`[Strava] Token refreshed for user ${userId}`);

      return updatedToken;

    } catch (error) {
      console.error('[Strava] Token refresh error:', error);
      return null;
    }
  }

  /**
   * 获取有效的访问令牌
   */
  static async getValidAccessToken(userId: string): Promise<string | null> {
    const tokenInfo = tokenStore.get(userId);
    if (!tokenInfo) {
      return null;
    }

    // 检查是否过期（提前5分钟刷新）
    if (Date.now() / 1000 > tokenInfo.expiresAt - 300) {
      const updated = await this.refreshToken(userId);
      return updated?.accessToken || null;
    }

    return tokenInfo.accessToken;
  }

  /**
   * 获取运动员信息
   */
  static async getAthlete(userId: string): Promise<any | null> {
    const accessToken = await this.getValidAccessToken(userId);
    if (!accessToken) {
      return null;
    }

    try {
      const response = await axios.get(`${STRAVA_CONFIG.API_BASE_URL}/athlete`, {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });

      return response.data;

    } catch (error) {
      console.error('[Strava] Get athlete error:', error);
      return null;
    }
  }

  /**
   * 上传活动
   */
  static async uploadActivity(
    userId: string,
    gpxData: string,
    options: {
      name?: string;
      description?: string;
      type?: string;
      commute?: boolean;
      trainer?: boolean;
    } = {}
  ): Promise<{ id: number; status: string } | null> {
    const accessToken = await this.getValidAccessToken(userId);
    if (!accessToken) {
      return null;
    }

    try {
      const formData = new FormData();
      formData.append('file', new Blob([gpxData], { type: 'application/gpx+xml' }), 'activity.gpx');
      formData.append('data_type', 'gpx');
      formData.append('name', options.name || '骑行活动');
      formData.append('description', options.description || '');
      formData.append('activity_type', options.type || 'ride');
      formData.append('commute', options.commute ? '1' : '0');
      formData.append('trainer', options.trainer ? '1' : '0');

      const response = await axios.post(
        `${STRAVA_CONFIG.API_BASE_URL}/uploads`,
        formData,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'multipart/form-data'
          }
        }
      );

      console.log(`[Strava] Activity uploaded for user ${userId}, upload_id: ${response.data.id}`);

      return {
        id: response.data.id,
        status: response.data.status
      };

    } catch (error) {
      console.error('[Strava] Upload activity error:', error);
      return null;
    }
  }

  /**
   * 获取上传状态
   */
  static async getUploadStatus(userId: string, uploadId: number): Promise<any | null> {
    const accessToken = await this.getValidAccessToken(userId);
    if (!accessToken) {
      return null;
    }

    try {
      const response = await axios.get(
        `${STRAVA_CONFIG.API_BASE_URL}/uploads/${uploadId}`,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`
          }
        }
      );

      return response.data;

    } catch (error) {
      console.error('[Strava] Get upload status error:', error);
      return null;
    }
  }

  /**
   * 获取活动列表
   */
  static async getActivities(
    userId: string,
    options: {
      page?: number;
      perPage?: number;
      before?: number;
      after?: number;
    } = {}
  ): Promise<StravaActivity[] | null> {
    const accessToken = await this.getValidAccessToken(userId);
    if (!accessToken) {
      return null;
    }

    try {
      const params = new URLSearchParams();
      if (options.page) params.append('page', options.page.toString());
      if (options.perPage) params.append('per_page', options.perPage.toString());
      if (options.before) params.append('before', options.before.toString());
      if (options.after) params.append('after', options.after.toString());

      const response = await axios.get(
        `${STRAVA_CONFIG.API_BASE_URL}/athlete/activities?${params.toString()}`,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`
          }
        }
      );

      return response.data;

    } catch (error) {
      console.error('[Strava] Get activities error:', error);
      return null;
    }
  }

  /**
   * 获取活动详情
   */
  static async getActivity(userId: string, activityId: number): Promise<any | null> {
    const accessToken = await this.getValidAccessToken(userId);
    if (!accessToken) {
      return null;
    }

    try {
      const response = await axios.get(
        `${STRAVA_CONFIG.API_BASE_URL}/activities/${activityId}`,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`
          }
        }
      );

      return response.data;

    } catch (error) {
      console.error('[Strava] Get activity error:', error);
      return null;
    }
  }

  /**
   * 删除活动
   */
  static async deleteActivity(userId: string, activityId: number): Promise<boolean> {
    const accessToken = await this.getValidAccessToken(userId);
    if (!accessToken) {
      return false;
    }

    try {
      await axios.delete(
        `${STRAVA_CONFIG.API_BASE_URL}/activities/${activityId}`,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`
          }
        }
      );

      console.log(`[Strava] Activity ${activityId} deleted for user ${userId}`);

      return true;

    } catch (error) {
      console.error('[Strava] Delete activity error:', error);
      return false;
    }
  }

  /**
   * 断开连接
   */
  static disconnect(userId: string): boolean {
    const deleted = tokenStore.delete(userId);
    if (deleted) {
      console.log(`[Strava] User ${userId} disconnected from Strava`);
    }
    return deleted;
  }

  /**
   * 检查连接状态
   */
  static isConnected(userId: string): boolean {
    return tokenStore.has(userId);
  }

  /**
   * 处理 Webhook 事件
   */
  static async handleWebhook(event: StravaWebhookEvent): Promise<void> {
    console.log('[Strava] Webhook event received:', JSON.stringify(event));

    // 根据 event type 处理
    switch (event.object_type) {
      case 'activity':
        await this.handleActivityWebhook(event);
        break;
      case 'athlete':
        await this.handleAthleteWebhook(event);
        break;
    }
  }

  /**
   * 处理活动 Webhook
   */
  private static async handleActivityWebhook(event: StravaWebhookEvent): Promise<void> {
    // 查找对应的用户
    const tokenInfo = Array.from(tokenStore.values()).find(t => t.athleteId === event.owner_id);

    if (!tokenInfo) {
      console.warn(`[Strava] No user found for athlete ${event.owner_id}`);
      return;
    }

    switch (event.aspect_type) {
      case 'create':
        console.log(`[Strava] Activity ${event.object_id} created by user ${tokenInfo.userId}`);
        // 可以在这里同步活动到本地数据库
        break;
      case 'update':
        console.log(`[Strava] Activity ${event.object_id} updated by user ${tokenInfo.userId}`);
        break;
      case 'delete':
        console.log(`[Strava] Activity ${event.object_id} deleted by user ${tokenInfo.userId}`);
        break;
    }
  }

  /**
   * 处理运动员 Webhook
   */
  private static async handleAthleteWebhook(event: StravaWebhookEvent): Promise<void> {
    if (event.aspect_type === 'delete') {
      // 用户撤销授权
      const tokenInfo = Array.from(tokenStore.values()).find(t => t.athleteId === event.object_id);
      if (tokenInfo) {
        tokenStore.delete(tokenInfo.userId);
        console.log(`[Strava] Athlete ${event.object_id} deauthorized, removed user ${tokenInfo.userId}`);
      }
    }
  }

  /**
   * 验证 Webhook 订阅
   */
  static verifyWebhookSubscription(token: string, challenge: string): { 'hub.challenge': string } | null {
    // 在实际实现中，应该验证 token 是否匹配订阅时的 verify_token
    return {
      'hub.challenge': challenge
    };
  }
}

/**
 * 路由处理函数
 */
export const stravaRoutes = {
  /**
   * 获取授权URL
   */
  async getAuthUrl(req: Request, res: Response): Promise<void> {
    const userId = req.user?.id; // 假设有认证中间件

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const authUrl = StravaService.getAuthorizationUrl(userId);
    res.json({ authUrl });
  },

  /**
   * OAuth 回调
   */
  async callback(req: Request, res: Response): Promise<void> {
    const { code, state } = req.query;

    if (!code || !state) {
      res.status(400).json({ error: 'Missing code or state' });
      return;
    }

    const tokenInfo = await StravaService.handleCallback(code as string, state as string);

    if (tokenInfo) {
      // 重定向到成功页面
      res.redirect('/settings/strava?success=true');
    } else {
      res.redirect('/settings/strava?error=auth_failed');
    }
  },

  /**
   * 获取连接状态
   */
  async getStatus(req: Request, res: Response): Promise<void> {
    const userId = req.user?.id;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const connected = StravaService.isConnected(userId);
    const athlete = connected ? await StravaService.getAthlete(userId) : null;

    res.json({
      connected,
      athlete: athlete ? {
        id: athlete.id,
        name: `${athlete.firstname} ${athlete.lastname}`,
        profile: athlete.profile
      } : null
    });
  },

  /**
   * 断开连接
   */
  async disconnect(req: Request, res: Response): Promise<void> {
    const userId = req.user?.id;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const success = StravaService.disconnect(userId);
    res.json({ success });
  },

  /**
   * 同步活动
   */
  async syncActivity(req: Request, res: Response): Promise<void> {
    const userId = req.user?.id;
    const { gpxData, name, description } = req.body;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    if (!gpxData) {
      res.status(400).json({ error: 'Missing GPX data' });
      return;
    }

    const result = await StravaService.uploadActivity(userId, gpxData, { name, description });

    if (result) {
      res.json(result);
    } else {
      res.status(500).json({ error: 'Upload failed' });
    }
  },

  /**
   * Webhook 回调
   */
  async webhook(req: Request, res: Response): Promise<void> {
    // GET 请求用于验证订阅
    if (req.method === 'GET') {
      const { 'hub.mode': mode, 'hub.challenge': challenge, 'hub.verify_token': token } = req.query;

      if (mode === 'subscribe') {
        const response = StravaService.verifyWebhookSubscription(token as string, challenge as string);
        if (response) {
          res.json(response);
          return;
        }
      }

      res.status(400).json({ error: 'Invalid verification request' });
      return;
    }

    // POST 请求处理事件
    const event: StravaWebhookEvent = req.body;
    await StravaService.handleWebhook(event);
    res.status(200).send('OK');
  },

  /**
   * 获取活动列表
   */
  async getActivities(req: Request, res: Response): Promise<void> {
    const userId = req.user?.id;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { page, perPage, before, after } = req.query;

    const activities = await StravaService.getActivities(userId, {
      page: page ? parseInt(page as string) : undefined,
      perPage: perPage ? parseInt(perPage as string) : undefined,
      before: before ? parseInt(before as string) : undefined,
      after: after ? parseInt(after as string) : undefined
    });

    res.json(activities || []);
  }
};

export default StravaService;

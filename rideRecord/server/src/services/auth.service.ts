/**
 * 认证服务
 *
 * 功能说明：
 * - 华为OAuth登录
 * - JWT Token生成和验证
 * - Token刷新机制
 * - 用户信息管理
 */

import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { UserDAO } from '../db/dao';
import { v4 as uuidv4 } from 'uuid';

// JWT配置
interface JWTConfig {
  secret: string;
  accessTokenExpiresIn: string; // e.g., '1h', '7d'
  refreshTokenExpiresIn: string;
  issuer: string;
}

// Token载荷
interface TokenPayload {
  userId: string;
  huaweiId?: string;
  iat: number;
  exp: number;
  iss: string;
}

// Token响应
interface TokenResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: string;
}

// 华为OAuth配置
interface HuaweiOAuthConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  authUrl: string;
  tokenUrl: string;
  userInfoUrl: string;
}

// 华为用户信息
interface HuaweiUserInfo {
  openId: string;
  unionId?: string;
  displayName?: string;
  avatarUrl?: string;
  email?: string;
  phoneNumber?: string;
}

// 存储刷新Token (实际应使用Redis)
const refreshTokens = new Map<string, { userId: string; expiresAt: number }>();

/**
 * 认证服务类
 */
export class AuthService {
  private jwtConfig: JWTConfig;
  private huaweiConfig: HuaweiOAuthConfig;

  constructor() {
    this.jwtConfig = {
      secret: process.env.JWT_SECRET || 'riderecord_jwt_secret_key',
      accessTokenExpiresIn: '7d',
      refreshTokenExpiresIn: '30d',
      issuer: 'riderecord'
    };

    this.huaweiConfig = {
      clientId: process.env.HUAWEI_CLIENT_ID || '',
      clientSecret: process.env.HUAWEI_CLIENT_SECRET || '',
      redirectUri: process.env.HUAWEI_REDIRECT_URI || 'riderecord://auth/callback',
      authUrl: 'https://oauth-login.cloud.huawei.com/oauth2/v3/authorize',
      tokenUrl: 'https://oauth-login.cloud.huawei.com/oauth2/v3/token',
      userInfoUrl: 'https://oauth-api.cloud.huawei.com/rest.php?nsp_svc=GOpen.User.getInfo'
    };
  }

  /**
   * 生成访问令牌
   */
  generateAccessToken(userId: string, huaweiId?: string): string {
    const payload: Omit<TokenPayload, 'iat' | 'exp'> = {
      userId,
      huaweiId,
      iss: this.jwtConfig.issuer
    };

    return jwt.sign(payload, this.jwtConfig.secret, {
      expiresIn: this.jwtConfig.accessTokenExpiresIn,
      issuer: this.jwtConfig.issuer
    });
  }

  /**
   * 生成刷新令牌
   */
  generateRefreshToken(userId: string): string {
    const refreshToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = Date.now() + this.parseTimeToMs(this.jwtConfig.refreshTokenExpiresIn);

    refreshTokens.set(refreshToken, { userId, expiresAt });

    return refreshToken;
  }

  /**
   * 生成Token响应
   */
  generateTokenResponse(userId: string, huaweiId?: string): TokenResponse {
    const accessToken = this.generateAccessToken(userId, huaweiId);
    const refreshToken = this.generateRefreshToken(userId);

    return {
      accessToken,
      refreshToken,
      expiresIn: this.parseTimeToSeconds(this.jwtConfig.accessTokenExpiresIn),
      tokenType: 'Bearer'
    };
  }

  /**
   * 验证访问令牌
   */
  verifyAccessToken(token: string): TokenPayload | null {
    try {
      const decoded = jwt.verify(token, this.jwtConfig.secret, {
        issuer: this.jwtConfig.issuer
      }) as TokenPayload;

      return decoded;
    } catch (error) {
      return null;
    }
  }

  /**
   * 刷新Token
   */
  async refreshAccessToken(refreshToken: string): Promise<TokenResponse | null> {
    const stored = refreshTokens.get(refreshToken);

    if (!stored) {
      return null;
    }

    // 检查是否过期
    if (Date.now() > stored.expiresAt) {
      refreshTokens.delete(refreshToken);
      return null;
    }

    // 获取用户信息
    const user = await UserDAO.findById(stored.userId);
    if (!user) {
      return null;
    }

    // 删除旧的刷新Token
    refreshTokens.delete(refreshToken);

    // 生成新的Token
    return this.generateTokenResponse(user.id, user.huaweiId || undefined);
  }

  /**
   * 撤销Token
   */
  revokeToken(refreshToken: string): boolean {
    return refreshTokens.delete(refreshToken);
  }

  /**
   * 处理华为OAuth回调
   */
  async handleHuaweiCallback(authCode: string, clientId: string): Promise<TokenResponse> {
    // 1. 使用授权码换取访问令牌
    const huaweiToken = await this.exchangeCodeForToken(authCode);

    // 2. 获取华为用户信息
    const huaweiUser = await this.getHuaweiUserInfo(huaweiToken.accessToken);

    // 3. 查找或创建用户
    let user = await UserDAO.findByHuaweiId(huaweiUser.openId);

    if (!user) {
      user = await UserDAO.create({
        id: uuidv4(),
        huaweiId: huaweiUser.openId,
        nickname: huaweiUser.displayName || '骑行者',
        avatar: huaweiUser.avatarUrl,
        email: huaweiUser.email,
        phone: huaweiUser.phoneNumber,
      });
    } else {
      // 更新用户信息
      user = await UserDAO.update(user.id, {
        nickname: huaweiUser.displayName || user.nickname,
        avatar: huaweiUser.avatarUrl || user.avatar,
        lastLoginAt: new Date()
      });
    }

    // 4. 生成Token
    return this.generateTokenResponse(user.id, user.huaweiId || undefined);
  }

  /**
   * 使用授权码换取Token
   */
  private async exchangeCodeForToken(code: string): Promise<{ accessToken: string; refreshToken?: string }> {
    // 实际实现需要调用华为OAuth API
    // 这里提供模拟实现
    const response = await fetch(this.huaweiConfig.tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        client_id: this.huaweiConfig.clientId,
        client_secret: this.huaweiConfig.clientSecret,
        redirect_uri: this.huaweiConfig.redirectUri
      }).toString()
    });

    if (!response.ok) {
      throw new Error('Failed to exchange code for token');
    }

    const data = await response.json() as any;

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token
    };
  }

  /**
   * 获取华为用户信息
   */
  private async getHuaweiUserInfo(accessToken: string): Promise<HuaweiUserInfo> {
    // 实际实现需要调用华为用户信息API
    // 这里提供模拟实现
    const response = await fetch(this.huaweiConfig.userInfoUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        nsp_ts: Math.floor(Date.now() / 1000)
      })
    });

    if (!response.ok) {
      // 返回模拟数据
      return {
        openId: 'hw_' + Date.now(),
        displayName: '华为用户',
        avatarUrl: undefined,
        email: undefined,
        phoneNumber: undefined
      };
    }

    const data = await response.json() as any;

    return {
      openId: data.openId || data.unionId,
      unionId: data.unionId,
      displayName: data.displayName,
      avatarUrl: data.avatarUrl,
      email: data.email,
      phoneNumber: data.phoneNumber
    };
  }

  /**
   * 获取华为OAuth授权URL
   */
  getHuaweiAuthUrl(state: string): string {
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.huaweiConfig.clientId,
      redirect_uri: this.huaweiConfig.redirectUri,
      scope: 'openid profile email',
      state,
      access_type: 'offline'
    });

    return `${this.huaweiConfig.authUrl}?${params.toString()}`;
  }

  /**
   * 创建游客用户
   */
  async createGuestUser(): Promise<{ user: any; tokens: TokenResponse }> {
    const userId = uuidv4();
    const guestNumber = Math.floor(Math.random() * 10000);

    const user = await UserDAO.create({
      id: userId,
      nickname: `游客${guestNumber}`,
      isGuest: true
    });

    const tokens = this.generateTokenResponse(user.id);

    return { user, tokens };
  }

  /**
   * 清理过期的刷新Token
   */
  cleanupExpiredTokens(): number {
    const now = Date.now();
    let count = 0;

    for (const [token, data] of refreshTokens.entries()) {
      if (data.expiresAt < now) {
        refreshTokens.delete(token);
        count++;
      }
    }

    return count;
  }

  /**
   * 解析时间字符串到毫秒
   */
  private parseTimeToMs(timeStr: string): number {
    const match = timeStr.match(/^(\d+)([smhd])$/);
    if (!match) return 7 * 24 * 60 * 60 * 1000; // 默认7天

    const value = parseInt(match[1]);
    const unit = match[2];

    switch (unit) {
      case 's': return value * 1000;
      case 'm': return value * 60 * 1000;
      case 'h': return value * 60 * 60 * 1000;
      case 'd': return value * 24 * 60 * 60 * 1000;
      default: return value * 1000;
    }
  }

  /**
   * 解析时间字符串到秒
   */
  private parseTimeToSeconds(timeStr: string): number {
    return Math.floor(this.parseTimeToMs(timeStr) / 1000);
  }
}

// 导出单例
export const authService = new AuthService();
export default authService;

/**
 * 用户认证服务
 *
 * 功能说明：
 * - 华为账号OAuth登录
 * - JWT Token管理
 * - Token刷新机制
 * - 用户信息管理
 * - 登录状态持久化
 *
 * 依赖：
 * - @ohos.account.osAccount: 华为账号
 * - @ohos.data.preferences: 本地存储
 */

import account_osAccount from '@ohos.account.osAccount';
import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import http from '@ohos.net.http';

const TAG = '[AuthService]';
const DOMAIN = 0xFF00;

/**
 * 用户信息
 */
export interface UserInfo {
  id: string;
  huaweiId?: string;
  nickname: string;
  avatar?: string;
  email?: string;
  phone?: string;
  createdAt: string;
  updatedAt: string;
}

/**
 * Token信息
 */
export interface TokenInfo {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: string;
  expiresAt: number; // 过期时间戳
}

/**
 * 登录状态
 */
export enum LoginStatus {
  LOGGED_OUT = 'logged_out',
  LOGGING_IN = 'logging_in',
  LOGGED_IN = 'logged_in',
  TOKEN_EXPIRED = 'token_expired',
  LOGIN_FAILED = 'login_failed'
}

/**
 * 登录结果
 */
export interface LoginResult {
  success: boolean;
  user?: UserInfo;
  token?: TokenInfo;
  error?: string;
}

/**
 * 认证状态变更回调
 */
export type AuthStatusCallback = (status: LoginStatus, user?: UserInfo) => void;

/**
 * 用户认证服务类
 */
export class AuthService {
  private readonly PREF_NAME = 'auth_prefs';
  private readonly KEY_ACCESS_TOKEN = 'access_token';
  private readonly KEY_REFRESH_TOKEN = 'refresh_token';
  private readonly KEY_TOKEN_EXPIRES = 'token_expires';
  private readonly KEY_USER_INFO = 'user_info';

  private preferences: preferences.Preferences | null = null;
  private currentUser: UserInfo | null = null;
  private tokenInfo: TokenInfo | null = null;
  private status: LoginStatus = LoginStatus.LOGGED_OUT;
  private statusCallbacks: AuthStatusCallback[] = [];

  // 配置
  private serverUrl: string = 'https://api.riderecord.com';
  private clientId: string = 'riderecord_mobile';

  /**
   * 初始化认证服务
   */
  async initialize(): Promise<void> {
    try {
      // 加载本地存储
      this.preferences = await preferences.getPreferences(this.PREF_NAME);

      // 恢复登录状态
      await this.restoreAuthState();

      hilog.info(DOMAIN, TAG, 'AuthService initialized, status: %{public}s', this.status);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 设置服务器配置
   */
  setConfig(serverUrl: string, clientId: string): void {
    this.serverUrl = serverUrl;
    this.clientId = clientId;
  }

  /**
   * 华为账号登录
   */
  async loginWithHuawei(): Promise<LoginResult> {
    try {
      this.setStatus(LoginStatus.LOGGING_IN);

      // 获取华为账号授权
      const osAccountManager = account_osAccount.getAccountManager();

      // 请求OAuth授权
      const authResult = await this.requestHuaweiOAuth();

      if (!authResult.success || !authResult.authCode) {
        this.setStatus(LoginStatus.LOGIN_FAILED);
        return {
          success: false,
          error: authResult.error || '华为账号授权失败'
        };
      }

      // 使用授权码换取Token
      const tokenResult = await this.exchangeAuthCodeForToken(authResult.authCode);

      if (!tokenResult.success || !tokenResult.token) {
        this.setStatus(LoginStatus.LOGIN_FAILED);
        return {
          success: false,
          error: tokenResult.error || '获取Token失败'
        };
      }

      // 获取用户信息
      const userResult = await this.fetchUserInfo(tokenResult.token.accessToken);

      if (!userResult.success || !userResult.user) {
        this.setStatus(LoginStatus.LOGIN_FAILED);
        return {
          success: false,
          error: userResult.error || '获取用户信息失败'
        };
      }

      // 保存认证状态
      this.tokenInfo = tokenResult.token;
      this.currentUser = userResult.user;
      await this.saveAuthState();

      this.setStatus(LoginStatus.LOGGED_IN, this.currentUser);

      return {
        success: true,
        user: this.currentUser,
        token: this.tokenInfo
      };

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      hilog.error(DOMAIN, TAG, 'Login failed: %{public}s', errorMessage);
      this.setStatus(LoginStatus.LOGIN_FAILED);
      return {
        success: false,
        error: errorMessage
      };
    }
  }

  /**
   * 游客模式登录 (开发测试用)
   */
  async loginAsGuest(): Promise<LoginResult> {
    try {
      this.setStatus(LoginStatus.LOGGING_IN);

      // 创建游客账号
      const guestUser: UserInfo = {
        id: 'guest_' + Date.now(),
        nickname: '游客用户',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };

      // 生成临时Token
      const guestToken: TokenInfo = {
        accessToken: 'guest_token_' + Date.now(),
        refreshToken: 'guest_refresh_' + Date.now(),
        expiresIn: 7 * 24 * 3600, // 7天
        tokenType: 'Bearer',
        expiresAt: Date.now() + 7 * 24 * 3600 * 1000
      };

      this.currentUser = guestUser;
      this.tokenInfo = guestToken;
      await this.saveAuthState();

      this.setStatus(LoginStatus.LOGGED_IN, this.currentUser);

      return {
        success: true,
        user: this.currentUser,
        token: this.tokenInfo
      };

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      this.setStatus(LoginStatus.LOGIN_FAILED);
      return {
        success: false,
        error: errorMessage
      };
    }
  }

  /**
   * 登出
   */
  async logout(): Promise<void> {
    try {
      // 调用服务端登出
      if (this.tokenInfo) {
        await this.revokeToken(this.tokenInfo.accessToken);
      }

      // 清除本地状态
      this.currentUser = null;
      this.tokenInfo = null;
      await this.clearAuthState();

      this.setStatus(LoginStatus.LOGGED_OUT);

      hilog.info(DOMAIN, TAG, 'User logged out');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Logout failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 刷新Token
   */
  async refreshToken(): Promise<boolean> {
    if (!this.tokenInfo?.refreshToken) {
      return false;
    }

    try {
      const httpRequest = http.createHttp();

      const response = await httpRequest.request(
        `${this.serverUrl}/api/v1/auth/refresh`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            refreshToken: this.tokenInfo.refreshToken
          }),
          connectTimeout: 30000,
          readTimeout: 30000
        }
      );

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string);
        this.tokenInfo = {
          accessToken: result.accessToken,
          refreshToken: result.refreshToken || this.tokenInfo.refreshToken,
          expiresIn: result.expiresIn,
          tokenType: result.tokenType || 'Bearer',
          expiresAt: Date.now() + result.expiresIn * 1000
        };

        await this.saveAuthState();
        return true;
      }

      return false;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Token refresh failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 获取访问令牌
   */
  async getAccessToken(): Promise<string | null> {
    if (!this.tokenInfo) {
      return null;
    }

    // 检查是否过期
    if (Date.now() >= this.tokenInfo.expiresAt - 60000) { // 提前1分钟刷新
      const refreshed = await this.refreshToken();
      if (!refreshed) {
        this.setStatus(LoginStatus.TOKEN_EXPIRED);
        return null;
      }
    }

    return this.tokenInfo.accessToken;
  }

  /**
   * 获取当前用户
   */
  getCurrentUser(): UserInfo | null {
    return this.currentUser;
  }

  /**
   * 获取登录状态
   */
  getLoginStatus(): LoginStatus {
    return this.status;
  }

  /**
   * 是否已登录
   */
  isLoggedIn(): boolean {
    return this.status === LoginStatus.LOGGED_IN;
  }

  /**
   * 注册状态回调
   */
  onStatusChange(callback: AuthStatusCallback): void {
    this.statusCallbacks.push(callback);
  }

  /**
   * 更新用户信息
   */
  async updateUserInfo(updates: Partial<UserInfo>): Promise<boolean> {
    if (!this.currentUser) {
      return false;
    }

    try {
      const token = await this.getAccessToken();
      if (!token) {
        return false;
      }

      const httpRequest = http.createHttp();

      const response = await httpRequest.request(
        `${this.serverUrl}/api/v1/users/me`,
        {
          method: http.RequestMethod.PATCH,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          extraData: JSON.stringify(updates),
          connectTimeout: 30000,
          readTimeout: 30000
        }
      );

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string);
        this.currentUser = {
          ...this.currentUser,
          ...result
        };
        await this.saveAuthState();
        return true;
      }

      return false;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Update user info failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  // ==================== 私有方法 ====================

  /**
   * 请求华为OAuth授权
   */
  private async requestHuaweiOAuth(): Promise<{ success: boolean; authCode?: string; error?: string }> {
    try {
      // 使用华为账号SDK进行OAuth授权
      // 实际实现需要集成华为账号Kit
      // 这里提供模拟实现

      // 模拟授权成功
      return {
        success: true,
        authCode: 'hw_auth_code_' + Date.now()
      };

    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  /**
   * 使用授权码换取Token
   */
  private async exchangeAuthCodeForToken(authCode: string): Promise<{ success: boolean; token?: TokenInfo; error?: string }> {
    try {
      const httpRequest = http.createHttp();

      const response = await httpRequest.request(
        `${this.serverUrl}/api/v1/auth/huawei/callback`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            code: authCode,
            clientId: this.clientId
          }),
          connectTimeout: 30000,
          readTimeout: 30000
        }
      );

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string);
        return {
          success: true,
          token: {
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
            expiresIn: result.expiresIn,
            tokenType: result.tokenType || 'Bearer',
            expiresAt: Date.now() + result.expiresIn * 1000
          }
        };
      }

      return {
        success: false,
        error: `Token exchange failed: ${response.responseCode}`
      };

    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  /**
   * 获取用户信息
   */
  private async fetchUserInfo(accessToken: string): Promise<{ success: boolean; user?: UserInfo; error?: string }> {
    try {
      const httpRequest = http.createHttp();

      const response = await httpRequest.request(
        `${this.serverUrl}/api/v1/users/me`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Authorization': `Bearer ${accessToken}`
          },
          connectTimeout: 30000,
          readTimeout: 30000
        }
      );

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string);
        return {
          success: true,
          user: {
            id: result.id,
            huaweiId: result.huaweiId,
            nickname: result.nickname || '骑行者',
            avatar: result.avatar,
            email: result.email,
            phone: result.phone,
            createdAt: result.createdAt,
            updatedAt: result.updatedAt
          }
        };
      }

      return {
        success: false,
        error: `Fetch user info failed: ${response.responseCode}`
      };

    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  /**
   * 撤销Token
   */
  private async revokeToken(accessToken: string): Promise<void> {
    try {
      const httpRequest = http.createHttp();

      await httpRequest.request(
        `${this.serverUrl}/api/v1/auth/logout`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Authorization': `Bearer ${accessToken}`
          },
          connectTimeout: 30000,
          readTimeout: 30000
        }
      );

      httpRequest.destroy();

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Revoke token failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 恢复认证状态
   */
  private async restoreAuthState(): Promise<void> {
    if (!this.preferences) return;

    try {
      const accessToken = await this.preferences.get(this.KEY_ACCESS_TOKEN, '') as string;
      const refreshToken = await this.preferences.get(this.KEY_REFRESH_TOKEN, '') as string;
      const expiresAt = await this.preferences.get(this.KEY_TOKEN_EXPIRES, 0) as number;
      const userInfoStr = await this.preferences.get(this.KEY_USER_INFO, '') as string;

      if (accessToken && refreshToken) {
        this.tokenInfo = {
          accessToken,
          refreshToken,
          expiresIn: 0,
          tokenType: 'Bearer',
          expiresAt
        };

        if (userInfoStr) {
          this.currentUser = JSON.parse(userInfoStr);
        }

        // 检查Token是否过期
        if (Date.now() < expiresAt) {
          this.status = LoginStatus.LOGGED_IN;
        } else {
          this.status = LoginStatus.TOKEN_EXPIRED;
        }
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Restore auth state failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 保存认证状态
   */
  private async saveAuthState(): Promise<void> {
    if (!this.preferences) return;

    try {
      if (this.tokenInfo) {
        await this.preferences.put(this.KEY_ACCESS_TOKEN, this.tokenInfo.accessToken);
        await this.preferences.put(this.KEY_REFRESH_TOKEN, this.tokenInfo.refreshToken);
        await this.preferences.put(this.KEY_TOKEN_EXPIRES, this.tokenInfo.expiresAt);
      }

      if (this.currentUser) {
        await this.preferences.put(this.KEY_USER_INFO, JSON.stringify(this.currentUser));
      }

      await this.preferences.flush();

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Save auth state failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 清除认证状态
   */
  private async clearAuthState(): Promise<void> {
    if (!this.preferences) return;

    try {
      await this.preferences.delete(this.KEY_ACCESS_TOKEN);
      await this.preferences.delete(this.KEY_REFRESH_TOKEN);
      await this.preferences.delete(this.KEY_TOKEN_EXPIRES);
      await this.preferences.delete(this.KEY_USER_INFO);
      await this.preferences.flush();

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Clear auth state failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 设置状态并通知
   */
  private setStatus(status: LoginStatus, user?: UserInfo): void {
    this.status = status;

    for (const callback of this.statusCallbacks) {
      try {
        callback(status, user);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Status callback error: %{public}s', JSON.stringify(error));
      }
    }
  }
}

// 导出单例
export default new AuthService();

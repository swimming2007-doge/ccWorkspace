/**
 * Strava 同步服务
 *
 * 功能说明：
 * - Strava OAuth 认证
 * - 骑行数据上传
 * - GPX 文件转换
 * - 同步状态管理
 *
 * SRS引用: FR-008-01
 */
import hilog from '@ohos.hilog';
import { Coordinate } from '../utils/Types';

const TAG = '[StravaService]';
const DOMAIN = 0xFF00;

/**
 * Strava API 配置
 */
export const STRAVA_CONFIG = {
  // 实际使用时替换为真实的 Client ID
  CLIENT_ID: 'your_strava_client_id',
  CLIENT_SECRET: 'your_strava_client_secret',
  REDIRECT_URI: 'riderecord://strava/callback',
  AUTH_URL: 'https://www.strava.com/oauth/authorize',
  TOKEN_URL: 'https://www.strava.com/oauth/token',
  API_BASE_URL: 'https://www.strava.com/api/v3',
  UPLOAD_URL: 'https://www.strava.com/api/v3/uploads'
};

/**
 * OAuth 授权范围
 */
export const STRAVA_SCOPES = [
  'read',
  'read_all',
  'profile:read_all',
  'profile:write',
  'activity:read',
  'activity:read_all',
  'activity:write'
];

/**
 * Strava 认证令牌
 */
export interface StravaToken {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;      // 过期时间戳
  tokenType: string;
  athleteId: number;
  athleteName?: string;
  athleteProfile?: string;
}

/**
 * Strava 活动数据
 */
export interface StravaActivity {
  id: number;
  name: string;
  type: string;
  startDate: string;
  distance: number;
  movingTime: number;
  elapsedTime: number;
  totalElevationGain: number;
  averageSpeed: number;
  maxSpeed: number;
  averageHeartRate?: number;
  maxHeartRate?: number;
  calories?: number;
  map?: {
    summaryPolyline: string;
    polyline?: string;
  };
}

/**
 * Strava 运动员信息
 */
export interface StravaAthlete {
  id: number;
  username: string;
  firstname: string;
  lastname: string;
  profile: string;
  city: string;
  state: string;
  country: string;
}

/**
 * 上传状态
 */
export enum UploadStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  READY = 'ready',
  ERROR = 'error',
  DELETED = 'deleted'
}

/**
 * 上传结果
 */
export interface UploadResult {
  id: number;
  externalId: string;
  error?: string;
  status: UploadStatus;
  activityId?: number;
}

/**
 * 同步记录
 */
export interface SyncRecord {
  rideId: string;
  stravaActivityId?: number;
  status: 'pending' | 'syncing' | 'completed' | 'error';
  uploadedAt?: number;
  error?: string;
}

/**
 * 同步配置
 */
export interface StravaSyncConfig {
  autoSync: boolean;           // 自动同步
  syncOnWifiOnly: boolean;     // 仅WiFi下同步
  syncPhotos: boolean;         // 同步照片
  activityType: string;        // 活动类型
  commute: boolean;            // 标记为通勤
  privateActivity: boolean;    // 私密活动
}

/**
 * 默认同步配置
 */
export const DEFAULT_STRAVA_SYNC_CONFIG: StravaSyncConfig = {
  autoSync: true,
  syncOnWifiOnly: false,
  syncPhotos: true,
  activityType: 'Ride',
  commute: false,
  privateActivity: false
};

/**
 * Strava 同步服务
 */
export class StravaService {
  private static instance: StravaService;

  // 认证信息
  private token: StravaToken | null = null;

  // 同步记录
  private syncRecords: Map<string, SyncRecord> = new Map();

  // 配置
  private syncConfig: StravaSyncConfig = DEFAULT_STRAVA_SYNC_CONFIG;

  // 回调
  private onAuthCallback?: (success: boolean, error?: string) => void;
  private onSyncCallback?: (rideId: string, status: SyncRecord['status']) => void;

  private constructor() {
    this.loadToken();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): StravaService {
    if (!StravaService.instance) {
      StravaService.instance = new StravaService();
    }
    return StravaService.instance;
  }

  // ==================== 认证功能 ====================

  /**
   * 检查是否已认证
   */
  isAuthenticated(): boolean {
    return this.token !== null && Date.now() < this.token.expiresAt * 1000;
  }

  /**
   * 获取授权URL
   */
  getAuthorizationUrl(): string {
    const params = new URLSearchParams({
      client_id: STRAVA_CONFIG.CLIENT_ID,
      redirect_uri: STRAVA_CONFIG.REDIRECT_URI,
      response_type: 'code',
      scope: STRAVA_SCOPES.join(','),
      approval_prompt: 'auto'
    });

    return `${STRAVA_CONFIG.AUTH_URL}?${params.toString()}`;
  }

  /**
   * 处理授权回调
   */
  async handleAuthCallback(code: string): Promise<boolean> {
    try {
      const token = await this.exchangeCodeForToken(code);

      if (token) {
        this.token = token;
        await this.saveToken();

        hilog.info(DOMAIN, TAG, `Strava auth successful, athlete: ${token.athleteName}`);

        if (this.onAuthCallback) {
          this.onAuthCallback(true);
        }

        return true;
      }

      return false;

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Strava auth failed: ${error}`);

      if (this.onAuthCallback) {
        this.onAuthCallback(false, String(error));
      }

      return false;
    }
  }

  /**
   * 用授权码换取令牌
   */
  private async exchangeCodeForToken(code: string): Promise<StravaToken | null> {
    // 在实际实现中，应该调用 Strava Token API
    // POST https://www.strava.com/oauth/token

    hilog.info(DOMAIN, TAG, 'Exchanging code for token');

    // 模拟 API 调用
    await new Promise(resolve => setTimeout(resolve, 500));

    // 返回模拟令牌
    return {
      accessToken: 'mock_access_token_' + Date.now(),
      refreshToken: 'mock_refresh_token_' + Date.now(),
      expiresAt: Math.floor(Date.now() / 1000) + 21600, // 6小时后过期
      tokenType: 'Bearer',
      athleteId: 12345,
      athleteName: 'Test Athlete',
      athleteProfile: 'https://example.com/profile.jpg'
    };
  }

  /**
   * 刷新访问令牌
   */
  async refreshToken(): Promise<boolean> {
    if (!this.token) {
      return false;
    }

    try {
      // 在实际实现中，应该调用 Strava Token 刷新 API
      hilog.info(DOMAIN, TAG, 'Refreshing token');

      // 模拟刷新
      await new Promise(resolve => setTimeout(resolve, 300));

      this.token = {
        ...this.token,
        accessToken: 'new_access_token_' + Date.now(),
        expiresAt: Math.floor(Date.now() / 1000) + 21600
      };

      await this.saveToken();
      return true;

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Token refresh failed: ${error}`);
      return false;
    }
  }

  /**
   * 注销登录
   */
  async logout(): Promise<void> {
    this.token = null;
    this.syncRecords.clear();
    await this.clearToken();

    hilog.info(DOMAIN, TAG, 'Strava logged out');
  }

  // ==================== 活动同步 ====================

  /**
   * 上传骑行活动
   */
  async uploadActivity(rideData: RideDataForStrava): Promise<UploadResult> {
    if (!this.isAuthenticated()) {
      throw new Error('未登录 Strava');
    }

    // 检查令牌是否需要刷新
    if (this.token && Date.now() > (this.token.expiresAt - 300) * 1000) {
      const refreshed = await this.refreshToken();
      if (!refreshed) {
        throw new Error('令牌刷新失败');
      }
    }

    try {
      // 更新同步状态
      this.updateSyncRecord(rideData.rideId, 'syncing');

      // 生成 GPX 文件
      const gpxContent = this.generateGPX(rideData);

      // 上传到 Strava
      const result = await this.uploadToStorage(gpxContent, rideData);

      // 更新同步状态
      if (result.status === UploadStatus.READY || result.activityId) {
        this.updateSyncRecord(rideData.rideId, 'completed', result.activityId);
      } else if (result.status === UploadStatus.ERROR) {
        this.updateSyncRecord(rideData.rideId, 'error', undefined, result.error);
      }

      return result;

    } catch (error) {
      this.updateSyncRecord(rideData.rideId, 'error', undefined, String(error));
      throw error;
    }
  }

  /**
   * 上传到 Strava
   */
  private async uploadToStorage(
    gpxContent: string,
    rideData: RideDataForStrava
  ): Promise<UploadResult> {
    // 在实际实现中，应该调用 Strava Upload API
    // POST https://www.strava.com/api/v3/uploads
    // Content-Type: multipart/form-data

    hilog.info(DOMAIN, TAG, `Uploading activity: ${rideData.rideId}`);

    // 模拟上传
    await new Promise(resolve => setTimeout(resolve, 1000));

    // 返回模拟结果
    return {
      id: Date.now(),
      externalId: rideData.rideId,
      status: UploadStatus.READY,
      activityId: Math.floor(Math.random() * 1000000)
    };
  }

  /**
   * 检查上传状态
   */
  async checkUploadStatus(uploadId: number): Promise<UploadResult> {
    // 在实际实现中，应该调用 Strava Upload Status API
    // GET https://www.strava.com/api/v3/uploads/{uploadId}

    return {
      id: uploadId,
      externalId: '',
      status: UploadStatus.READY
    };
  }

  /**
   * 获取活动详情
   */
  async getActivity(activityId: number): Promise<StravaActivity | null> {
    if (!this.isAuthenticated()) {
      return null;
    }

    // 在实际实现中，应该调用 Strava Activity API
    // GET https://www.strava.com/api/v3/activities/{id}

    hilog.debug(DOMAIN, TAG, `Getting activity: ${activityId}`);

    // 返回模拟数据
    return {
      id: activityId,
      name: '骑行活动',
      type: 'Ride',
      startDate: new Date().toISOString(),
      distance: 25000,
      movingTime: 5400,
      elapsedTime: 5700,
      totalElevationGain: 350,
      averageSpeed: 4.6,
      maxSpeed: 8.5
    };
  }

  /**
   * 删除活动
   */
  async deleteActivity(activityId: number): Promise<boolean> {
    if (!this.isAuthenticated()) {
      return false;
    }

    // 在实际实现中，应该调用 Strava Delete Activity API
    // DELETE https://www.strava.com/api/v3/activities/{id}

    hilog.info(DOMAIN, TAG, `Deleting activity: ${activityId}`);

    return true;
  }

  // ==================== GPX 生成 ====================

  /**
   * 生成 GPX 文件内容
   */
  generateGPX(rideData: RideDataForStrava): string {
    const lines: string[] = [];

    // GPX 头部
    lines.push('<?xml version="1.0" encoding="UTF-8"?>');
    lines.push('<gpx version="1.1" creator="RideRecord"');
    lines.push('  xmlns="http://www.topografix.com/GPX/1/1"');
    lines.push('  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
    lines.push('  xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">');

    // 元数据
    lines.push('  <metadata>');
    lines.push(`    <name>${this.escapeXml(rideData.name || '骑行记录')}</name>`);
    lines.push(`    <time>${new Date(rideData.startTime).toISOString()}</time>`);
    lines.push('  </metadata>');

    // 轨迹
    lines.push('  <trk>');
    lines.push(`    <name>${this.escapeXml(rideData.name || '骑行记录')}</name>`);
    lines.push(`    <type>${this.syncConfig.activityType}</type>`);
    lines.push('    <trkseg>');

    // 轨迹点
    for (const point of rideData.trackPoints) {
      lines.push('      <trkpt>');
      lines.push(`        lat="${point.latitude.toFixed(8)}" lon="${point.longitude.toFixed(8)}"`);

      if (point.altitude !== undefined) {
        lines.push(`        <ele>${point.altitude.toFixed(1)}</ele>`);
      }

      if (point.timestamp) {
        lines.push(`        <time>${new Date(point.timestamp).toISOString()}</time>`);
      }

      // 扩展数据
      if (point.heartRate || point.speed || point.cadence) {
        lines.push('        <extensions>');
        lines.push('          <gpxtpx:TrackPointExtension xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">');

        if (point.heartRate) {
          lines.push(`            <gpxtpx:hr>${point.heartRate}</gpxtpx:hr>`);
        }

        if (point.speed) {
          lines.push(`            <gpxtpx:speed>${point.speed.toFixed(2)}</gpxtpx:speed>`);
        }

        if (point.cadence) {
          lines.push(`            <gpxtpx:cad>${point.cadence}</gpxtpx:cad>`);
        }

        lines.push('          </gpxtpx:TrackPointExtension>');
        lines.push('        </extensions>');
      }

      lines.push('      </trkpt>');
    }

    lines.push('    </trkseg>');
    lines.push('  </trk>');
    lines.push('</gpx>');

    return lines.join('\n');
  }

  // ==================== 同步记录管理 ====================

  /**
   * 获取同步记录
   */
  getSyncRecord(rideId: string): SyncRecord | undefined {
    return this.syncRecords.get(rideId);
  }

  /**
   * 获取所有同步记录
   */
  getAllSyncRecords(): SyncRecord[] {
    return Array.from(this.syncRecords.values());
  }

  /**
   * 更新同步记录
   */
  private updateSyncRecord(
    rideId: string,
    status: SyncRecord['status'],
    stravaActivityId?: number,
    error?: string
  ): void {
    const record: SyncRecord = {
      rideId,
      stravaActivityId,
      status,
      uploadedAt: status === 'completed' ? Date.now() : undefined,
      error
    };

    this.syncRecords.set(rideId, record);

    if (this.onSyncCallback) {
      this.onSyncCallback(rideId, status);
    }

    this.saveSyncRecords();
  }

  /**
   * 检查是否已同步
   */
  isSynced(rideId: string): boolean {
    const record = this.syncRecords.get(rideId);
    return record?.status === 'completed';
  }

  // ==================== 配置管理 ====================

  /**
   * 获取同步配置
   */
  getSyncConfig(): StravaSyncConfig {
    return { ...this.syncConfig };
  }

  /**
   * 更新同步配置
   */
  async updateSyncConfig(config: Partial<StravaSyncConfig>): Promise<void> {
    this.syncConfig = { ...this.syncConfig, ...config };
    await this.saveSyncConfig();
  }

  // ==================== 回调设置 ====================

  /**
   * 设置认证回调
   */
  setAuthCallback(callback: (success: boolean, error?: string) => void): void {
    this.onAuthCallback = callback;
  }

  /**
   * 设置同步回调
   */
  setSyncCallback(callback: (rideId: string, status: SyncRecord['status']) => void): void {
    this.onSyncCallback = callback;
  }

  // ==================== 运动员信息 ====================

  /**
   * 获取当前运动员信息
   */
  async getAthlete(): Promise<StravaAthlete | null> {
    if (!this.isAuthenticated()) {
      return null;
    }

    // 在实际实现中，应该调用 Strava Athlete API
    // GET https://www.strava.com/api/v3/athlete

    return {
      id: this.token?.athleteId || 0,
      username: 'test_athlete',
      firstname: 'Test',
      lastname: 'Athlete',
      profile: this.token?.athleteProfile || '',
      city: 'Beijing',
      state: '',
      country: 'China'
    };
  }

  // ==================== 持久化 ====================

  /**
   * 加载令牌
   */
  private loadToken(): void {
    // 在实际实现中，应该从持久化存储加载
    hilog.debug(DOMAIN, TAG, 'Token loaded');
  }

  /**
   * 保存令牌
   */
  private async saveToken(): Promise<void> {
    // 在实际实现中，应该保存到持久化存储
    hilog.debug(DOMAIN, TAG, 'Token saved');
  }

  /**
   * 清除令牌
   */
  private async clearToken(): Promise<void> {
    // 在实际实现中，应该从持久化存储清除
    hilog.debug(DOMAIN, TAG, 'Token cleared');
  }

  /**
   * 保存同步记录
   */
  private saveSyncRecords(): void {
    // 在实际实现中，应该保存到数据库
    hilog.debug(DOMAIN, TAG, 'Sync records saved');
  }

  /**
   * 保存同步配置
   */
  private async saveSyncConfig(): Promise<void> {
    // 在实际实现中，应该保存到持久化存储
    hilog.debug(DOMAIN, TAG, 'Sync config saved');
  }

  // ==================== 工具方法 ====================

  /**
   * XML 转义
   */
  private escapeXml(str: string): string {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }
}

/**
 * 用于 Strava 上传的骑行数据
 */
export interface RideDataForStrava {
  rideId: string;
  name?: string;
  description?: string;
  startTime: number;
  endTime: number;
  distance: number;       // 米
  duration: number;       // 秒
  avgSpeed?: number;      // m/s
  maxSpeed?: number;      // m/s
  elevation?: number;     // 米
  avgHeartRate?: number;
  maxHeartRate?: number;
  calories?: number;
  trackPoints: TrackPointForStrava[];
  photos?: string[];
}

/**
 * 用于 Strava 的轨迹点
 */
export interface TrackPointForStrava extends Coordinate {
  timestamp?: number;
  altitude?: number;
  heartRate?: number;
  speed?: number;
  cadence?: number;
}

// 导出单例
export default StravaService.getInstance();

/**
 * 用户设置服务
 *
 * 功能说明：
 * - 用户设置持久化存储
 * - 骑行偏好管理
 * - 动作检测设置
 * - 同步设置
 * - 设置变更通知
 *
 * 依赖：
 * - @ohos.data.preferences: 本地存储
 */

import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';

const TAG = '[SettingsService]';
const DOMAIN = 0xFF00;

/**
 * 导航模式
 */
export enum NavMode {
  ROAD = 'road',
  ADVENTURE = 'adventure',
  MIXED = 'mixed'
}

/**
 * 单位制
 */
export enum UnitSystem {
  METRIC = 'metric',
  IMPERIAL = 'imperial'
}

/**
 * 检测灵敏度
 */
export enum DetectionSensitivity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high'
}

/**
 * 用户骑行设置
 */
export interface RidingSettings {
  // 导航偏好
  defaultNavMode: NavMode;
  adventureRatio: number; // 探险比例 0-1
  maxRiskIndex: number; // 最大风险指数 1-5

  // 单位与显示
  unitSystem: UnitSystem;
  showHeartRate: boolean;
  showElevation: boolean;
  showCadence: boolean;

  // 语音与提示
  voiceNavigation: boolean;
  voiceAlerts: boolean;
  vibrationAlerts: boolean;
}

/**
 * 动作检测设置
 */
export interface DetectionSettings {
  autoStartStop: boolean;
  sensitivity: DetectionSensitivity;
  pauseTimeout: number; // 自动暂停超时(秒)
  minRidingTime: number; // 最小骑行时间(秒)
}

/**
 * 同步设置
 */
export interface SyncSettings {
  cloudSyncEnabled: boolean;
  autoSync: boolean;
  wifiOnlySync: boolean;
  syncInterval: number; // 同步间隔(分钟)
}

/**
 * 隐私设置
 */
export interface PrivacySettings {
  shareLocation: boolean;
  shareHeartRate: boolean;
  publicProfile: boolean;
}

/**
 * 完整用户设置
 */
export interface UserSettings {
  riding: RidingSettings;
  detection: DetectionSettings;
  sync: SyncSettings;
  privacy: PrivacySettings;
}

/**
 * 设置变更回调
 */
export type SettingsChangeCallback = (key: string, value: any) => void;

/**
 * 默认设置
 */
const DEFAULT_SETTINGS: UserSettings = {
  riding: {
    defaultNavMode: NavMode.ROAD,
    adventureRatio: 0.3,
    maxRiskIndex: 3,
    unitSystem: UnitSystem.METRIC,
    showHeartRate: true,
    showElevation: true,
    showCadence: false,
    voiceNavigation: true,
    voiceAlerts: true,
    vibrationAlerts: true
  },
  detection: {
    autoStartStop: true,
    sensitivity: DetectionSensitivity.MEDIUM,
    pauseTimeout: 30,
    minRidingTime: 10
  },
  sync: {
    cloudSyncEnabled: true,
    autoSync: true,
    wifiOnlySync: true,
    syncInterval: 5
  },
  privacy: {
    shareLocation: true,
    shareHeartRate: false,
    publicProfile: false
  }
};

/**
 * 用户设置服务类
 */
export class SettingsService {
  private readonly PREF_NAME = 'user_settings';
  private preferences: preferences.Preferences | null = null;
  private settings: UserSettings = { ...DEFAULT_SETTINGS };
  private callbacks: SettingsChangeCallback[] = [];

  /**
   * 初始化设置服务
   */
  async initialize(): Promise<void> {
    try {
      this.preferences = await preferences.getPreferences(this.PREF_NAME);
      await this.loadSettings();
      hilog.info(DOMAIN, TAG, 'SettingsService initialized');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 获取所有设置
   */
  getSettings(): UserSettings {
    return { ...this.settings };
  }

  /**
   * 获取骑行设置
   */
  getRidingSettings(): RidingSettings {
    return { ...this.settings.riding };
  }

  /**
   * 获取动作检测设置
   */
  getDetectionSettings(): DetectionSettings {
    return { ...this.settings.detection };
  }

  /**
   * 获取同步设置
   */
  getSyncSettings(): SyncSettings {
    return { ...this.settings.sync };
  }

  /**
   * 获取隐私设置
   */
  getPrivacySettings(): PrivacySettings {
    return { ...this.settings.privacy };
  }

  /**
   * 更新骑行设置
   */
  async updateRidingSettings(updates: Partial<RidingSettings>): Promise<void> {
    this.settings.riding = { ...this.settings.riding, ...updates };
    await this.saveSettings();
    this.notifyChange('riding', this.settings.riding);
  }

  /**
   * 更新动作检测设置
   */
  async updateDetectionSettings(updates: Partial<DetectionSettings>): Promise<void> {
    this.settings.detection = { ...this.settings.detection, ...updates };
    await this.saveSettings();
    this.notifyChange('detection', this.settings.detection);
  }

  /**
   * 更新同步设置
   */
  async updateSyncSettings(updates: Partial<SyncSettings>): Promise<void> {
    this.settings.sync = { ...this.settings.sync, ...updates };
    await this.saveSettings();
    this.notifyChange('sync', this.settings.sync);
  }

  /**
   * 更新隐私设置
   */
  async updatePrivacySettings(updates: Partial<PrivacySettings>): Promise<void> {
    this.settings.privacy = { ...this.settings.privacy, ...updates };
    await this.saveSettings();
    this.notifyChange('privacy', this.settings.privacy);
  }

  /**
   * 重置为默认设置
   */
  async resetToDefault(): Promise<void> {
    this.settings = { ...DEFAULT_SETTINGS };
    await this.saveSettings();
    this.notifyChange('all', this.settings);
    hilog.info(DOMAIN, TAG, 'Settings reset to default');
  }

  /**
   * 注册设置变更回调
   */
  onSettingsChange(callback: SettingsChangeCallback): void {
    this.callbacks.push(callback);
  }

  /**
   * 取消注册回调
   */
  offSettingsChange(callback: SettingsChangeCallback): void {
    const index = this.callbacks.indexOf(callback);
    if (index > -1) {
      this.callbacks.splice(index, 1);
    }
  }

  // ==================== 私有方法 ====================

  /**
   * 加载设置
   */
  private async loadSettings(): Promise<void> {
    if (!this.preferences) return;

    try {
      // 加载骑行设置
      const ridingStr = await this.preferences.get('riding', '') as string;
      if (ridingStr) {
        this.settings.riding = { ...DEFAULT_SETTINGS.riding, ...JSON.parse(ridingStr) };
      }

      // 加载检测设置
      const detectionStr = await this.preferences.get('detection', '') as string;
      if (detectionStr) {
        this.settings.detection = { ...DEFAULT_SETTINGS.detection, ...JSON.parse(detectionStr) };
      }

      // 加载同步设置
      const syncStr = await this.preferences.get('sync', '') as string;
      if (syncStr) {
        this.settings.sync = { ...DEFAULT_SETTINGS.sync, ...JSON.parse(syncStr) };
      }

      // 加载隐私设置
      const privacyStr = await this.preferences.get('privacy', '') as string;
      if (privacyStr) {
        this.settings.privacy = { ...DEFAULT_SETTINGS.privacy, ...JSON.parse(privacyStr) };
      }

      hilog.info(DOMAIN, TAG, 'Settings loaded');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load settings: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 保存设置
   */
  private async saveSettings(): Promise<void> {
    if (!this.preferences) return;

    try {
      await this.preferences.put('riding', JSON.stringify(this.settings.riding));
      await this.preferences.put('detection', JSON.stringify(this.settings.detection));
      await this.preferences.put('sync', JSON.stringify(this.settings.sync));
      await this.preferences.put('privacy', JSON.stringify(this.settings.privacy));
      await this.preferences.flush();

      hilog.info(DOMAIN, TAG, 'Settings saved');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to save settings: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 通知设置变更
   */
  private notifyChange(key: string, value: any): void {
    for (const callback of this.callbacks) {
      try {
        callback(key, value);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Callback error: %{public}s', JSON.stringify(error));
      }
    }
  }
}

// 导出单例
export default new SettingsService();

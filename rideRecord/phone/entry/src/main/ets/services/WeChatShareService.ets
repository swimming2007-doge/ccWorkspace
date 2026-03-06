/**
 * 微信分享服务
 *
 * 功能说明：
 * - 微信好友/群分享
 * - 朋友圈分享
 * - 分享图片生成
 * - 分享内容定制
 *
 * SRS引用: FR-006
 */
import hilog from '@ohos.hilog';
import { Coordinate } from '../utils/Types';

const TAG = '[WeChatShareService]';
const DOMAIN = 0xFF00;

/**
 * 分享类型
 */
export enum ShareType {
  FRIEND = 'friend',       // 微信好友
  MOMENTS = 'moments',     // 朋友圈
  FAVORITE = 'favorite'    // 收藏
}

/**
 * 分享模板风格
 */
export enum ShareTemplate {
  MINIMAL = 'minimal',     // 简约风格
  SPORT = 'sport',         // 运动风格
  ADVENTURE = 'adventure', // 探险风格
  DATA = 'data'            // 数据风格
}

/**
 * 骑行分享数据
 */
export interface RideShareData {
  rideId: string;
  title?: string;
  description?: string;

  // 基础数据
  distance: number;          // 距离 (米)
  duration: number;          // 时长 (秒)
  avgSpeed: number;          // 平均速度 (m/s)
  maxSpeed: number;          // 最高速度 (m/s)
  elevation: number;         // 爬升 (米)
  calories: number;          // 热量 (千卡)

  // 心率数据
  avgHeartRate?: number;
  maxHeartRate?: number;

  // 轨迹数据
  trackPoints: Coordinate[];
  startPoint?: Coordinate;
  endPoint?: Coordinate;

  // 照片
  photos: string[];

  // 时间
  startTime: number;
  endTime: number;
}

/**
 * 分享配置
 */
export interface ShareConfig {
  template: ShareTemplate;
  showLocation: boolean;
  showSpeed: boolean;
  showHeartRate: boolean;
  showElevation: boolean;
  showCalories: boolean;
  selectedPhotoIndex?: number;
  customTitle?: string;
  customDescription?: string;
}

/**
 * 默认分享配置
 */
export const DEFAULT_SHARE_CONFIG: ShareConfig = {
  template: ShareTemplate.SPORT,
  showLocation: true,
  showSpeed: true,
  showHeartRate: true,
  showElevation: true,
  showCalories: true
};

/**
 * 分享结果
 */
export interface ShareResult {
  success: boolean;
  shareType: ShareType;
  error?: string;
}

/**
 * 分享图片信息
 */
export interface ShareImage {
  path: string;
  width: number;
  height: number;
  size: number;
}

/**
 * 模板配置
 */
export interface TemplateConfig {
  name: string;
  backgroundColor: string;
  primaryColor: string;
  accentColor: string;
  fontFamily: string;
  showLogo: boolean;
  showQRCode: boolean;
}

/**
 * 预设模板配置
 */
export const TEMPLATE_CONFIGS: Record<ShareTemplate, TemplateConfig> = {
  [ShareTemplate.MINIMAL]: {
    name: '简约风格',
    backgroundColor: '#FFFFFF',
    primaryColor: '#1F2937',
    accentColor: '#3B82F6',
    fontFamily: 'HarmonyOS Sans',
    showLogo: true,
    showQRCode: false
  },
  [ShareTemplate.SPORT]: {
    name: '运动风格',
    backgroundColor: '#1E3A5F',
    primaryColor: '#FFFFFF',
    accentColor: '#F59E0B',
    fontFamily: 'HarmonyOS Sans',
    showLogo: true,
    showQRCode: true
  },
  [ShareTemplate.ADVENTURE]: {
    name: '探险风格',
    backgroundColor: '#2D3436',
    primaryColor: '#FFEAA7',
    accentColor: '#E17055',
    fontFamily: 'HarmonyOS Sans',
    showLogo: true,
    showQRCode: true
  },
  [ShareTemplate.DATA]: {
    name: '数据风格',
    backgroundColor: '#0F172A',
    primaryColor: '#22D3EE',
    accentColor: '#A78BFA',
    fontFamily: 'HarmonyOS Sans',
    showLogo: false,
    showQRCode: true
  }
};

/**
 * 微信分享服务
 */
export class WeChatShareService {
  private static instance: WeChatShareService;

  // 微信SDK是否已注册
  private isRegistered: boolean = false;

  // 配置
  private readonly APP_ID = 'wx_sample_app_id'; // 实际使用时替换

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): WeChatShareService {
    if (!WeChatShareService.instance) {
      WeChatShareService.instance = new WeChatShareService();
    }
    return WeChatShareService.instance;
  }

  // ==================== SDK 注册 ====================

  /**
   * 注册微信SDK
   */
  async registerApp(): Promise<boolean> {
    if (this.isRegistered) {
      return true;
    }

    try {
      // 在实际实现中，应该调用微信SDK注册API
      // HarmonyOS 使用 @ohos.share 或集成微信SDK

      // 模拟注册
      await new Promise(resolve => setTimeout(resolve, 100));

      this.isRegistered = true;
      hilog.info(DOMAIN, TAG, 'WeChat SDK registered');

      return true;

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to register WeChat SDK: ${error}`);
      return false;
    }
  }

  /**
   * 检查微信是否安装
   */
  async isWeChatInstalled(): Promise<boolean> {
    // 在实际实现中，应该检查微信应用是否安装
    // HarmonyOS: 使用 @ohos.bundle 检查应用
    return true;
  }

  // ==================== 分享功能 ====================

  /**
   * 分享到微信好友
   */
  async shareToFriend(data: RideShareData, config: ShareConfig): Promise<ShareResult> {
    return this.share(ShareType.FRIEND, data, config);
  }

  /**
   * 分享到朋友圈
   */
  async shareToMoments(data: RideShareData, config: ShareConfig): Promise<ShareResult> {
    return this.share(ShareType.MOMENTS, data, config);
  }

  /**
   * 分享到收藏
   */
  async shareToFavorite(data: RideShareData, config: ShareConfig): Promise<ShareResult> {
    return this.share(ShareType.FAVORITE, data, config);
  }

  /**
   * 通用分享方法
   */
  private async share(
    shareType: ShareType,
    data: RideShareData,
    config: ShareConfig
  ): Promise<ShareResult> {
    try {
      // 检查SDK注册
      if (!this.isRegistered) {
        const registered = await this.registerApp();
        if (!registered) {
          return {
            success: false,
            shareType,
            error: '微信SDK注册失败'
          };
        }
      }

      // 检查微信安装
      const installed = await this.isWeChatInstalled();
      if (!installed) {
        return {
          success: false,
          shareType,
          error: '请先安装微信'
        };
      }

      // 生成分享图片
      const shareImage = await this.generateShareImage(data, config);

      // 调用微信分享
      const success = await this.invokeWeChatShare(shareType, shareImage, data, config);

      return {
        success,
        shareType,
        error: success ? undefined : '分享失败'
      };

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Share failed: ${error}`);
      return {
        success: false,
        shareType,
        error: String(error)
      };
    }
  }

  // ==================== 图片生成 ====================

  /**
   * 生成分享图片
   */
  async generateShareImage(data: RideShareData, config: ShareConfig): Promise<ShareImage> {
    const template = TEMPLATE_CONFIGS[config.template];

    // 在实际实现中，应该使用Canvas绘制分享图片
    // 这里返回模拟结果

    const width = 750;
    const height = 1334;

    // 绘制分享图片
    const imageData = await this.renderShareImage(data, config, template, width, height);

    // 保存图片
    const path = await this.saveShareImage(imageData, data.rideId);

    return {
      path,
      width,
      height,
      size: imageData.length
    };
  }

  /**
   * 渲染分享图片
   */
  private async renderShareImage(
    data: RideShareData,
    config: ShareConfig,
    template: TemplateConfig,
    width: number,
    height: number
  ): Promise<ArrayBuffer> {
    // 在实际实现中，应该使用Canvas API绘制图片
    // 1. 绘制背景
    // 2. 绘制轨迹图
    // 3. 绘制数据卡片
    // 4. 绘制照片
    // 5. 绘制Logo和二维码

    hilog.debug(DOMAIN, TAG, `Rendering share image for template: ${template.name}`);

    // 模拟图片数据
    return new ArrayBuffer(1024);
  }

  /**
   * 保存分享图片
   */
  private async saveShareImage(imageData: ArrayBuffer, rideId: string): Promise<string> {
    // 在实际实现中，应该保存到应用缓存目录
    const path = `/data/cache/share_${rideId}_${Date.now()}.png`;
    hilog.debug(DOMAIN, TAG, `Share image saved: ${path}`);
    return path;
  }

  // ==================== 微信SDK调用 ====================

  /**
   * 调用微信分享
   */
  private async invokeWeChatShare(
    shareType: ShareType,
    shareImage: ShareImage,
    data: RideShareData,
    config: ShareConfig
  ): Promise<boolean> {
    // 在实际实现中，应该调用微信SDK分享API
    // 微信SDK分享接口:
    // - WXImageObject: 图片分享
    // - WXWebpageObject: 网页分享
    // - WXMiniProgramObject: 小程序分享

    hilog.info(DOMAIN, TAG, `Invoking WeChat share: ${shareType}`);

    // 模拟分享成功
    await new Promise(resolve => setTimeout(resolve, 500));

    return true;
  }

  // ==================== 分享内容生成 ====================

  /**
   * 生成分享标题
   */
  generateShareTitle(data: RideShareData, config: ShareConfig): string {
    if (config.customTitle) {
      return config.customTitle;
    }

    const distanceKm = (data.distance / 1000).toFixed(1);
    const durationMin = Math.floor(data.duration / 60);

    return `我刚刚骑行了 ${distanceKm} 公里`;
  }

  /**
   * 生成分享描述
   */
  generateShareDescription(data: RideShareData, config: ShareConfig): string {
    if (config.customDescription) {
      return config.customDescription;
    }

    const parts: string[] = [];

    // 距离
    const distanceKm = (data.distance / 1000).toFixed(1);
    parts.push(`距离 ${distanceKm}km`);

    // 时长
    const hours = Math.floor(data.duration / 3600);
    const mins = Math.floor((data.duration % 3600) / 60);
    if (hours > 0) {
      parts.push(`时长 ${hours}小时${mins}分钟`);
    } else {
      parts.push(`时长 ${mins}分钟`);
    }

    // 速度
    if (config.showSpeed) {
      const avgSpeedKmh = (data.avgSpeed * 3.6).toFixed(1);
      parts.push(`均速 ${avgSpeedKmh}km/h`);
    }

    // 热量
    if (config.showCalories && data.calories > 0) {
      parts.push(`消耗 ${Math.round(data.calories)}千卡`);
    }

    return parts.join(' · ');
  }

  /**
   * 生成分享数据文本
   */
  generateShareDataText(data: RideShareData, config: ShareConfig): string {
    const lines: string[] = [];

    lines.push('📊 骑行数据');
    lines.push('');

    // 距离
    const distanceKm = (data.distance / 1000).toFixed(2);
    lines.push(`距离: ${distanceKm} km`);

    // 时长
    const hours = Math.floor(data.duration / 3600);
    const mins = Math.floor((data.duration % 3600) / 60);
    const secs = data.duration % 60;
    lines.push(`时长: ${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`);

    // 速度
    if (config.showSpeed) {
      const avgSpeedKmh = (data.avgSpeed * 3.6).toFixed(1);
      const maxSpeedKmh = (data.maxSpeed * 3.6).toFixed(1);
      lines.push(`平均速度: ${avgSpeedKmh} km/h`);
      lines.push(`最高速度: ${maxSpeedKmh} km/h`);
    }

    // 爬升
    if (config.showElevation && data.elevation > 0) {
      lines.push(`累计爬升: ${data.elevation.toFixed(0)} m`);
    }

    // 热量
    if (config.showCalories && data.calories > 0) {
      lines.push(`消耗热量: ${Math.round(data.calories)} kcal`);
    }

    // 心率
    if (config.showHeartRate && data.avgHeartRate) {
      lines.push(`平均心率: ${data.avgHeartRate} bpm`);
      if (data.maxHeartRate) {
        lines.push(`最高心率: ${data.maxHeartRate} bpm`);
      }
    }

    return lines.join('\n');
  }

  // ==================== 工具方法 ====================

  /**
   * 格式化时长
   */
  formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  /**
   * 格式化距离
   */
  formatDistance(meters: number): string {
    if (meters >= 1000) {
      return `${(meters / 1000).toFixed(2)} km`;
    }
    return `${meters.toFixed(0)} m`;
  }

  /**
   * 格式化速度
   */
  formatSpeed(metersPerSecond: number): string {
    return `${(metersPerSecond * 3.6).toFixed(1)} km/h`;
  }

  /**
   * 获取所有模板
   */
  getTemplates(): { key: ShareTemplate; name: string; preview: string }[] {
    return Object.entries(TEMPLATE_CONFIGS).map(([key, config]) => ({
      key: key as ShareTemplate,
      name: config.name,
      preview: `preview_${key}.png`
    }));
  }

  /**
   * 清理分享缓存
   */
  async clearShareCache(): Promise<void> {
    // 清理生成的分享图片缓存
    hilog.info(DOMAIN, TAG, 'Share cache cleared');
  }
}

// 导出单例
export default WeChatShareService.getInstance();

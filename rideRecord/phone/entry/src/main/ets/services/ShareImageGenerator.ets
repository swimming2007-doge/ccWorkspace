/**
 * 分享图片生成器
 *
 * 功能说明：
 * - 绘制分享卡片图片
 * - 轨迹路线图渲染
 * - 数据统计卡片
 * - 多种模板样式
 *
 * SRS引用: FR-006
 */
import hilog from '@ohos.hilog';
import { Coordinate } from '../utils/Types';
import {
  RideShareData,
  ShareConfig,
  ShareTemplate,
  TEMPLATE_CONFIGS,
  TemplateConfig
} from './WeChatShareService';

const TAG = '[ShareImageGenerator]';
const DOMAIN = 0xFF00;

/**
 * 图片尺寸
 */
export interface ImageSize {
  width: number;
  height: number;
}

/**
 * 绘图上下文
 */
interface DrawContext {
  canvas: any;
  width: number;
  height: number;
  scale: number;
}

/**
 * 轨迹样式
 */
export interface TrackStyle {
  lineColor: string;
  lineWidth: number;
  startPointColor: string;
  endPointColor: string;
  showMarkers: boolean;
  gradient?: boolean;
}

/**
 * 数据卡片样式
 */
export interface DataCardStyle {
  backgroundColor: string;
  borderRadius: number;
  padding: number;
  titleFontSize: number;
  valueFontSize: number;
  unitFontSize: number;
}

/**
 * 默认图片尺寸
 */
export const SHARE_IMAGE_SIZE: ImageSize = {
  width: 750,
  height: 1334
};

/**
 * 分享图片生成器
 */
export class ShareImageGenerator {
  private static instance: ShareImageGenerator;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): ShareImageGenerator {
    if (!ShareImageGenerator.instance) {
      ShareImageGenerator.instance = new ShareImageGenerator();
    }
    return ShareImageGenerator.instance;
  }

  // ==================== 主生成方法 ====================

  /**
   * 生成分享图片
   */
  async generateImage(
    data: RideShareData,
    config: ShareConfig
  ): Promise<ArrayBuffer> {
    const template = TEMPLATE_CONFIGS[config.template];
    const { width, height } = SHARE_IMAGE_SIZE;

    hilog.info(DOMAIN, TAG, `Generating share image: ${template.name}`);

    // 创建画布上下文
    const ctx = this.createContext(width, height);

    // 1. 绘制背景
    this.drawBackground(ctx, template);

    // 2. 绘制头部区域
    this.drawHeader(ctx, data, config, template);

    // 3. 绘制轨迹图
    const trackRect = this.calculateTrackRect(ctx, config);
    this.drawTrack(ctx, data, config, template, trackRect);

    // 4. 绘制数据卡片
    this.drawDataCards(ctx, data, config, template, trackRect);

    // 5. 绘制照片（如果有）
    if (data.photos.length > 0 && config.selectedPhotoIndex !== undefined) {
      this.drawPhoto(ctx, data.photos[config.selectedPhotoIndex], template);
    }

    // 6. 绘制底部区域
    this.drawFooter(ctx, template);

    // 7. 生成图片数据
    return this.exportImage(ctx);
  }

  // ==================== 绘制方法 ====================

  /**
   * 创建绘图上下文
   */
  private createContext(width: number, height: number): DrawContext {
    // 在实际实现中，应该创建真实的Canvas上下文
    // HarmonyOS: 使用 CanvasRenderingContext2D
    return {
      canvas: null,
      width,
      height,
      scale: 2
    };
  }

  /**
   * 绘制背景
   */
  private drawBackground(ctx: DrawContext, template: TemplateConfig): void {
    // 根据模板设置背景
    // - 纯色背景
    // - 渐变背景
    // - 纹理背景

    hilog.debug(DOMAIN, TAG, `Drawing background: ${template.backgroundColor}`);
  }

  /**
   * 绘制头部区域
   */
  private drawHeader(
    ctx: DrawContext,
    data: RideShareData,
    config: ShareConfig,
    template: TemplateConfig
  ): void {
    const headerHeight = 120;

    // 绘制Logo
    if (template.showLogo) {
      // 绘制应用Logo
    }

    // 绘制标题
    const title = config.customTitle || '骑行记录';
    // ctx.fillText(title, x, y);

    // 绘制日期
    const date = new Date(data.startTime);
    const dateStr = `${date.getFullYear()}.${(date.getMonth() + 1).toString().padStart(2, '0')}.${date.getDate().toString().padStart(2, '0')}`;
    // ctx.fillText(dateStr, x, y);

    hilog.debug(DOMAIN, TAG, 'Drawing header');
  }

  /**
   * 计算轨迹图区域
   */
  private calculateTrackRect(ctx: DrawContext, config: ShareConfig): { x: number; y: number; width: number; height: number } {
    const margin = 24;
    const headerHeight = 120;
    const cardHeight = config.showHeartRate ? 280 : 200;

    return {
      x: margin,
      y: headerHeight + 20,
      width: ctx.width - margin * 2,
      height: ctx.height - headerHeight - cardHeight - 180
    };
  }

  /**
   * 绘制轨迹图
   */
  private drawTrack(
    ctx: DrawContext,
    data: RideShareData,
    config: ShareConfig,
    template: TemplateConfig,
    rect: { x: number; y: number; width: number; height: number }
  ): void {
    if (data.trackPoints.length < 2) {
      return;
    }

    // 计算轨迹边界
    const bounds = this.calculateTrackBounds(data.trackPoints);

    // 绘制背景地图
    this.drawMapBackground(ctx, rect, template);

    // 绘制轨迹线
    const trackStyle: TrackStyle = {
      lineColor: template.accentColor,
      lineWidth: 4,
      startPointColor: '#10B981',
      endPointColor: '#EF4444',
      showMarkers: true,
      gradient: true
    };

    this.drawTrackLine(ctx, data.trackPoints, bounds, rect, trackStyle);

    // 绘制起点终点标记
    if (trackStyle.showMarkers && data.startPoint && data.endPoint) {
      this.drawMarkers(ctx, data.startPoint, data.endPoint, bounds, rect, trackStyle);
    }

    hilog.debug(DOMAIN, TAG, `Drawing track with ${data.trackPoints.length} points`);
  }

  /**
   * 计算轨迹边界
   */
  private calculateTrackBounds(points: Coordinate[]): { minLat: number; maxLat: number; minLon: number; maxLon: number } {
    let minLat = Infinity, maxLat = -Infinity;
    let minLon = Infinity, maxLon = -Infinity;

    for (const point of points) {
      minLat = Math.min(minLat, point.latitude);
      maxLat = Math.max(maxLat, point.latitude);
      minLon = Math.min(minLon, point.longitude);
      maxLon = Math.max(maxLon, point.longitude);
    }

    // 添加边距
    const latPadding = (maxLat - minLat) * 0.1 || 0.01;
    const lonPadding = (maxLon - minLon) * 0.1 || 0.01;

    return {
      minLat: minLat - latPadding,
      maxLat: maxLat + latPadding,
      minLon: minLon - lonPadding,
      maxLon: maxLon + lonPadding
    };
  }

  /**
   * 绘制地图背景
   */
  private drawMapBackground(
    ctx: DrawContext,
    rect: { x: number; y: number; width: number; height: number },
    template: TemplateConfig
  ): void {
    // 绘制半透明背景
    // ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
    // ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
  }

  /**
   * 绘制轨迹线
   */
  private drawTrackLine(
    ctx: DrawContext,
    points: Coordinate[],
    bounds: { minLat: number; maxLat: number; minLon: number; maxLon: number },
    rect: { x: number; y: number; width: number; height: number },
    style: TrackStyle
  ): void {
    // 将GPS坐标转换为画布坐标
    const toCanvasX = (lon: number): number => {
      return rect.x + ((lon - bounds.minLon) / (bounds.maxLon - bounds.minLon)) * rect.width;
    };

    const toCanvasY = (lat: number): number => {
      return rect.y + rect.height - ((lat - bounds.minLat) / (bounds.maxLat - bounds.minLat)) * rect.height;
    };

    // 绘制轨迹路径
    // ctx.beginPath();
    // ctx.moveTo(toCanvasX(points[0].longitude), toCanvasY(points[0].latitude));

    for (let i = 1; i < points.length; i++) {
      // ctx.lineTo(toCanvasX(points[i].longitude), toCanvasY(points[i].latitude));
    }

    // ctx.strokeStyle = style.lineColor;
    // ctx.lineWidth = style.lineWidth;
    // ctx.stroke();
  }

  /**
   * 绘制起点终点标记
   */
  private drawMarkers(
    ctx: DrawContext,
    startPoint: Coordinate,
    endPoint: Coordinate,
    bounds: { minLat: number; maxLat: number; minLon: number; maxLon: number },
    rect: { x: number; y: number; width: number; height: number },
    style: TrackStyle
  ): void {
    // 绘制起点标记
    // ctx.fillStyle = style.startPointColor;
    // ctx.beginPath();
    // ctx.arc(startX, startY, 8, 0, Math.PI * 2);
    // ctx.fill();

    // 绘制终点标记
    // ctx.fillStyle = style.endPointColor;
    // ctx.beginPath();
    // ctx.arc(endX, endY, 8, 0, Math.PI * 2);
    // ctx.fill();
  }

  /**
   * 绘制数据卡片
   */
  private drawDataCards(
    ctx: DrawContext,
    data: RideShareData,
    config: ShareConfig,
    template: TemplateConfig,
    trackRect: { x: number; y: number; width: number; height: number }
  ): void {
    const cardStyle: DataCardStyle = {
      backgroundColor: 'rgba(255, 255, 255, 0.15)',
      borderRadius: 16,
      padding: 20,
      titleFontSize: 12,
      valueFontSize: 32,
      unitFontSize: 14
    };

    const cardY = trackRect.y + trackRect.height + 20;
    const cardWidth = (ctx.width - 24 * 3) / 2;
    const cardHeight = 80;

    // 第一行卡片：距离、时长
    this.drawDataCard(ctx, '距离', this.formatDistance(data.distance), 'km', 24, cardY, cardWidth, cardHeight, cardStyle, template);
    this.drawDataCard(ctx, '时长', this.formatDuration(data.duration), '', 24 + cardWidth + 24, cardY, cardWidth, cardHeight, cardStyle, template);

    // 第二行卡片：均速、热量
    const row2Y = cardY + cardHeight + 16;
    if (config.showSpeed) {
      this.drawDataCard(ctx, '均速', (data.avgSpeed * 3.6).toFixed(1), 'km/h', 24, row2Y, cardWidth, cardHeight, cardStyle, template);
    }
    if (config.showCalories) {
      this.drawDataCard(ctx, '热量', Math.round(data.calories).toString(), 'kcal', 24 + cardWidth + 24, row2Y, cardWidth, cardHeight, cardStyle, template);
    }

    // 第三行：心率（如果显示）
    if (config.showHeartRate && data.avgHeartRate) {
      const row3Y = row2Y + cardHeight + 16;
      this.drawDataCard(ctx, '平均心率', data.avgHeartRate.toString(), 'bpm', 24, row3Y, cardWidth, cardHeight, cardStyle, template);
      if (data.maxHeartRate) {
        this.drawDataCard(ctx, '最高心率', data.maxHeartRate.toString(), 'bpm', 24 + cardWidth + 24, row3Y, cardWidth, cardHeight, cardStyle, template);
      }
    }

    hilog.debug(DOMAIN, TAG, 'Drawing data cards');
  }

  /**
   * 绘制单个数据卡片
   */
  private drawDataCard(
    ctx: DrawContext,
    title: string,
    value: string,
    unit: string,
    x: number,
    y: number,
    width: number,
    height: number,
    style: DataCardStyle,
    template: TemplateConfig
  ): void {
    // 绘制背景
    // ctx.fillStyle = style.backgroundColor;
    // roundRect(ctx, x, y, width, height, style.borderRadius);

    // 绘制标题
    // ctx.font = `${style.titleFontSize}px ${template.fontFamily}`;
    // ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
    // ctx.fillText(title, x + style.padding, y + style.padding + style.titleFontSize);

    // 绘制数值
    // ctx.font = `bold ${style.valueFontSize}px ${template.fontFamily}`;
    // ctx.fillStyle = template.primaryColor;
    // ctx.fillText(value, x + style.padding, y + height - style.padding);

    // 绘制单位
    // ctx.font = `${style.unitFontSize}px ${template.fontFamily}`;
    // ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
    // ctx.fillText(unit, x + style.padding + valueWidth, y + height - style.padding);
  }

  /**
   * 绘制照片
   */
  private drawPhoto(ctx: DrawContext, photoPath: string, template: TemplateConfig): void {
    // 在指定位置绘制照片
    hilog.debug(DOMAIN, TAG, `Drawing photo: ${photoPath}`);
  }

  /**
   * 绘制底部区域
   */
  private drawFooter(ctx: DrawContext, template: TemplateConfig): void {
    const footerY = ctx.height - 100;

    // 绘制应用名称和Slogan
    // ctx.fillText('RideRecord', x, footerY);
    // ctx.fillText('记录每一次骑行', x, footerY + 20);

    // 绘制二维码
    if (template.showQRCode) {
      // this.drawQRCode(ctx, qrCodeData, x, y, size);
    }

    hilog.debug(DOMAIN, TAG, 'Drawing footer');
  }

  /**
   * 导出图片
   */
  private exportImage(ctx: DrawContext): ArrayBuffer {
    // 从Canvas导出PNG图片
    hilog.info(DOMAIN, TAG, 'Exporting image');

    // 返回模拟数据
    return new ArrayBuffer(1024);
  }

  // ==================== 工具方法 ====================

  /**
   * 格式化距离
   */
  private formatDistance(meters: number): string {
    return (meters / 1000).toFixed(2);
  }

  /**
   * 格式化时长
   */
  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return `${hours}:${mins.toString().padStart(2, '0')}`;
    }
    return `${mins}:00`;
  }

  /**
   * 计算文本宽度
   */
  measureText(text: string, fontSize: number): number {
    // 简化实现，实际应该使用Canvas测量
    return text.length * fontSize * 0.6;
  }
}

// 导出单例
export default ShareImageGenerator.getInstance();

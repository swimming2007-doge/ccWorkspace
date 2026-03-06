/**
 * 分享页面
 *
 * 功能说明：
 * - 选择分享模板
 * - 配置分享内容
 * - 预览分享效果
 * - 执行分享操作
 *
 * SRS引用: FR-006
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import WeChatShareService, {
  ShareType,
  ShareTemplate,
  ShareConfig,
  DEFAULT_SHARE_CONFIG,
  RideShareData,
  ShareResult
} from '../services/WeChatShareService';
import ShareImageGenerator from '../services/ShareImageGenerator';
import {
  TemplateSelector,
  ShareConfigPanel,
  PhotoSelector,
  DescriptionInput,
  ShareButtons,
  SharePreview,
  ShareResultToast,
  ShareDataSummary
} from '../components/ShareComponents';

const TAG = '[SharePage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct SharePage {
  // 服务
  private shareService: WeChatShareService = WeChatShareService;
  private imageGenerator: ShareImageGenerator = ShareImageGenerator;

  // 路由参数
  private rideId: string = '';

  // 分享数据
  @State shareData: RideShareData | null = null;

  // 配置状态
  @State config: ShareConfig = { ...DEFAULT_SHARE_CONFIG };
  @State selectedTemplate: ShareTemplate = ShareTemplate.SPORT;
  @State customTitle: string = '';
  @State customDescription: string = '';
  @State selectedPhotoIndex: number | undefined = undefined;

  // UI状态
  @State isLoading: boolean = true;
  @State isSharing: boolean = false;
  @State previewImage: string = '';
  @State shareResult: ShareResult | null = null;

  // 模板列表
  private templates = this.shareService.getTemplates();

  aboutToAppear() {
    // 获取路由参数
    const params = router.getParams() as Record<string, string>;
    if (params && params['rideId']) {
      this.rideId = params['rideId'];
    }

    this.loadShareData();
  }

  async loadShareData() {
    this.isLoading = true;

    try {
      // 在实际实现中，应该从数据库加载骑行数据
      // 这里使用模拟数据
      this.shareData = this.createMockShareData();

      // 生成预览图
      await this.generatePreview();

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to load share data: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  async generatePreview() {
    if (!this.shareData) return;

    try {
      const imageData = await this.imageGenerator.generateImage(this.shareData, this.config);
      // 在实际实现中，应该将imageData转为可显示的图片
      this.previewImage = 'preview_image_path';
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to generate preview: ${error}`);
    }
  }

  build() {
    Column() {
      // 标题栏
      this.TitleBar()

      if (this.isLoading) {
        // 加载状态
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#3B82F6')

          Text('加载中...')
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

      } else {
        // 滚动内容
        Scroll() {
          Column() {
            // 数据摘要
            ShareDataSummary({ shareData: this.shareData })

            // 模板选择
            TemplateSelector({
              templates: this.templates,
              selectedTemplate: this.selectedTemplate
            })

            // 分享设置
            ShareConfigPanel({ config: this.config })

            // 照片选择（如果有照片）
            if (this.shareData && this.shareData.photos.length > 0) {
              PhotoSelector({
                photos: this.shareData.photos,
                selectedIndex: this.selectedPhotoIndex
              })
            }

            // 自定义内容
            DescriptionInput({
              customTitle: this.customTitle,
              customDescription: this.customDescription
            })

            // 分享预览
            SharePreview({
              shareData: this.shareData,
              config: this.config,
              previewImage: this.previewImage
            })

            // 分享按钮
            ShareButtons({
              isSharing: this.isSharing,
              onShareFriend: () => this.shareToFriend(),
              onShareMoments: () => this.shareToMoments()
            })
          }
          .width('100%')
          .padding({ top: 12, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      // 分享结果提示
      ShareResultToast({ result: this.shareResult })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F6')
  }

  @Builder
  TitleBar() {
    Row() {
      Image('arrow_left_icon')
        .width(24)
        .height(24)
        .onClick(() => router.back())

      Text('分享骑行')
        .fontSize(18)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ left: 12 })

      Blank()

      // 重新生成预览
      Button('刷新预览')
        .fontSize(14)
        .height(32)
        .backgroundColor('#E5E7EB')
        .fontColor('#374151')
        .onClick(() => this.generatePreview())
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
  }

  // ==================== 分享操作 ====================

  async shareToFriend() {
    await this.doShare(ShareType.FRIEND);
  }

  async shareToMoments() {
    await this.doShare(ShareType.MOMENTS);
  }

  async doShare(shareType: ShareType) {
    if (!this.shareData) return;

    this.isSharing = true;

    try {
      // 合并配置
      const finalConfig: ShareConfig = {
        ...this.config,
        template: this.selectedTemplate,
        selectedPhotoIndex: this.selectedPhotoIndex,
        customTitle: this.customTitle,
        customDescription: this.customDescription
      };

      // 执行分享
      let result: ShareResult;

      if (shareType === ShareType.FRIEND) {
        result = await this.shareService.shareToFriend(this.shareData, finalConfig);
      } else {
        result = await this.shareService.shareToMoments(this.shareData, finalConfig);
      }

      this.shareResult = result;

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Share failed: ${error}`);
      this.shareResult = {
        success: false,
        shareType,
        error: String(error)
      };
    } finally {
      this.isSharing = false;
    }
  }

  // ==================== 工具方法 ====================

  private createMockShareData(): RideShareData {
    return {
      rideId: this.rideId || 'mock_ride_001',
      distance: 25000,
      duration: 5400,
      avgSpeed: 4.6,
      maxSpeed: 8.5,
      elevation: 350,
      calories: 450,
      avgHeartRate: 135,
      maxHeartRate: 168,
      trackPoints: [
        { latitude: 39.9, longitude: 116.4, altitude: 50 },
        { latitude: 39.91, longitude: 116.41, altitude: 52 },
        { latitude: 39.92, longitude: 116.42, altitude: 55 }
      ],
      startPoint: { latitude: 39.9, longitude: 116.4, altitude: 50 },
      endPoint: { latitude: 39.95, longitude: 116.5, altitude: 48 },
      photos: [],
      startTime: Date.now() - 5400000,
      endTime: Date.now()
    };
  }
}

/**
 * 离线地图页面
 *
 * 功能说明：
 * - 离线地图区域管理
 * - 下载任务管理
 * - 存储空间查看
 * - 地图更新检测
 *
 * SRS引用: FR-003-05
 */
import router from '@ohos.router';
import {
  OfflineMapService,
  OfflineRegion,
  OfflineRegionCreate,
  RegionStatus,
  DownloadProgress,
  StorageUsage,
  PRESET_REGIONS
} from '../services/OfflineMapService';
import { StorageManager, StorageStats, StorageWarningLevel, CleanupResult } from '../services/StorageManager';
import {
  StorageUsageBar,
  DownloadProgressIndicator,
  OfflineRegionCard,
  StorageWarningCard,
  RegionSelector
} from '../components/OfflineMapComponents';

const TAG = '[OfflineMapPage]';
const DOMAIN = 0xFF00;

interface RegionWithProgress {
  region: OfflineRegion;
  progress?: DownloadProgress;
}

@Entry
@Component
struct OfflineMapPage {
  // 服务
  private offlineMapService: OfflineMapService = OfflineMapService;
  private storageManager: StorageManager = StorageManager;

  // 状态
  @State regions: OfflineRegion[] = [];
  @State storageUsage: StorageUsage | null = null;
  @State warningLevel: StorageWarningLevel = StorageWarningLevel.NONE;
  @State isLoading: boolean = true;
  @State showAddDialog: boolean = false;
  @State showStorageDialog: boolean = false;

  // 下载进度
  @State downloadProgress: Map<string, DownloadProgress> = new Map();

  // 新区域表单
  @State newRegionName: string = '';
  @State newRegionMinLat: string = '';
  @State newRegionMaxLat: string = '';
  @State newRegionMinLon: string = '';
  @State newRegionMaxLon: string = '';
  @State newRegionMinZoom: number = 10;
  @State newRegionMaxZoom: number = 15;

  aboutToAppear() {
    this.loadData();
  }

  aboutToDisappear() {
    // 清理回调
    for (const region of this.regions) {
      this.offlineMapService.removeDownloadCallback(region.id);
    }
  }

  async loadData() {
    this.isLoading = true;

    try {
      // 加载区域
      this.regions = await this.offlineMapService.getRegions();

      // 加载存储信息
      this.storageUsage = await this.offlineMapService.getStorageUsage();

      // 检查预警
      this.warningLevel = await this.storageManager.getWarningLevel();

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to load data: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 标题栏
      this.TitleBar()

      // 存储警告
      if (this.warningLevel !== StorageWarningLevel.NONE) {
        StorageWarningCard({
          level: this.warningLevel,
          stats: null
        })
          .margin({ left: 16, right: 16, top: 8 })
      }

      // 存储使用情况
      if (this.storageUsage) {
        Column() {
          Row() {
            Text('存储使用')
              .fontSize(14)
              .fontWeight(FontWeight.MEDIUM)

            Blank()

            Text(`${this.formatSize(this.storageUsage.mapSpace)} / ${this.formatSize(this.storageUsage.totalSpace)}`)
              .fontSize(12)
              .fontColor('#6B7280')
          }
          .width('100%')
          .margin({ bottom: 8 })

          StorageUsageBar({
            usage: this.storageUsage,
            showDetails: false,
            height: 12
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#F9FAFB')
      }

      // 区域列表
      if (this.isLoading) {
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

      } else if (this.regions.length === 0) {
        this.EmptyState()

      } else {
        List() {
          ForEach(this.regions, (region: OfflineRegion) => {
            ListItem() {
              OfflineRegionCard({
                region: region,
                progress: this.downloadProgress.get(region.id),
                onDownload: () => this.startDownload(region.id),
                onPause: () => this.pauseDownload(region.id),
                onResume: () => this.resumeDownload(region.id),
                onDelete: () => this.deleteRegion(region.id),
                onSelect: () => this.selectRegion(region)
              })
            }
            .margin({ left: 16, right: 16, top: 8, bottom: 8 })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
      }

      // 底部操作栏
      this.BottomBar()
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

      Text('离线地图')
        .fontSize(18)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ left: 12 })

      Blank()

      Image('settings_icon')
        .width(24)
        .height(24)
        .onClick(() => this.showStorageDialog = true)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  EmptyState() {
    Column() {
      Image('offline_map_icon')
        .width(80)
        .height(80)
        .opacity(0.5)

      Text('暂无离线地图')
        .fontSize(16)
        .fontColor('#6B7280')
        .margin({ top: 16 })

      Text('点击下方按钮添加区域')
        .fontSize(14)
        .fontColor('#9CA3AF')
        .margin({ top: 8 })

      Button('添加区域')
        .fontSize(14)
        .height(36)
        .backgroundColor('#3B82F6')
        .margin({ top: 24 })
        .onClick(() => this.showAddDialog = true)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  BottomBar() {
    Row() {
      Button('添加区域')
        .fontSize(14)
        .height(44)
        .backgroundColor('#3B82F6')
        .borderRadius(22)
        .layoutWeight(1)
        .onClick(() => this.showAddDialog = true)

      Button('检查更新')
        .fontSize(14)
        .height(44)
        .backgroundColor('#F3F4F6')
        .fontColor('#374151')
        .borderRadius(22)
        .layoutWeight(1)
        .margin({ left: 12 })
        .onClick(() => this.checkUpdates())
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }

  // ==================== 操作方法 ====================

  async startDownload(regionId: string) {
    try {
      // 设置进度回调
      this.offlineMapService.setDownloadCallback(regionId, (progress) => {
        this.downloadProgress.set(regionId, progress);
        // 触发UI更新
        this.regions = [...this.regions];
      });

      await this.offlineMapService.startDownload(regionId);

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to start download: ${error}`);
    }
  }

  async pauseDownload(regionId: string) {
    try {
      await this.offlineMapService.pauseDownload(regionId);
      this.loadData();
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to pause download: ${error}`);
    }
  }

  async resumeDownload(regionId: string) {
    try {
      await this.offlineMapService.resumeDownload(regionId);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to resume download: ${error}`);
    }
  }

  async deleteRegion(regionId: string) {
    try {
      // 确认删除
      // AlertDialog.show({
      //   title: '删除确认',
      //   message: '确定要删除此离线地图吗？',
      //   primaryButton: { value: '取消' },
      //   secondaryButton: {
      //     value: '删除',
      //     action: async () => {
      //       await this.offlineMapService.removeRegion(regionId);
      //       this.loadData();
      //     }
      //   }
      // });

      await this.offlineMapService.removeRegion(regionId);
      this.loadData();

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to delete region: ${error}`);
    }
  }

  selectRegion(region: OfflineRegion) {
    // 导航到区域详情页
    // router.pushUrl({
    //   url: 'pages/OfflineMapDetailPage',
    //   params: { regionId: region.id }
    // });
  }

  async checkUpdates() {
    try {
      const updates = await this.offlineMapService.checkForUpdates();
      const hasUpdates = updates.filter(u => u.hasUpdate);

      if (hasUpdates.length === 0) {
        // Toast.show('所有地图已是最新版本');
      } else {
        // 显示更新提示
        // Toast.show(`有 ${hasUpdates.length} 个地图可更新`);
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to check updates: ${error}`);
    }
  }

  async addCustomRegion() {
    if (!this.newRegionName || !this.newRegionMinLat || !this.newRegionMaxLat ||
        !this.newRegionMinLon || !this.newRegionMaxLon) {
      // Toast.show('请填写完整信息');
      return;
    }

    try {
      const create: OfflineRegionCreate = {
        name: this.newRegionName,
        bounds: {
          minLat: parseFloat(this.newRegionMinLat),
          maxLat: parseFloat(this.newRegionMaxLat),
          minLon: parseFloat(this.newRegionMinLon),
          maxLon: parseFloat(this.newRegionMaxLon)
        },
        zoomRange: [this.newRegionMinZoom, this.newRegionMaxZoom]
      };

      await this.offlineMapService.addRegion(create);
      this.showAddDialog = false;
      this.resetNewRegionForm();
      this.loadData();

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to add region: ${error}`);
    }
  }

  resetNewRegionForm() {
    this.newRegionName = '';
    this.newRegionMinLat = '';
    this.newRegionMaxLat = '';
    this.newRegionMinLon = '';
    this.newRegionMaxLon = '';
    this.newRegionMinZoom = 10;
    this.newRegionMaxZoom = 15;
  }

  selectPresetRegion(preset: typeof PRESET_REGIONS[0]) {
    this.newRegionName = preset.name;
    this.newRegionMinLat = preset.bounds.minLat.toString();
    this.newRegionMaxLat = preset.bounds.maxLat.toString();
    this.newRegionMinLon = preset.bounds.minLon.toString();
    this.newRegionMaxLon = preset.bounds.maxLon.toString();
    this.newRegionMinZoom = preset.zoomRange[0];
    this.newRegionMaxZoom = preset.zoomRange[1];
  }

  // ==================== 工具方法 ====================

  formatSize(bytes: number): string {
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    } else {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
    }
  }
}

import hilog from '@ohos.hilog';

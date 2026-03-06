/**
 * 离线地图界面组件
 *
 * 功能说明：
 * - 离线区域卡片
 * - 下载进度指示器
 * - 存储使用条
 * - 区域选择器
 *
 * SRS引用: FR-003-05
 */
import {
  OfflineRegion,
  RegionStatus,
  DownloadProgress,
  StorageUsage
} from '../services/OfflineMapService';
import { StorageStats, StorageWarningLevel } from '../services/StorageManager';

/**
 * 存储使用条组件参数
 */
export interface StorageUsageBarProps {
  usage: StorageUsage;
  showDetails?: boolean;
  height?: number;
}

/**
 * 存储使用条组件
 */
@Component
export struct StorageUsageBar {
  @Prop usage: StorageUsage = {
    totalSpace: 0,
    usedSpace: 0,
    mapSpace: 0,
    availableSpace: 0,
    regions: [],
    usedPercent: 0
  };
  @Prop showDetails: boolean = true;
  @Prop height: number = 24;

  build() {
    Column() {
      // 进度条
      Row() {
        // 已用空间
        Row()
          .width(`${this.usage.usedPercent}%`)
          .height('100%')
          .backgroundColor(this.getUsageColor())
          .borderRadius({ topLeft: 4, bottomLeft: 4 })

        // 可用空间
        Row()
          .width(`${100 - this.usage.usedPercent}%`)
          .height('100%')
          .backgroundColor('#E5E7EB')
          .borderRadius({ topRight: 4, bottomRight: 4 })
      }
      .width('100%')
      .height(this.height)
      .borderRadius(4)

      // 详细信息
      if (this.showDetails) {
        Row() {
          Text(`已用: ${this.formatSize(this.usage.usedSpace)}`)
            .fontSize(12)
            .fontColor('#6B7280')

          Blank()

          Text(`可用: ${this.formatSize(this.usage.availableSpace)}`)
            .fontSize(12)
            .fontColor('#6B7280')
        }
        .width('100%')
        .margin({ top: 4 })
      }
    }
    .width('100%')
  }

  private getUsageColor(): ResourceColor {
    const percent = this.usage.usedPercent;
    if (percent > 90) {
      return '#EF4444'; // 红色
    } else if (percent > 75) {
      return '#F59E0B'; // 橙色
    } else {
      return '#10B981'; // 绿色
    }
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    } else {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
    }
  }
}

/**
 * 下载进度指示器参数
 */
export interface DownloadProgressIndicatorProps {
  progress: DownloadProgress;
  showSpeed?: boolean;
}

/**
 * 下载进度指示器组件
 */
@Component
export struct DownloadProgressIndicator {
  @Prop progress: DownloadProgress = {
    regionId: '',
    totalTiles: 0,
    downloadedTiles: 0,
    currentSpeed: 0,
    estimatedTime: 0,
    percent: 0
  };
  @Prop showSpeed: boolean = true;

  build() {
    Column() {
      // 进度条
      Row() {
        Row()
          .width(`${this.progress.percent}%`)
          .height('100%')
          .backgroundColor('#3B82F6')
          .borderRadius(4)
      }
      .width('100%')
      .height(8)
      .backgroundColor('#E5E7EB')
      .borderRadius(4)

      // 进度信息
      Row() {
        Text(`${this.progress.percent}%`)
          .fontSize(14)
          .fontWeight(FontWeight.MEDIUM)

        Blank()

        if (this.showSpeed) {
          Text(`${this.progress.currentSpeed} KB/s`)
            .fontSize(12)
            .fontColor('#6B7280')
        }
      }
      .width('100%')
      .margin({ top: 4 })

      // 瓦片计数
      Row() {
        Text(`${this.progress.downloadedTiles} / ${this.progress.totalTiles} 瓦片`)
          .fontSize(12)
          .fontColor('#6B7280')

        Blank()

        if (this.progress.estimatedTime > 0) {
          Text(`预计 ${this.formatTime(this.progress.estimatedTime)}`)
            .fontSize(12)
            .fontColor('#6B7280')
        }
      }
      .width('100%')
      .margin({ top: 2 })
    }
    .width('100%')
  }

  private formatTime(seconds: number): string {
    if (seconds < 60) {
      return `${seconds}秒`;
    } else if (seconds < 3600) {
      const mins = Math.floor(seconds / 60);
      return `${mins}分钟`;
    } else {
      const hours = Math.floor(seconds / 3600);
      const mins = Math.floor((seconds % 3600) / 60);
      return `${hours}小时${mins}分钟`;
    }
  }
}

/**
 * 离线区域卡片参数
 */
export interface OfflineRegionCardProps {
  region: OfflineRegion;
  progress?: DownloadProgress;
  onDownload?: () => void;
  onPause?: () => void;
  onResume?: () => void;
  onDelete?: () => void;
  onSelect?: () => void;
}

/**
 * 离线区域卡片组件
 */
@Component
export struct OfflineRegionCard {
  @Prop region: OfflineRegion = {
    id: '',
    name: '',
    bounds: { minLat: 0, maxLat: 0, minLon: 0, maxLon: 0 },
    zoomRange: [0, 0],
    totalSize: 0,
    downloadedSize: 0,
    status: RegionStatus.PENDING,
    version: '',
    tileCount: 0,
    downloadedTiles: 0,
    createdAt: 0,
    updatedAt: 0
  };
  @Prop progress: DownloadProgress | null = null;

  onDownload?: () => void;
  onPause?: () => void;
  onResume?: () => void;
  onDelete?: () => void;
  onSelect?: () => void;

  build() {
    Column() {
      // 标题行
      Row() {
        Column() {
          Text(this.region.name)
            .fontSize(16)
            .fontWeight(FontWeight.MEDIUM)

          Text(this.getStatusText())
            .fontSize(12)
            .fontColor(this.getStatusColor())
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 操作按钮
        this.ActionButtons()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      // 进度条 (下载中或暂停时显示)
      if (this.region.status === RegionStatus.DOWNLOADING ||
          this.region.status === RegionStatus.PAUSED) {
        Column() {
          DownloadProgressIndicator({
            progress: this.progress || {
              regionId: this.region.id,
              totalTiles: this.region.tileCount,
              downloadedTiles: this.region.downloadedTiles,
              currentSpeed: 0,
              estimatedTime: 0,
              percent: this.getDownloadPercent()
            }
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
      }

      // 已完成时显示大小
      if (this.region.status === RegionStatus.COMPLETED) {
        Row() {
          Text(`大小: ${this.formatSize(this.region.downloadedSize)}`)
            .fontSize(12)
            .fontColor('#6B7280')

          Blank()

          Text(`更新: ${this.formatDate(this.region.updatedAt)}`)
            .fontSize(12)
            .fontColor('#6B7280')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
      }

      // 错误信息
      if (this.region.status === RegionStatus.ERROR) {
        Row() {
          Text('下载失败，请重试')
            .fontSize(12)
            .fontColor('#EF4444')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: 'rgba(0, 0, 0, 0.1)',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      if (this.onSelect) {
        this.onSelect();
      }
    })
  }

  @Builder
  ActionButtons() {
    Row({ space: 8 }) {
      when (this.region.status) {
        RegionStatus.PENDING -> {
          Button('下载')
            .fontSize(14)
            .height(32)
            .backgroundColor('#3B82F6')
            .onClick(() => {
              if (this.onDownload) {
                this.onDownload();
              }
            })
        }
        RegionStatus.DOWNLOADING -> {
          Button('暂停')
            .fontSize(14)
            .height(32)
            .backgroundColor('#F59E0B')
            .onClick(() => {
              if (this.onPause) {
                this.onPause();
              }
            })
        }
        RegionStatus.PAUSED -> {
          Button('继续')
            .fontSize(14)
            .height(32)
            .backgroundColor('#3B82F6')
            .onClick(() => {
              if (this.onResume) {
                this.onResume();
              }
            })
        }
        RegionStatus.COMPLETED -> {
          Button('删除')
            .fontSize(14)
            .height(32)
            .backgroundColor('#EF4444')
            .onClick(() => {
              if (this.onDelete) {
                this.onDelete();
              }
            })
        }
        RegionStatus.ERROR -> {
          Button('重试')
            .fontSize(14)
            .height(32)
            .backgroundColor('#3B82F6')
            .onClick(() => {
              if (this.onDownload) {
                this.onDownload();
              }
            })
        }
      }
    }
  }

  private getStatusText(): string {
    switch (this.region.status) {
      case RegionStatus.PENDING:
        return '待下载';
      case RegionStatus.DOWNLOADING:
        return '下载中...';
      case RegionStatus.PAUSED:
        return '已暂停';
      case RegionStatus.COMPLETED:
        return '已完成';
      case RegionStatus.ERROR:
        return '下载失败';
      default:
        return '未知';
    }
  }

  private getStatusColor(): ResourceColor {
    switch (this.region.status) {
      case RegionStatus.PENDING:
        return '#6B7280';
      case RegionStatus.DOWNLOADING:
        return '#3B82F6';
      case RegionStatus.PAUSED:
        return '#F59E0B';
      case RegionStatus.COMPLETED:
        return '#10B981';
      case RegionStatus.ERROR:
        return '#EF4444';
      default:
        return '#6B7280';
    }
  }

  private getDownloadPercent(): number {
    if (this.region.tileCount === 0) return 0;
    return Math.round((this.region.downloadedTiles / this.region.tileCount) * 100);
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    } else {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
    }
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getMonth() + 1}/${date.getDate()}`;
  }
}

/**
 * 存储警告卡片组件
 */
@Component
export struct StorageWarningCard {
  @Prop level: StorageWarningLevel = StorageWarningLevel.NONE;
  @Prop stats: StorageStats | null = null;

  build() {
    if (this.level === StorageWarningLevel.NONE) {
      return;
    }

    Row() {
      Image(this.getWarningIcon())
        .width(24)
        .height(24)
        .margin({ right: 12 })

      Column() {
        Text(this.getWarningTitle())
          .fontSize(14)
          .fontWeight(FontWeight.MEDIUM)

        Text(this.getWarningMessage())
          .fontSize(12)
          .fontColor('#6B7280')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.getWarningBackgroundColor())
    .borderRadius(8)
  }

  private getWarningIcon(): ResourceStr {
    switch (this.level) {
      case StorageWarningLevel.LOW:
        return 'warn_icon';
      case StorageWarningLevel.CRITICAL:
        return 'error_icon';
      case StorageWarningLevel.FULL:
        return 'critical_icon';
      default:
        return 'info_icon';
    }
  }

  private getWarningTitle(): string {
    switch (this.level) {
      case StorageWarningLevel.LOW:
        return '存储空间不足';
      case StorageWarningLevel.CRITICAL:
        return '存储空间严重不足';
      case StorageWarningLevel.FULL:
        return '存储空间已满';
      default:
        return '';
    }
  }

  private getWarningMessage(): string {
    if (!this.stats) return '';

    const availablePercent = Math.round((this.stats.availableSpace / this.stats.totalSpace) * 100);

    switch (this.level) {
      case StorageWarningLevel.LOW:
        return `可用空间仅剩 ${availablePercent}%，建议清理旧地图`;
      case StorageWarningLevel.CRITICAL:
        return `可用空间仅剩 ${availablePercent}%，请立即清理`;
      case StorageWarningLevel.FULL:
        return '无法下载新地图，请清理存储空间';
      default:
        return '';
    }
  }

  private getWarningBackgroundColor(): ResourceColor {
    switch (this.level) {
      case StorageWarningLevel.LOW:
        return '#FEF3C7'; // 黄色
      case StorageWarningLevel.CRITICAL:
        return '#FEE2E2'; // 红色
      case StorageWarningLevel.FULL:
        return '#FEE2E2'; // 红色
      default:
        return '#F3F4F6';
    }
  }
}

/**
 * 区域选择器组件
 */
@Component
export struct RegionSelector {
  @Prop presetRegions: Array<{
    name: string;
    bounds: { minLat: number; maxLat: number; minLon: number; maxLon: number };
    zoomRange: [number, number];
  }> = [];
  @State selectedRegion: number = -1;

  onSelect?: (region: typeof this.presetRegions[0]) => void;

  build() {
    Column() {
      Text('选择区域')
        .fontSize(16)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ bottom: 12 })

      List() {
        ForEach(this.presetRegions, (region: typeof this.presetRegions[0], index: number) => {
          ListItem() {
            Row() {
              Column() {
                Text(region.name)
                  .fontSize(14)
                  .fontWeight(this.selectedRegion === index ? FontWeight.MEDIUM : FontWeight.Normal)

                Text(`缩放级别: ${region.zoomRange[0]}-${region.zoomRange[1]}`)
                  .fontSize(12)
                  .fontColor('#6B7280')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (this.selectedRegion === index) {
                Image('check_icon')
                  .width(20)
                  .height(20)
              }
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.selectedRegion === index ? '#EFF6FF' : '#FFFFFF')
            .borderRadius(8)
            .onClick(() => {
              this.selectedRegion = index;
              if (this.onSelect) {
                this.onSelect(region);
              }
            })
          }
          .margin({ bottom: 8 })
        })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
  }
}

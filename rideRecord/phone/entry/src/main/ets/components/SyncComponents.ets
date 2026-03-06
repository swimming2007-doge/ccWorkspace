/**
 * 同步界面组件
 *
 * 功能说明：
 * - 同步状态卡片
 * - 同步进度显示
 * - 同步设置面板
 */

import { SyncStatus, SyncTask, SyncDirection } from '../services/SyncService';

/**
 * 同步状态卡片
 */
@Component
export struct SyncStatusCard {
  @Prop status: SyncStatus = SyncStatus.IDLE;
  @Prop pendingCount: number = 0;
  @Prop lastSyncTime: string = '';
  onSyncPressed?: () => void;

  private get statusText(): string {
    switch (this.status) {
      case SyncStatus.IDLE:
        return '空闲';
      case SyncStatus.SYNCING:
        return '同步中...';
      case SyncStatus.SUCCESS:
        return '同步成功';
      case SyncStatus.FAILED:
        return '同步失败';
      case SyncStatus.PAUSED:
        return '已暂停';
      default:
        return '未知';
    }
  }

  private get statusColor(): string {
    switch (this.status) {
      case SyncStatus.IDLE:
        return '#1890FF';
      case SyncStatus.SYNCING:
        return '#FAAD14';
      case SyncStatus.SUCCESS:
        return '#52C41A';
      case SyncStatus.FAILED:
        return '#F5222D';
      case SyncStatus.PAUSED:
        return '#8C8C8C';
      default:
        return '#BFBFBF';
    }
  }

  private get statusIcon(): string {
    switch (this.status) {
      case SyncStatus.IDLE:
        return '☁️';
      case SyncStatus.SYNCING:
        return '🔄';
      case SyncStatus.SUCCESS:
        return '✅';
      case SyncStatus.FAILED:
        return '❌';
      case SyncStatus.PAUSED:
        return '⏸️';
      default:
        return '❓';
    }
  }

  build() {
    Column() {
      // 标题行
      Row() {
        Text('云端同步')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.statusText)
          .fontSize(14)
          .fontColor(this.statusColor)
      }
      .width('100%')

      // 状态图标和信息
      Row() {
        Text(this.statusIcon)
          .fontSize(48)

        Column() {
          Text(`${this.pendingCount} 条记录待同步`)
            .fontSize(16)
            .fontColor('#182431')

          if (this.lastSyncTime) {
            Text(`上次同步: ${this.lastSyncTime}`)
              .fontSize(12)
              .fontColor('#99182431')
              .margin({ top: 4 })
          } else {
            Text('暂无同步记录')
              .fontSize(12)
              .fontColor('#99182431')
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 })
        .layoutWeight(1)

        // 同步按钮
        if (this.status !== SyncStatus.SYNCING) {
          Button('同步')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#1890FF')
            .borderRadius(20)
            .padding({ left: 20, right: 20, top: 8, bottom: 8 })
            .onClick(() => this.onSyncPressed?.())
        } else {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#1890FF')
        }
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}

/**
 * 同步进度条
 */
@Component
export struct SyncProgressBar {
  @Prop currentTask: SyncTask | null = null;

  build() {
    Column() {
      if (this.currentTask) {
        // 进度信息
        Row() {
          Text('正在同步')
            .fontSize(14)
            .fontColor('#182431')

          Blank()

          Text(`${this.currentTask.progress}%`)
            .fontSize(14)
            .fontColor('#1890FF')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')

        // 进度条
        Progress({
          value: this.currentTask.progress,
          total: 100,
          type: ProgressType.Linear
        })
          .width('100%')
          .height(8)
          .color('#1890FF')
          .backgroundColor('#E8E8E8')
          .margin({ top: 8 })

        // 数据大小
        Row() {
          Text(`已上传: ${this.formatBytes(this.currentTask.uploadedBytes)}`)
            .fontSize(12)
            .fontColor('#99182431')

          Blank()

          Text(`共: ${this.formatBytes(this.currentTask.totalBytes)}`)
            .fontSize(12)
            .fontColor('#99182431')
        }
        .width('100%')
        .margin({ top: 4 })
      }
    }
    .width('100%')
  }

  private formatBytes(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  }
}

/**
 * 同步历史项
 */
@Component
export struct SyncHistoryItem {
  @Prop rideId: string = '';
  @Prop syncTime: string = '';
  @Prop status: string = '';
  @Prop distance: number = 0;
  @Prop duration: number = 0;

  build() {
    Row() {
      // 状态图标
      Text(this.status === 'success' ? '✅' : '❌')
        .fontSize(24)

      // 同步信息
      Column() {
        Text(this.formatDate(this.syncTime))
          .fontSize(14)
          .fontColor('#182431')

        Row() {
          Text(`${(this.distance / 1000).toFixed(1)} km`)
            .fontSize(12)
            .fontColor('#99182431')

          Text(' · ')
            .fontSize(12)
            .fontColor('#99182431')

          Text(this.formatDuration(this.duration))
            .fontSize(12)
            .fontColor('#99182431')
        }
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      // 同步状态
      Text(this.status === 'success' ? '已同步' : '失败')
        .fontSize(12)
        .fontColor(this.status === 'success' ? '#52C41A' : '#F5222D')
        .backgroundColor(this.status === 'success' ? '#F6FFED' : '#FFF2F0')
        .borderRadius(4)
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  private formatDate(dateStr: string): string {
    const date = new Date(dateStr);
    const now = new Date();
    const diff = now.getTime() - date.getTime();

    if (diff < 60 * 1000) {
      return '刚刚';
    } else if (diff < 60 * 60 * 1000) {
      return `${Math.floor(diff / (60 * 1000))} 分钟前`;
    } else if (diff < 24 * 60 * 60 * 1000) {
      return `${Math.floor(diff / (60 * 60 * 1000))} 小时前`;
    } else {
      return `${date.getMonth() + 1}月${date.getDate()}日 ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;
    }
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}分钟`;
  }
}

/**
 * 同步设置项
 */
@Component
export struct SyncSettingItem {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop value: boolean | string = false;
  @Prop type: 'toggle' | 'text' | 'select' = 'toggle';
  onToggle?: (value: boolean) => void;

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor('#182431')

        Text(this.description)
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.type === 'toggle') {
        Toggle({ type: ToggleType.Switch, isOn: this.value as boolean })
          .selectedColor('#1890FF')
          .onChange((isOn: boolean) => {
            this.onToggle?.(isOn);
          })
      } else if (this.type === 'text') {
        Text(this.value as string)
          .fontSize(14)
          .fontColor('#1890FF')
      }
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }
}

/**
 * 同步冲突解决对话框
 */
@Component
export struct SyncConflictDialog {
  @Prop localTime: string = '';
  @Prop serverTime: string = '';
  @Prop localDistance: number = 0;
  @Prop serverDistance: number = 0;
  onKeepLocal?: () => void;
  onKeepServer?: () => void;
  onKeepBoth?: () => void;

  build() {
    Column() {
      Text('同步冲突')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)

      Text('检测到本地和云端数据不一致，请选择保留版本：')
        .fontSize(14)
        .fontColor('#99182431')
        .margin({ top: 12 })

      // 本地版本
      Column() {
        Text('本地版本')
          .fontSize(12)
          .fontColor('#1890FF')

        Text(`${(this.localDistance / 1000).toFixed(1)} km`)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 4 })

        Text(this.localTime)
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ top: 2 })
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#E6F7FF')
      .borderRadius(8)
      .margin({ top: 16 })

      // 云端版本
      Column() {
        Text('云端版本')
          .fontSize(12)
          .fontColor('#52C41A')

        Text(`${(this.serverDistance / 1000).toFixed(1)} km`)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 4 })

        Text(this.serverTime)
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ top: 2 })
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F6FFED')
      .borderRadius(8)
      .margin({ top: 8 })

      // 操作按钮
      Row() {
        Button('保留本地')
          .fontSize(14)
          .fontColor('#182431')
          .backgroundColor('#F5F5F5')
          .borderRadius(20)
          .layoutWeight(1)
          .onClick(() => this.onKeepLocal?.())

        Button('保留云端')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#52C41A')
          .borderRadius(20)
          .layoutWeight(1)
          .margin({ left: 12 })
          .onClick(() => this.onKeepServer?.())
      }
      .width('100%')
      .margin({ top: 16 })

      Button('保留两份')
        .fontSize(14)
        .fontColor('#1890FF')
        .backgroundColor('#E6F7FF')
        .borderRadius(20)
        .width('100%')
        .margin({ top: 8 })
        .onClick(() => this.onKeepBoth?.())
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}

/**
 * Strava 同步界面组件
 *
 * 功能说明：
 * - Strava 连接状态
 * - 同步操作按钮
 * - 同步历史记录
 * - 配置面板
 *
 * SRS引用: FR-008-01
 */
import {
  StravaToken,
  StravaSyncConfig,
  SyncRecord,
  UploadStatus
} from '../services/StravaService';

/**
 * Strava 连接状态卡片组件
 */
@Component
export struct StravaConnectionCard {
  @Prop isConnected: boolean = false;
  @Prop athleteName: string = '';
  @Prop athleteProfile: string = '';

  onConnect?: () => void;
  onDisconnect?: () => void;

  build() {
    Column() {
      Row() {
        // Strava Logo
        Image('strava_logo')
          .width(48)
          .height(48)
          .margin({ right: 12 })

        Column() {
          Text('Strava')
            .fontSize(18)
            .fontWeight(FontWeight.MEDIUM)

          if (this.isConnected && this.athleteName) {
            Text(`已连接: ${this.athleteName}`)
              .fontSize(12)
              .fontColor('#6B7280')
              .margin({ top: 2 })
          } else {
            Text('连接后可同步骑行数据')
              .fontSize(12)
              .fontColor('#6B7280')
              .margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 状态指示
        Circle()
          .width(12)
          .height(12)
          .fill(this.isConnected ? '#10B981' : '#9CA3AF')
      }
      .width('100%')
      .padding(16)

      Divider().margin({ left: 16, right: 16 })

      // 操作按钮
      Row() {
        if (this.isConnected) {
          Button('断开连接')
            .fontSize(14)
            .height(40)
            .backgroundColor('#EF4444')
            .borderRadius(8)
            .layoutWeight(1)
            .onClick(() => {
              if (this.onDisconnect) {
                this.onDisconnect();
              }
            })
        } else {
          Button('连接 Strava')
            .fontSize(14)
            .height(40)
            .backgroundColor('#FC4C02')
            .borderRadius(8)
            .layoutWeight(1)
            .onClick(() => {
              if (this.onConnect) {
                this.onConnect();
              }
            })
        }
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}

/**
 * Strava 同步配置面板组件
 */
@Component
export struct StravaSyncConfigPanel {
  @Link config: StravaSyncConfig;

  build() {
    Column() {
      Text('同步设置')
        .fontSize(14)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ bottom: 12 })

      // 自动同步
      this.SettingRow('自动同步', '骑行结束后自动上传到 Strava', this.config.autoSync, (value) => {
        this.config.autoSync = value;
      })

      // 仅WiFi同步
      this.SettingRow('仅WiFi同步', '仅在WiFi网络下同步数据', this.config.syncOnWifiOnly, (value) => {
        this.config.syncOnWifiOnly = value;
      })

      // 同步照片
      this.SettingRow('同步照片', '上传骑行照片到 Strava', this.config.syncPhotos, (value) => {
        this.config.syncPhotos = value;
      })

      // 标记为通勤
      this.SettingRow('标记为通勤', '将活动标记为通勤类型', this.config.commute, (value) => {
        this.config.commute = value;
      })

      // 私密活动
      this.SettingRow('私密活动', '仅自己可见', this.config.privateActivity, (value) => {
        this.config.privateActivity = value;
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  SettingRow(title: string, description: string, value: boolean, onChange: (value: boolean) => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#374151')

        Text(description)
          .fontSize(12)
          .fontColor('#6B7280')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor('#FC4C02')
        .onChange(onChange)
    }
    .width('100%')
    .height(60)
  }
}

/**
 * 同步记录卡片组件
 */
@Component
export struct SyncRecordCard {
  @Prop record: SyncRecord | null = null;
  @Prop rideName: string = '';

  onRetry?: () => void;
  onViewActivity?: () => void;

  build() {
    if (!this.record) {
      return;
    }

    Column() {
      Row() {
        Column() {
          Text(this.rideName || '骑行记录')
            .fontSize(14)
            .fontWeight(FontWeight.MEDIUM)

          Text(this.getStatusText())
            .fontSize(12)
            .fontColor(this.getStatusColor())
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 状态图标
        Image(this.getStatusIcon())
          .width(24)
          .height(24)
      }
      .width('100%')
      .padding(16)

      if (this.record.status === 'completed' && this.record.stravaActivityId) {
        Divider().margin({ left: 16, right: 16 })

        Row() {
          Text(`Strava ID: ${this.record.stravaActivityId}`)
            .fontSize(12)
            .fontColor('#6B7280')

          Blank()

          Button('查看')
            .fontSize(12)
            .height(28)
            .backgroundColor('#F3F4F6')
            .fontColor('#374151')
            .onClick(() => {
              if (this.onViewActivity) {
                this.onViewActivity();
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }

      if (this.record.status === 'error') {
        Divider().margin({ left: 16, right: 16 })

        Row() {
          Text(this.record.error || '同步失败')
            .fontSize(12)
            .fontColor('#EF4444')
            .layoutWeight(1)

          Button('重试')
            .fontSize(12)
            .height(28)
            .backgroundColor('#FC4C02')
            .onClick(() => {
              if (this.onRetry) {
                this.onRetry();
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  private getStatusText(): string {
    switch (this.record?.status) {
      case 'pending':
        return '等待同步';
      case 'syncing':
        return '同步中...';
      case 'completed':
        return '已同步';
      case 'error':
        return '同步失败';
      default:
        return '未知';
    }
  }

  private getStatusColor(): ResourceColor {
    switch (this.record?.status) {
      case 'pending':
        return '#6B7280';
      case 'syncing':
        return '#3B82F6';
      case 'completed':
        return '#10B981';
      case 'error':
        return '#EF4444';
      default:
        return '#6B7280';
    }
  }

  private getStatusIcon(): ResourceStr {
    switch (this.record?.status) {
      case 'pending':
        return 'pending_icon';
      case 'syncing':
        return 'syncing_icon';
      case 'completed':
        return 'check_icon';
      case 'error':
        return 'error_icon';
      default:
        return 'unknown_icon';
    }
  }
}

/**
 * 同步进度指示器组件
 */
@Component
export struct SyncProgressIndicator {
  @Prop progress: number = 0; // 0-100
  @Prop status: string = '';

  build() {
    Column() {
      // 进度条
      Row() {
        Row()
          .width(`${this.progress}%`)
          .height('100%')
          .backgroundColor('#FC4C02')
          .borderRadius(4)
      }
      .width('100%')
      .height(8)
      .backgroundColor('#E5E7EB')
      .borderRadius(4)

      // 状态文本
      Row() {
        Text(`${this.progress}%`)
          .fontSize(12)
          .fontColor('#374151')

        Blank()

        Text(this.status)
          .fontSize(12)
          .fontColor('#6B7280')
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
  }
}

/**
 * 同步按钮组件
 */
@Component
export struct StravaSyncButton {
  @Prop isSyncing: boolean = false;
  @Prop isConnected: boolean = false;

  onSync?: () => void;

  build() {
    Button() {
      Row() {
        if (this.isSyncing) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color('#FFFFFF')
        } else {
          Image('strava_icon')
            .width(20)
            .height(20)
        }

        Text(this.isSyncing ? '同步中...' : '同步到 Strava')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(44)
    .backgroundColor(this.isConnected ? '#FC4C02' : '#9CA3AF')
    .borderRadius(8)
    .enabled(this.isConnected && !this.isSyncing)
    .onClick(() => {
      if (this.onSync) {
        this.onSync();
      }
    })
  }
}

/**
 * 同步历史列表组件
 */
@Component
export struct SyncHistoryList {
  @Prop records: SyncRecord[] = [];

  onRetry?: (rideId: string) => void;
  onViewActivity?: (stravaActivityId: number) => void;

  build() {
    Column() {
      Text('同步历史')
        .fontSize(14)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ bottom: 12 })

      if (this.records.length === 0) {
        Column() {
          Text('暂无同步记录')
            .fontSize(14)
            .fontColor('#6B7280')

          Text('骑行结束后会自动同步到 Strava')
            .fontSize(12)
            .fontColor('#9CA3AF')
            .margin({ top: 4 })
        }
        .width('100%')
        .height(100)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.records, (record: SyncRecord) => {
            ListItem() {
              SyncRecordCard({
                record: record,
                rideName: `骑行 ${record.rideId.slice(0, 8)}`,
                onRetry: () => {
                  if (this.onRetry) {
                    this.onRetry(record.rideId);
                  }
                },
                onViewActivity: () => {
                  if (this.onViewActivity && record.stravaActivityId) {
                    this.onViewActivity(record.stravaActivityId);
                  }
                }
              })
            }
            .margin({ bottom: 8 })
          })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}

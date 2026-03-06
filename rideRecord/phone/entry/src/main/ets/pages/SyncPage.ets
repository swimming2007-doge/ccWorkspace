/**
 * 同步页面 - F014
 *
 * 功能说明：
 * - 云端同步状态展示
 * - 同步操作控制
 * - 同步历史查看
 * - 同步设置管理
 *
 * 依赖组件：
 * - SyncService: 同步服务
 * - SyncComponents: 同步界面组件
 */

import router from '@ohos.router';
import hilog from '@ohos.hilog';
import SyncService, { SyncStatus, SyncTask, SyncResult } from '../services/SyncService';
import {
  SyncStatusCard,
  SyncProgressBar,
  SyncHistoryItem,
  SyncSettingItem
} from '../components/SyncComponents';

const TAG = '[SyncPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct SyncPage {
  // 同步状态
  @State syncStatus: SyncStatus = SyncStatus.IDLE;
  @State pendingCount: number = 0;
  @State currentTask: SyncTask | null = null;
  @State lastSyncTime: string = '';

  // 同步设置
  @State autoSyncEnabled: boolean = true;
  @State wifiOnlySync: boolean = true;
  @State syncInterval: string = '5分钟';

  // 同步历史
  @State syncHistory: SyncHistoryItem[] = [];

  // 同步结果
  @State syncResults: SyncResult[] = [];
  @State showResultsDialog: boolean = false;

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'SyncPage appearing');

    // 注册回调
    SyncService.onStatusChange((status, task) => {
      this.syncStatus = status;
      this.currentTask = task;
    });

    SyncService.onProgress((task) => {
      this.currentTask = task;
    });

    // 加载数据
    this.loadData();
  }

  /**
   * 加载页面数据
   */
  private async loadData(): Promise<void> {
    // 获取待同步数量
    this.pendingCount = await SyncService.getPendingCount();

    // 获取当前状态
    this.syncStatus = SyncService.getStatus();

    // 加载同步历史 (模拟数据)
    this.syncHistory = [
      { rideId: '1', syncTime: new Date(Date.now() - 3600000).toISOString(), status: 'success', distance: 15200, duration: 2400 },
      { rideId: '2', syncTime: new Date(Date.now() - 7200000).toISOString(), status: 'success', distance: 8300, duration: 1800 },
      { rideId: '3', syncTime: new Date(Date.now() - 86400000).toISOString(), status: 'failed', distance: 21000, duration: 4200 },
    ];

    // 获取上次同步时间
    if (this.syncHistory.length > 0) {
      this.lastSyncTime = this.syncHistory[0].syncTime;
    }
  }

  /**
   * 开始同步
   */
  private async startSync(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Starting sync');

    try {
      this.syncResults = await SyncService.syncAll();

      // 刷新数据
      await this.loadData();

      // 显示结果对话框
      const failedCount = this.syncResults.filter(r => !r.success).length;
      if (failedCount > 0) {
        this.showResultsDialog = true;
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Sync failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 暂停同步
   */
  private pauseSync(): void {
    SyncService.pauseSync();
  }

  /**
   * 恢复同步
   */
  private resumeSync(): void {
    SyncService.resumeSync();
    this.startSync();
  }

  build() {
    Column() {
      // 顶部导航栏
      this.buildHeader()

      // 内容区域
      Scroll() {
        Column() {
          // 同步状态卡片
          SyncStatusCard({
            status: this.syncStatus,
            pendingCount: this.pendingCount,
            lastSyncTime: this.formatLastSyncTime(),
            onSyncPressed: () => this.startSync()
          })
            .margin({ left: 16, right: 16, top: 16 })

          // 同步进度
          if (this.currentTask) {
            Column() {
              Text('同步进度')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .width('100%')

              SyncProgressBar({ currentTask: this.currentTask })
                .margin({ top: 12 })

              // 控制按钮
              Row() {
                if (this.syncStatus === SyncStatus.SYNCING) {
                  Button('暂停')
                    .fontSize(14)
                    .fontColor('#182431')
                    .backgroundColor('#F5F5F5')
                    .borderRadius(20)
                    .onClick(() => this.pauseSync())
                } else if (this.syncStatus === SyncStatus.PAUSED) {
                  Button('继续')
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#1890FF')
                    .borderRadius(20)
                    .onClick(() => this.resumeSync())
                }

                Button('取消')
                  .fontSize(14)
                  .fontColor('#F5222D')
                  .backgroundColor('#FFF2F0')
                  .borderRadius(20)
                  .margin({ left: 12 })
                  .onClick(() => SyncService.cancelSync())
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ top: 16 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ left: 16, right: 16, top: 12 })
          }

          // 同步设置
          Column() {
            Text('同步设置')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')

            SyncSettingItem({
              title: '自动同步',
              description: '骑行结束后自动上传到云端',
              value: this.autoSyncEnabled,
              onToggle: (value: boolean) => {
                this.autoSyncEnabled = value;
                if (value) {
                  SyncService.startAutoSync();
                } else {
                  SyncService.stopAutoSync();
                }
              }
            })

            Divider()

            SyncSettingItem({
              title: '仅WiFi同步',
              description: '仅在WiFi网络下进行同步',
              value: this.wifiOnlySync,
              onToggle: (value: boolean) => {
                this.wifiOnlySync = value;
              }
            })

            Divider()

            SyncSettingItem({
              title: '同步频率',
              description: '自动同步的时间间隔',
              value: this.syncInterval,
              type: 'text'
            })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ left: 16, right: 16, top: 12 })

          // 同步历史
          Column() {
            Row() {
              Text('同步历史')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)

              Blank()

              Text('查看全部')
                .fontSize(14)
                .fontColor('#1890FF')
                .onClick(() => {
                  // TODO: 跳转到同步历史页面
                })
            }
            .width('100%')

            ForEach(this.syncHistory, (item: SyncHistoryItem) => {
              Column() {
                SyncHistoryItem({
                  rideId: item.rideId,
                  syncTime: item.syncTime,
                  status: item.status,
                  distance: item.distance,
                  duration: item.duration
                })

                if (this.syncHistory.indexOf(item) < this.syncHistory.length - 1) {
                  Divider()
                }
              }
            })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ left: 16, right: 16, top: 12, bottom: 16 })
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }

  @Builder
  buildHeader() {
    Row() {
      Button() {
        Text('←')
          .fontSize(20)
          .fontColor('#182431')
      }
      .width(40)
      .height(40)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .onClick(() => router.back())

      Text('云端同步')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 占位
      Row()
        .width(40)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  private formatLastSyncTime(): string {
    if (!this.lastSyncTime) return '';

    const date = new Date(this.lastSyncTime);
    const now = new Date();
    const diff = now.getTime() - date.getTime();

    if (diff < 60 * 1000) {
      return '刚刚';
    } else if (diff < 60 * 60 * 1000) {
      return `${Math.floor(diff / (60 * 1000))}分钟前`;
    } else if (diff < 24 * 60 * 60 * 1000) {
      return `${Math.floor(diff / (60 * 60 * 1000))}小时前`;
    } else {
      return `${date.getMonth() + 1}月${date.getDate()}日`;
    }
  }
}

/**
 * 同步历史项接口
 */
interface SyncHistoryItem {
  rideId: string;
  syncTime: string;
  status: string;
  distance: number;
  duration: number;
}

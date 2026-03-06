/**
 * Strava 同步页面
 *
 * 功能说明：
 * - Strava 账号连接
 * - 同步配置管理
 * - 同步历史查看
 * - 手动同步操作
 *
 * SRS引用: FR-008-01
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import StravaService, {
  StravaToken,
  StravaSyncConfig,
  SyncRecord,
  DEFAULT_STRAVA_SYNC_CONFIG,
  RideDataForStrava
} from '../services/StravaService';
import {
  StravaConnectionCard,
  StravaSyncConfigPanel,
  StravaSyncButton,
  SyncHistoryList
} from '../components/StravaComponents';

const TAG = '[StravaPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct StravaPage {
  // 服务
  private stravaService: StravaService = StravaService;

  // 连接状态
  @State isConnected: boolean = false;
  @State athleteName: string = '';
  @State athleteProfile: string = '';

  // 同步配置
  @State syncConfig: StravaSyncConfig = { ...DEFAULT_STRAVA_SYNC_CONFIG };

  // 同步状态
  @State isSyncing: boolean = false;
  @State syncProgress: number = 0;
  @State syncStatus: string = '';

  // 同步历史
  @State syncRecords: SyncRecord[] = [];

  aboutToAppear() {
    this.loadStatus();
  }

  async loadStatus() {
    this.isConnected = this.stravaService.isAuthenticated();

    if (this.isConnected) {
      // 获取运动员信息
      const athlete = await this.stravaService.getAthlete();
      if (athlete) {
        this.athleteName = `${athlete.firstname} ${athlete.lastname}`;
        this.athleteProfile = athlete.profile;
      }

      // 加载同步配置
      this.syncConfig = this.stravaService.getSyncConfig();

      // 加载同步历史
      this.syncRecords = this.stravaService.getAllSyncRecords();
    }
  }

  build() {
    Column() {
      // 标题栏
      this.TitleBar()

      Scroll() {
        Column() {
          // 连接状态卡片
          StravaConnectionCard({
            isConnected: this.isConnected,
            athleteName: this.athleteName,
            athleteProfile: this.athleteProfile,
            onConnect: () => this.connectStrava(),
            onDisconnect: () => this.disconnectStrava()
          })
            .margin({ bottom: 16 })

          // 同步配置（已连接时显示）
          if (this.isConnected) {
            StravaSyncConfigPanel({ config: this.syncConfig })
              .margin({ bottom: 16 })

            // 同步历史
            SyncHistoryList({
              records: this.syncRecords,
              onRetry: (rideId: string) => this.retrySync(rideId),
              onViewActivity: (activityId: number) => this.viewActivity(activityId)
            })
              .margin({ bottom: 16 })
          }

          // 使用说明
          this.UsageGuide()
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
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

      Text('Strava 同步')
        .fontSize(18)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ left: 12 })

      Blank()

      Image('help_icon')
        .width(24)
        .height(24)
        .onClick(() => this.showHelp())
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  UsageGuide() {
    Column() {
      Text('使用说明')
        .fontSize(14)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ bottom: 12 })

      this.GuideItem('1. 点击"连接 Strava"按钮进行授权')
      this.GuideItem('2. 授权成功后，骑行数据将自动同步')
      this.GuideItem('3. 可在设置中配置自动同步选项')
      this.GuideItem('4. 同步的数据包括轨迹、速度、心率等')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  GuideItem(text: string) {
    Row() {
      Text('•')
        .fontSize(12)
        .fontColor('#6B7280')
        .margin({ right: 8 })

      Text(text)
        .fontSize(12)
        .fontColor('#6B7280')
    }
    .width('100%')
    .margin({ bottom: 4 })
  }

  // ==================== 操作方法 ====================

  async connectStrava() {
    try {
      // 获取授权URL
      const authUrl = this.stravaService.getAuthorizationUrl();

      hilog.info(DOMAIN, TAG, `Opening Strava auth: ${authUrl}`);

      // 在实际实现中，应该打开浏览器或WebView进行授权
      // 授权完成后会通过 deeplink 回调到应用

      // 模拟授权成功
      const mockCode = 'mock_auth_code_' + Date.now();
      const success = await this.stravaService.handleAuthCallback(mockCode);

      if (success) {
        await this.loadStatus();
        // Toast.show('Strava 连接成功');
      } else {
        // Toast.show('Strava 连接失败');
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Connect failed: ${error}`);
    }
  }

  async disconnectStrava() {
    try {
      // 确认断开
      // AlertDialog.show({
      //   title: '断开连接',
      //   message: '确定要断开与 Strava 的连接吗？已同步的活动不会被删除。',
      //   primaryButton: { value: '取消' },
      //   secondaryButton: {
      //     value: '断开',
      //     action: async () => {
      //       await this.stravaService.logout();
      //       await this.loadStatus();
      //     }
      //   }
      // });

      await this.stravaService.logout();
      await this.loadStatus();

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Disconnect failed: ${error}`);
    }
  }

  async syncRide(rideData: RideDataForStrava) {
    if (!this.isConnected) {
      // Toast.show('请先连接 Strava');
      return;
    }

    this.isSyncing = true;
    this.syncProgress = 0;
    this.syncStatus = '准备同步...';

    try {
      // 设置进度回调
      this.stravaService.setSyncCallback((rideId, status) => {
        switch (status) {
          case 'syncing':
            this.syncStatus = '正在上传...';
            this.syncProgress = 50;
            break;
          case 'completed':
            this.syncStatus = '同步完成';
            this.syncProgress = 100;
            break;
          case 'error':
            this.syncStatus = '同步失败';
            break;
        }
      });

      // 执行同步
      const result = await this.stravaService.uploadActivity(rideData);

      if (result.activityId) {
        // Toast.show('同步成功');
        this.syncRecords = this.stravaService.getAllSyncRecords();
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Sync failed: ${error}`);
      // Toast.show('同步失败: ' + error);
    } finally {
      this.isSyncing = false;
    }
  }

  async retrySync(rideId: string) {
    // 在实际实现中，应该从数据库加载骑行数据
    // 这里使用模拟数据
    const mockRideData: RideDataForStrava = {
      rideId: rideId,
      name: '骑行记录',
      startTime: Date.now() - 5400000,
      endTime: Date.now(),
      distance: 25000,
      duration: 5400,
      avgSpeed: 4.6,
      maxSpeed: 8.5,
      elevation: 350,
      avgHeartRate: 135,
      maxHeartRate: 168,
      calories: 450,
      trackPoints: []
    };

    await this.syncRide(mockRideData);
  }

  viewActivity(activityId: number) {
    // 打开 Strava 活动页面
    const url = `https://www.strava.com/activities/${activityId}`;
    hilog.info(DOMAIN, TAG, `Opening Strava activity: ${url}`);

    // 在实际实现中，应该打开浏览器
    // 可以使用 @ohos.app.ability.common 或 WebView
  }

  showHelp() {
    // 显示帮助信息
    hilog.info(DOMAIN, TAG, 'Showing help');
  }
}

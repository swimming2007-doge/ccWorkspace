/**
 * 设置页面 - F023
 *
 * 功能说明：
 * - 骑行偏好设置
 * - 动作检测设置
 * - 同步设置
 * - 隐私设置
 * - 关于与帮助
 *
 * 依赖组件：
 * - SettingsService: 设置服务
 * - SettingsComponents: 设置组件
 */

import router from '@ohos.router';
import hilog from '@ohos.hilog';
import SettingsService, {
  NavMode,
  UnitSystem,
  DetectionSensitivity,
  RidingSettings,
  DetectionSettings,
  SyncSettings,
  PrivacySettings
} from '../services/SettingsService';
import {
  SettingsGroupHeader,
  ToggleSettingItem,
  SelectSettingItem,
  SliderSettingItem,
  NumberSettingItem,
  SettingsCard,
  SettingsDivider
} from '../components/SettingsComponents';

const TAG = '[SettingsPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct SettingsPage {
  // 设置数据
  @State ridingSettings: RidingSettings = SettingsService.getRidingSettings();
  @State detectionSettings: DetectionSettings = SettingsService.getDetectionSettings();
  @State syncSettings: SyncSettings = SettingsService.getSyncSettings();
  @State privacySettings: PrivacySettings = SettingsService.getPrivacySettings();

  // 导航模式选项
  private navModeOptions = [
    { label: '公路模式', value: NavMode.ROAD },
    { label: '探险模式', value: NavMode.ADVENTURE },
    { label: '混合模式', value: NavMode.MIXED }
  ];

  // 单位制选项
  private unitSystemOptions = [
    { label: '公制 (km)', value: UnitSystem.METRIC },
    { label: '英制 (mi)', value: UnitSystem.IMPERIAL }
  ];

  // 检测灵敏度选项
  private sensitivityOptions = [
    { label: '低', value: DetectionSensitivity.LOW },
    { label: '中', value: DetectionSensitivity.MEDIUM },
    { label: '高', value: DetectionSensitivity.HIGH }
  ];

  // 同步间隔选项
  private syncIntervalOptions = [
    { label: '1分钟', value: 1 },
    { label: '5分钟', value: 5 },
    { label: '15分钟', value: 15 },
    { label: '30分钟', value: 30 }
  ];

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'SettingsPage appearing');
    this.loadSettings();
  }

  private loadSettings(): void {
    this.ridingSettings = SettingsService.getRidingSettings();
    this.detectionSettings = SettingsService.getDetectionSettings();
    this.syncSettings = SettingsService.getSyncSettings();
    this.privacySettings = SettingsService.getPrivacySettings();
  }

  build() {
    Column() {
      // 顶部导航栏
      this.buildHeader()

      // 设置内容
      Scroll() {
        Column() {
          // 骑行偏好设置
          this.buildRidingSettings()

          // 动作检测设置
          this.buildDetectionSettings()

          // 同步设置
          this.buildSyncSettings()

          // 隐私设置
          this.buildPrivacySettings()

          // 关于与帮助
          this.buildAboutSection()

          // 底部间距
          Column()
            .height(32)
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

      Text('设置')
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

  // ==================== 骑行偏好设置 ====================

  @Builder
  buildRidingSettings() {
    SettingsCard({ title: '骑行偏好' }) {
      Column() {
        // 默认导航模式
        SelectSettingItem<NavMode>({
          title: '默认导航模式',
          description: '开始骑行时使用的导航模式',
          value: this.ridingSettings.defaultNavMode,
          options: this.navModeOptions,
          icon: '🧭',
          onSelect: (value: NavMode) => {
            this.ridingSettings.defaultNavMode = value;
            SettingsService.updateRidingSettings({ defaultNavMode: value });
          }
        })

        SettingsDivider()

        // 探险比例
        SliderSettingItem({
          title: '探险比例',
          description: '混合模式中探险路线的比例',
          value: Math.round(this.ridingSettings.adventureRatio * 100),
          min: 0,
          max: 100,
          step: 10,
          unit: '%',
          icon: '🏔️',
          onChange: (value: number) => {
            this.ridingSettings.adventureRatio = value / 100;
            SettingsService.updateRidingSettings({ adventureRatio: value / 100 });
          }
        })

        SettingsDivider()

        // 最大风险指数
        NumberSettingItem({
          title: '最大风险指数',
          description: '导航路线的最大风险等级',
          value: this.ridingSettings.maxRiskIndex,
          min: 1,
          max: 5,
          step: 1,
          unit: '级',
          icon: '⚠️',
          onChange: (value: number) => {
            this.ridingSettings.maxRiskIndex = value;
            SettingsService.updateRidingSettings({ maxRiskIndex: value });
          }
        })

        SettingsDivider()

        // 单位制
        SelectSettingItem<UnitSystem>({
          title: '单位制',
          description: '距离和速度的显示单位',
          value: this.ridingSettings.unitSystem,
          options: this.unitSystemOptions,
          icon: '📏',
          onSelect: (value: UnitSystem) => {
            this.ridingSettings.unitSystem = value;
            SettingsService.updateRidingSettings({ unitSystem: value });
          }
        })

        SettingsDivider()

        // 显示心率
        ToggleSettingItem({
          title: '显示心率',
          description: '骑行时显示心率数据',
          value: this.ridingSettings.showHeartRate,
          icon: '❤️',
          onToggle: (value: boolean) => {
            this.ridingSettings.showHeartRate = value;
            SettingsService.updateRidingSettings({ showHeartRate: value });
          }
        })

        SettingsDivider()

        // 显示海拔
        ToggleSettingItem({
          title: '显示海拔',
          description: '骑行时显示海拔和坡度',
          value: this.ridingSettings.showElevation,
          icon: '⛰️',
          onToggle: (value: boolean) => {
            this.ridingSettings.showElevation = value;
            SettingsService.updateRidingSettings({ showElevation: value });
          }
        })

        SettingsDivider()

        // 语音导航
        ToggleSettingItem({
          title: '语音导航',
          description: '导航时播放语音提示',
          value: this.ridingSettings.voiceNavigation,
          icon: '🔊',
          onToggle: (value: boolean) => {
            this.ridingSettings.voiceNavigation = value;
            SettingsService.updateRidingSettings({ voiceNavigation: value });
          }
        })

        SettingsDivider()

        // 语音提醒
        ToggleSettingItem({
          title: '语音提醒',
          description: '心率异常等事件语音提醒',
          value: this.ridingSettings.voiceAlerts,
          icon: '🔔',
          onToggle: (value: boolean) => {
            this.ridingSettings.voiceAlerts = value;
            SettingsService.updateRidingSettings({ voiceAlerts: value });
          }
        })
      }
    }
    .margin({ left: 16, right: 16, top: 16 })
  }

  // ==================== 动作检测设置 ====================

  @Builder
  buildDetectionSettings() {
    SettingsCard({ title: '动作检测' }) {
      Column() {
        // 自动启停
        ToggleSettingItem({
          title: '自动启停',
          description: '检测到上下车动作自动开始/结束记录',
          value: this.detectionSettings.autoStartStop,
          icon: '🚴',
          onToggle: (value: boolean) => {
            this.detectionSettings.autoStartStop = value;
            SettingsService.updateDetectionSettings({ autoStartStop: value });
          }
        })

        SettingsDivider()

        // 检测灵敏度
        SelectSettingItem<DetectionSensitivity>({
          title: '检测灵敏度',
          description: '动作检测的敏感程度',
          value: this.detectionSettings.sensitivity,
          options: this.sensitivityOptions,
          icon: '🎯',
          onSelect: (value: DetectionSensitivity) => {
            this.detectionSettings.sensitivity = value;
            SettingsService.updateDetectionSettings({ sensitivity: value });
          }
        })

        SettingsDivider()

        // 自动暂停超时
        NumberSettingItem({
          title: '自动暂停超时',
          description: '停止踩踏后多久自动暂停记录',
          value: this.detectionSettings.pauseTimeout,
          min: 10,
          max: 120,
          step: 10,
          unit: '秒',
          icon: '⏸️',
          onChange: (value: number) => {
            this.detectionSettings.pauseTimeout = value;
            SettingsService.updateDetectionSettings({ pauseTimeout: value });
          }
        })

        SettingsDivider()

        // 最小骑行时间
        NumberSettingItem({
          title: '最小骑行时间',
          description: '少于此时长的骑行不记录',
          value: this.detectionSettings.minRidingTime,
          min: 5,
          max: 60,
          step: 5,
          unit: '秒',
          icon: '⏱️',
          onChange: (value: number) => {
            this.detectionSettings.minRidingTime = value;
            SettingsService.updateDetectionSettings({ minRidingTime: value });
          }
        })
      }
    }
    .margin({ left: 16, right: 16, top: 12 })
  }

  // ==================== 同步设置 ====================

  @Builder
  buildSyncSettings() {
    SettingsCard({ title: '数据同步' }) {
      Column() {
        // 云端同步
        ToggleSettingItem({
          title: '云端同步',
          description: '将骑行数据同步到云端',
          value: this.syncSettings.cloudSyncEnabled,
          icon: '☁️',
          onToggle: (value: boolean) => {
            this.syncSettings.cloudSyncEnabled = value;
            SettingsService.updateSyncSettings({ cloudSyncEnabled: value });
          }
        })

        SettingsDivider()

        // 自动同步
        ToggleSettingItem({
          title: '自动同步',
          description: '骑行结束后自动上传',
          value: this.syncSettings.autoSync,
          icon: '🔄',
          onToggle: (value: boolean) => {
            this.syncSettings.autoSync = value;
            SettingsService.updateSyncSettings({ autoSync: value });
          }
        })

        SettingsDivider()

        // 仅WiFi同步
        ToggleSettingItem({
          title: '仅WiFi同步',
          description: '仅在WiFi网络下进行同步',
          value: this.syncSettings.wifiOnlySync,
          icon: '📶',
          onToggle: (value: boolean) => {
            this.syncSettings.wifiOnlySync = value;
            SettingsService.updateSyncSettings({ wifiOnlySync: value });
          }
        })

        SettingsDivider()

        // 同步间隔
        SelectSettingItem<number>({
          title: '同步频率',
          description: '后台自动同步的时间间隔',
          value: this.syncSettings.syncInterval,
          options: this.syncIntervalOptions,
          icon: '⏰',
          onSelect: (value: number) => {
            this.syncSettings.syncInterval = value;
            SettingsService.updateSyncSettings({ syncInterval: value });
          }
        })
      }
    }
    .margin({ left: 16, right: 16, top: 12 })
  }

  // ==================== 隐私设置 ====================

  @Builder
  buildPrivacySettings() {
    SettingsCard({ title: '隐私设置' }) {
      Column() {
        // 分享位置
        ToggleSettingItem({
          title: '分享位置',
          description: '允许分享骑行轨迹位置',
          value: this.privacySettings.shareLocation,
          icon: '📍',
          onToggle: (value: boolean) => {
            this.privacySettings.shareLocation = value;
            SettingsService.updatePrivacySettings({ shareLocation: value });
          }
        })

        SettingsDivider()

        // 分享心率
        ToggleSettingItem({
          title: '分享心率',
          description: '允许分享骑行心率数据',
          value: this.privacySettings.shareHeartRate,
          icon: '💓',
          onToggle: (value: boolean) => {
            this.privacySettings.shareHeartRate = value;
            SettingsService.updatePrivacySettings({ shareHeartRate: value });
          }
        })

        SettingsDivider()

        // 公开个人资料
        ToggleSettingItem({
          title: '公开个人资料',
          description: '允许他人查看您的骑行统计',
          value: this.privacySettings.publicProfile,
          icon: '👁️',
          onToggle: (value: boolean) => {
            this.privacySettings.publicProfile = value;
            SettingsService.updatePrivacySettings({ publicProfile: value });
          }
        })
      }
    }
    .margin({ left: 16, right: 16, top: 12 })
  }

  // ==================== 关于与帮助 ====================

  @Builder
  buildAboutSection() {
    Column() {
      // 重置设置
      Row() {
        Text('重置所有设置')
          .fontSize(16)
          .fontColor('#F5222D')
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .onClick(async () => {
        await SettingsService.resetToDefault();
        this.loadSettings();
      })

      // 版本信息
      Column() {
        Text('RideRecord')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')

        Text('版本 0.1.0')
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ top: 4 })

        Text('© 2026 RideRecord Team')
          .fontSize(10)
          .fontColor('#BFBFBF')
          .margin({ top: 8 })
      }
      .width('100%')
      .padding(16)
      .margin({ top: 12 })
    }
    .margin({ left: 16, right: 16, top: 12 })
  }
}

/**
 * 手机端首页
 *
 * 功能说明：
 * - 显示骑行状态概览
 * - 设备连接状态
 * - 开始骑行入口
 * - 历史记录入口
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import { BleClient, ConnectionState } from '../services/BleClient';
import { RideState, RideEvent } from '../utils/Types';

const TAG = '[HomePage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct HomePage {
  // 连接状态
  @State connectionState: string = ConnectionState.DISCONNECTED;
  @State deviceName: string = '';
  @State batteryLevel: number = 0;

  // 骑行状态
  @State rideState: string = RideState.IDLE;
  @State currentRide: any = null;

  // BLE客户端
  private bleClient: BleClient = new BleClient();

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'HomePage aboutToAppear');
    this.setupBleCallbacks();
  }

  aboutToDisappear() {
    hilog.info(DOMAIN, TAG, 'HomePage aboutToDisappear');
  }

  // 设置BLE回调
  private setupBleCallbacks(): void {
    this.bleClient.onConnectionStateChange((state: string, device?: any) => {
      this.connectionState = state;
      if (device) {
        this.deviceName = device.deviceName || 'RideRecord Watch';
      }
      hilog.info(DOMAIN, TAG, 'Connection state changed: %{public}s', state);
    });

    this.bleClient.onDataReceived((data: any) => {
      hilog.info(DOMAIN, TAG, 'Data received: %{public}s', JSON.stringify(data));
      // TODO: 处理接收到的数据
    });
  }

  // 扫描并连接设备
  private async scanAndConnect(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Start scanning for devices');
    try {
      await this.bleClient.startScan();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Scan failed: %{public}s', JSON.stringify(error));
    }
  }

  // 断开连接
  private async disconnect(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Disconnecting');
    try {
      await this.bleClient.disconnect();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Disconnect failed: %{public}s', JSON.stringify(error));
    }
  }

  // 开始骑行
  private startRide(): void {
    hilog.info(DOMAIN, TAG, 'Start ride');
    router.pushUrl({ url: 'pages/RidingPage' });
  }

  // 查看记录
  private viewRecords(): void {
    router.pushUrl({ url: 'pages/RecordsPage' });
  }

  // 打开设置
  private openSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' });
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('RideRecord')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)

        Blank()

        // 设置按钮
        Button() {
          Text('⚙')
            .fontSize(20)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.openSettings())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })

      // 设备连接状态卡片
      Column() {
        Row() {
          // 连接状态图标
          Circle()
            .width(12)
            .height(12)
            .fill(this.connectionState === ConnectionState.CONNECTED
              ? '#4CAF50' : '#9E9E9E')
            .margin({ right: 8 })

          Text(this.connectionState === ConnectionState.CONNECTED
            ? '手表已连接' : '手表未连接')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)

          Blank()

          if (this.connectionState === ConnectionState.CONNECTED) {
            Text(`${this.batteryLevel}%`)
              .fontSize(14)
              .fontColor('#99182431')
          }
        }
        .width('100%')

        if (this.connectionState !== ConnectionState.CONNECTED) {
          Button('连接手表')
            .width('100%')
            .height(40)
            .margin({ top: 12 })
            .onClick(() => this.scanAndConnect())
        } else {
          Row() {
            Text(this.deviceName || 'RideRecord Watch')
              .fontSize(14)
              .fontColor('#99182431')

            Blank()

            Button('断开')
              .fontSize(12)
              .height(32)
              .backgroundColor('#F5F5F5')
              .fontColor('#182431')
              .onClick(() => this.disconnect())
          }
          .width('100%')
          .margin({ top: 8 })
        }
      }
      .width('92%')
      .padding(16)
      .backgroundColor('#F5F5F5')
      .borderRadius(12)
      .margin({ top: 16 })

      // 开始骑行按钮
      Column() {
        Button() {
          Column() {
            Text('🚴')
              .fontSize(48)

            Text('开始骑行')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 8 })
          }
        }
        .width(160)
        .height(160)
        .borderRadius(80)
        .backgroundColor(this.connectionState === ConnectionState.CONNECTED
          ? '#007DFF' : '#E0E0E0')
        .enabled(this.connectionState === ConnectionState.CONNECTED)
        .onClick(() => this.startRide())

        if (this.connectionState !== ConnectionState.CONNECTED) {
          Text('请先连接手表')
            .fontSize(12)
            .fontColor('#99182431')
            .margin({ top: 8 })
        }
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 底部导航
      Row() {
        Column() {
          Text('🏠')
            .fontSize(24)
          Text('首页')
            .fontSize(12)
            .fontColor('#007DFF')
        }
        .layoutWeight(1)

        Column() {
          Text('📋')
            .fontSize(24)
          Text('记录')
            .fontSize(12)
            .fontColor('#99182431')
        }
        .layoutWeight(1)
        .onClick(() => this.viewRecords())

        Column() {
          Text('📊')
            .fontSize(24)
          Text('统计')
            .fontSize(12)
            .fontColor('#99182431')
        }
        .layoutWeight(1)

        Column() {
          Text('⚙')
            .fontSize(24)
          Text('设置')
            .fontSize(12)
            .fontColor('#99182431')
        }
        .layoutWeight(1)
        .onClick(() => this.openSettings())
      }
      .width('100%')
      .height(60)
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 1 }, color: '#E0E0E0' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

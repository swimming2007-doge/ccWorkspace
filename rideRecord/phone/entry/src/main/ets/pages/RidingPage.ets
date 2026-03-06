/**
 * 骑行中页面（手机端）- F009 实时数据看板
 *
 * 功能说明：
 * - 实时速度/距离/时间显示
 * - 心率区间可视化
 * - 海拔/坡度显示
 * - 地图轨迹实时绘制
 * - 骑行状态控制
 *
 * 依赖组件：
 * - RideDataService: 骑行数据管理
 * - DataCard: 数据卡片
 * - HeartRateRing: 心率环
 * - SpeedDisplay: 速度显示
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import { RideState, RideEvent } from '../utils/Types';
import RideDataService, { RideData, HeartRateZone } from '../services/RideDataService';
import { ConnectionState } from '../services/BleClient';
import { GpsSignalState } from '../services/GpsService';
import { DataCard, LargeDataCard, CompactDataCard } from '../components/DataCard';
import { HeartRateRing, HeartRateZoneBar, CompactHeartRate } from '../components/HeartRateRing';
import { SpeedDisplay, DistanceDisplay, TimeDisplay, ElevationDisplay } from '../components/SpeedDisplay';

const TAG = '[RidingPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct RidingPage {
  // 骑行数据
  @State rideData: RideData = RideDataService.getCurrentData();

  // UI状态
  @State showEndConfirm: boolean = false;
  @State isPortrait: boolean = true;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'RidingPage appearing');

    // 注册数据更新回调
    RideDataService.onChange((data: RideData) => {
      this.rideData = data;
    });

    // 如果骑行未开始，自动开始
    if (RideDataService.getRideState() === RideState.IDLE) {
      this.startRide();
    }
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'RidingPage disappearing');
  }

  build() {
    Column() {
      if (this.isPortrait) {
        this.buildPortraitLayout()
      } else {
        this.buildLandscapeLayout()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      // 检测屏幕方向
      const width = Number(newValue.width);
      const height = Number(newValue.height);
      this.isPortrait = height >= width;
    })
  }

  // ==================== 竖屏布局 ====================

  @Builder
  buildPortraitLayout() {
    Column() {
      // 顶部状态栏
      this.buildTopBar()

      // 主数据区域
      Scroll() {
        Column() {
          // 速度显示
          this.buildSpeedSection()

          // 数据卡片行
          this.buildDataRow()

          // 心率区域
          this.buildHeartRateSection()

          // 海拔信息
          this.buildElevationSection()

          // 地图区域
          this.buildMapSection()

          // 控制按钮
          this.buildControlButtons()
        }
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
  }

  // ==================== 横屏布局 ====================

  @Builder
  buildLandscapeLayout() {
    Row() {
      // 左侧：地图
      Column() {
        this.buildMapSection()
      }
      .layoutWeight(1)
      .height('100%')

      // 右侧：数据和控制
      Column() {
        // 数据面板
        Row() {
          // 速度
          Column() {
            Text(`${this.rideData.currentSpeed.toFixed(1)}`)
              .fontSize(36)
              .fontWeight(FontWeight.Bold)
            Text('km/h')
              .fontSize(12)
              .fontColor('#99182431')
          }

          Blank()

          // 心率
          Row() {
            CompactHeartRate({
              heartRate: this.rideData.heartRate,
              zone: this.rideData.heartRateZone
            })
          }
        }
        .width('100%')
        .padding(16)

        Row() {
          // 距离
          CompactDataCard({
            title: '距离',
            value: (this.rideData.distance / 1000).toFixed(2),
            unit: 'km'
          })

          // 时间
          CompactDataCard({
            title: '时间',
            value: this.formatTime(this.rideData.elapsedTime),
            unit: ''
          })

          // 海拔
          CompactDataCard({
            title: '海拔',
            value: Math.round(this.rideData.elevation).toString(),
            unit: 'm'
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .padding({ left: 16, right: 16 })

        Blank()

        // 控制按钮
        this.buildControlButtons()
      }
      .width(280)
      .height('100%')
      .backgroundColor('#FFFFFF')
    }
  }

  // ==================== 子组件 ====================

  @Builder
  buildTopBar() {
    Row() {
      // 返回按钮
      Button() {
        Text('←')
          .fontSize(20)
          .fontColor('#182431')
      }
      .width(40)
      .height(40)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .onClick(() => {
        this.showEndConfirm = true;
      })

      Blank()

      // 骑行状态
      Text(this.getStateText())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getStateColor())

      Blank()

      // 信号状态
      Row() {
        // GPS信号
        Text(this.getGpsSignalIcon())
          .fontSize(16)
          .fontColor(this.getGpsSignalColor())

        // BLE连接
        Text(this.getBleIcon())
          .fontSize(16)
          .fontColor(this.getBleColor())
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildSpeedSection() {
    Column() {
      SpeedDisplay({
        currentSpeed: this.rideData.currentSpeed,
        avgSpeed: this.rideData.avgSpeed,
        maxSpeed: this.rideData.maxSpeed,
        sizeMode: 'large'
      })
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
  }

  @Builder
  buildDataRow() {
    Row() {
      // 距离
      DataCard({
        title: '距离',
        value: (this.rideData.distance / 1000).toFixed(2),
        unit: 'km'
      })
      .layoutWeight(1)
      .margin({ right: 8 })

      // 时间
      DataCard({
        title: '骑行时间',
        value: this.formatTime(this.rideData.elapsedTime),
        unit: ''
      })
      .layoutWeight(1)
      .margin({ left: 8 })
    }
    .width('100%')
  }

  @Builder
  buildHeartRateSection() {
    Column() {
      // 心率环和区间分布
      Row() {
        // 心率环
        HeartRateRing({
          heartRate: this.rideData.heartRate,
          zone: this.rideData.heartRateZone,
          maxHeartRate: 185,
          size: 120,
          strokeWidth: 12
        })
        .margin({ right: 16 })

        // 心率统计
        Column() {
          Text('心率统计')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 })

          Row() {
            Text('平均: ')
              .fontSize(12)
              .fontColor('#99182431')
            Text(`${this.rideData.avgHeartRate}`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            Text(' bpm')
              .fontSize(12)
              .fontColor('#99182431')
          }

          Row() {
            Text('最高: ')
              .fontSize(12)
              .fontColor('#99182431')
            Text(`${this.rideData.maxHeartRate}`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1890FF')
            Text(' bpm')
              .fontSize(12)
              .fontColor('#99182431')
          }
          .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ top: 16 })

      // 心率区间分布
      HeartRateZoneBar({
        zoneDistribution: this.rideData.heartRateZoneDistribution
      })
      .margin({ top: 8 })
    }
  }

  @Builder
  buildElevationSection() {
    Row() {
      // 当前海拔
      DataCard({
        title: '海拔',
        value: Math.round(this.rideData.elevation).toString(),
        unit: 'm'
      })
      .layoutWeight(1)
      .margin({ right: 8 })

      // 累计爬升
      DataCard({
        title: '累计爬升',
        value: Math.round(this.rideData.elevationGain).toString(),
        unit: 'm',
        themeColor: '#52C41A'
      })
      .layoutWeight(1)
      .margin({ left: 8, right: 8 })

      // 坡度
      DataCard({
        title: '坡度',
        value: this.formatGradient(),
        unit: '%',
        themeColor: this.getGradientColor()
      })
      .layoutWeight(1)
      .margin({ left: 8 })
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  buildMapSection() {
    Column() {
      // 地图标题
      Row() {
        Text('实时轨迹')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(`${this.rideData.trackPoints.length} 点`)
          .fontSize(12)
          .fontColor('#99182431')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })

      // 地图占位区域
      Column() {
        // 在实际实现中，这里应该集成地图组件
        // 目前使用占位符显示
        Column() {
          Text('🗺️')
            .fontSize(48)

          Text('地图轨迹显示区域')
            .fontSize(14)
            .fontColor('#99182431')
            .margin({ top: 8 })

          if (this.rideData.trackPoints.length > 0) {
            Text(`已记录 ${this.rideData.trackPoints.length} 个轨迹点`)
              .fontSize(12)
              .fontColor('#80182431')
              .margin({ top: 4 })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(200)
      .backgroundColor('#F0F5FF')
      .borderRadius(12)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 16 })
  }

  @Builder
  buildControlButtons() {
    Row() {
      // 暂停/继续
      Button() {
        Text(this.rideData.state === RideState.PAUSED ? '继续' : '暂停')
          .fontSize(16)
          .fontColor('#182431')
      }
      .width(100)
      .height(48)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
      .onClick(() => {
        if (this.rideData.state === RideState.PAUSED) {
          RideDataService.resumeRide();
        } else {
          RideDataService.pauseRide();
        }
      })

      Blank()

      // 结束
      Button() {
        Text('结束')
          .fontSize(16)
          .fontColor('#FFFFFF')
      }
      .width(100)
      .height(48)
      .backgroundColor('#F5222D')
      .borderRadius(24)
      .onClick(() => {
        this.showEndConfirm = true;
      })
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
  }

  // ==================== 辅助方法 ====================

  private async startRide(): Promise<void> {
    try {
      await RideDataService.startRide();
      hilog.info(DOMAIN, TAG, 'Ride started');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start ride: %{public}s', JSON.stringify(error));
    }
  }

  private formatTime(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  }

  private formatGradient(): string {
    const g = this.rideData.gradient;
    if (g > 0) {
      return `+${g.toFixed(1)}`;
    }
    return g.toFixed(1);
  }

  private getGradientColor(): string {
    const g = this.rideData.gradient;
    if (g > 8) return '#F5222D';
    if (g > 4) return '#FAAD14';
    if (g > 0) return '#52C41A';
    if (g < -4) return '#1890FF';
    return '#182431';
  }

  private getStateText(): string {
    switch (this.rideData.state) {
      case RideState.RIDING:
        return '骑行中';
      case RideState.PAUSED:
        return '已暂停';
      case RideState.ENDING:
        return '结束确认';
      default:
        return '准备中';
    }
  }

  private getStateColor(): string {
    switch (this.rideData.state) {
      case RideState.RIDING:
        return '#52C41A';
      case RideState.PAUSED:
        return '#FAAD14';
      case RideState.ENDING:
        return '#F5222D';
      default:
        return '#182431';
    }
  }

  private getGpsSignalIcon(): string {
    switch (this.rideData.gpsSignal) {
      case GpsSignalState.EXCELLENT:
        return '📡';
      case GpsSignalState.GOOD:
        return '📶';
      case GpsSignalState.FAIR:
        return '📶';
      case GpsSignalState.POOR:
        return '⚠️';
      case GpsSignalState.LOST:
        return '❌';
      default:
        return '❓';
    }
  }

  private getGpsSignalColor(): string {
    switch (this.rideData.gpsSignal) {
      case GpsSignalState.EXCELLENT:
      case GpsSignalState.GOOD:
        return '#52C41A';
      case GpsSignalState.FAIR:
        return '#FAAD14';
      case GpsSignalState.POOR:
      case GpsSignalState.LOST:
        return '#F5222D';
      default:
        return '#182431';
    }
  }

  private getBleIcon(): string {
    return this.rideData.bleConnection === ConnectionState.CONNECTED ? '⌚' : '📱';
  }

  private getBleColor(): string {
    return this.rideData.bleConnection === ConnectionState.CONNECTED ? '#1890FF' : '#FAAD14';
  }
}

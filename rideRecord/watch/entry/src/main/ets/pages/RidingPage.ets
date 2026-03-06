/**
 * 骑行中页面
 *
 * 功能说明：
 * - 显示实时骑行数据（速度、距离、时间、心率）
 * - 支持暂停/继续操作
 * - 显示骑行状态
 * - 支持圆弧按钮交互
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import { HeartRateRing, MiniHeartRate, HeartRateZoneBar } from '../components/HeartRateRing';
import { SpeedDisplay, DistanceDisplay, SpeedRangeIndicator } from '../components/SpeedDisplay';
import { DataCard, CompactDataCard, StatusIndicator, TimerDisplay } from '../components/DataCard';
import { RideState, RideEvent } from '../utils/Types';

const TAG = '[RidingPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct RidingPage {
  // 骑行状态
  @State currentSpeed: number = 0;
  @State distance: number = 0;
  @State elapsedTime: number = 0;
  @State heartRate: number = 0;
  @State avgSpeed: number = 0;
  @State maxSpeed: number = 0;
  @State elevation: number = 0;
  @State elevationGain: number = 0;
  @State rideState: string = 'RIDING';
  @State calories: number = 0;

  // 用户设置
  @State maxHeartRate: number = 185;

  // 计时器ID
  private timerId: number = -1;
  private startTime: number = 0;

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'RidingPage aboutToAppear');
    this.startTime = Date.now();
    this.startTimer();
    this.startSimulation();
  }

  aboutToDisappear() {
    hilog.info(DOMAIN, TAG, 'RidingPage aboutToDisappear');
    this.stopTimer();
  }

  // 启动计时器
  private startTimer(): void {
    this.timerId = setInterval(() => {
      this.elapsedTime = Math.floor((Date.now() - this.startTime) / 1000);
    }, 1000);
  }

  // 停止计时器
  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  // 模拟数据（测试用）
  private startSimulation(): void {
    setInterval(() => {
      // 模拟速度变化
      this.currentSpeed = 20 + Math.random() * 15;
      if (this.currentSpeed > this.maxSpeed) {
        this.maxSpeed = this.currentSpeed;
      }

      // 模拟距离增加
      this.distance += this.currentSpeed / 3.6;

      // 模拟心率
      this.heartRate = 120 + Math.floor(Math.random() * 40);

      // 模拟海拔
      this.elevation = 50 + Math.random() * 10;
      this.elevationGain += Math.random() > 0.8 ? 2 : 0;

      // 计算平均速度
      if (this.elapsedTime > 0) {
        this.avgSpeed = (this.distance / 1000) / (this.elapsedTime / 3600);
      }

      // 计算热量 (简化公式)
      this.calories = Math.floor(this.elapsedTime * 0.15);
    }, 1000);
  }

  // 暂停骑行
  private pauseRide(): void {
    hilog.info(DOMAIN, TAG, 'Pause ride');
    this.rideState = 'PAUSED';
    this.stopTimer();
    // TODO: 调用状态机
  }

  // 继续骑行
  private resumeRide(): void {
    hilog.info(DOMAIN, TAG, 'Resume ride');
    this.rideState = 'RIDING';
    this.startTimer();
    // TODO: 调用状态机
  }

  // 结束骑行
  private endRide(): void {
    hilog.info(DOMAIN, TAG, 'End ride');
    this.stopTimer();
    // 跳转到总结页面
    router.pushUrl({
      url: 'pages/SummaryPage',
      params: {
        distance: this.distance,
        duration: this.elapsedTime,
        avgSpeed: this.avgSpeed,
        maxSpeed: this.maxSpeed,
        calories: this.calories,
        elevationGain: this.elevationGain,
        avgHeartRate: this.heartRate
      }
    });
  }

  build() {
    Column() {
      // 顶部状态栏
      Row() {
        StatusIndicator({ status: this.rideState, isActive: true })

        Blank()

        MiniHeartRate({ heartRate: this.heartRate })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })

      // 主要数据区域
      Column() {
        // 速度显示
        SpeedDisplay({ speed: this.currentSpeed, fontSize: 56 })
          .margin({ top: 10 })

        // 速度范围指示
        SpeedRangeIndicator({ currentSpeed: this.currentSpeed, maxSpeed: 60 })
          .width('80%')
          .margin({ top: 8 })

        // 计时器
        TimerDisplay({ seconds: this.elapsedTime })
          .margin({ top: 8 })

        // 数据网格
        Row() {
          // 距离
          Column() {
            Text('距离')
              .fontSize(10)
              .fontColor('#99182431')
            DistanceDisplay({ distance: this.distance })
          }
          .layoutWeight(1)

          // 心率环
          HeartRateRing({
            heartRate: this.heartRate,
            maxHeartRate: this.maxHeartRate,
            size: 80,
            strokeWidth: 6
          })
          .layoutWeight(1.5)

          // 平均速度
          Column() {
            Text('均速')
              .fontSize(10)
              .fontColor('#99182431')
            Row() {
              Text(this.avgSpeed.toFixed(1))
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
              Text('km/h')
                .fontSize(10)
                .fontColor('#99182431')
                .margin({ left: 2 })
            }
          }
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 16 })

        // 心率区间条
        HeartRateZoneBar({
          heartRate: this.heartRate,
          maxHeartRate: this.maxHeartRate
        })
          .width('90%')
          .margin({ top: 12 })

        // 底部数据
        Row() {
          CompactDataCard({ title: '热量', value: `${this.calories}`, unit: 'kcal' })
          CompactDataCard({ title: '最高速', value: this.maxSpeed.toFixed(1), unit: 'km/h' })
          CompactDataCard({ title: '爬升', value: `${Math.round(this.elevationGain)}`, unit: 'm' })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .margin({ top: 12 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 底部操作按钮
      Row() {
        // 暂停/继续按钮
        Column() {
          Text(this.rideState === 'PAUSED' ? '▶' : '⏸')
            .fontSize(28)
            .fontColor('#182431')
          Text(this.rideState === 'PAUSED' ? '继续' : '暂停')
            .fontSize(10)
            .fontColor('#99182431')
        }
        .width(70)
        .height(70)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F5F5F5')
        .borderRadius(35)
        .onClick(() => {
          if (this.rideState === 'PAUSED') {
            this.resumeRide();
          } else {
            this.pauseRide();
          }
        })

        // 结束按钮
        Column() {
          Text('⏹')
            .fontSize(28)
            .fontColor('#FFFFFF')
          Text('结束')
            .fontSize(10)
            .fontColor('#FFFFFF')
        }
        .width(70)
        .height(70)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F44336')
        .borderRadius(35)
        .margin({ left: 20 })
        .onClick(() => this.endRide())
      }
      .margin({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

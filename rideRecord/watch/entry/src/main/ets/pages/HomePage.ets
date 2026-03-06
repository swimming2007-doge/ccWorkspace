/**
 * 手表端首页
 *
 * 功能说明：
 * - 显示骑行状态
 * - 显示实时数据（心率、速度、距离）
 * - 提供开始/结束骑行按钮
 * - 集成动作检测服务
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import sensor from '@ohos.sensor';
import { HeartRateRing, MiniHeartRate } from '../components/HeartRateRing';
import { StatusIndicator, TimerDisplay } from '../components/DataCard';
import { SpeedDisplay, DistanceDisplay } from '../components/SpeedDisplay';
import { RideState, RideEvent, ActionType } from '../utils/Types';
import { SensorService } from '../services/SensorService';
import { ActionDetector } from '../services/ActionDetector';
import { RideStateMachine } from '../services/RideStateMachine';

const TAG = '[HomePage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct HomePage {
  // 骑行状态
  @State rideState: string = RideState.IDLE;
  @State heartRate: number = 0;
  @State speed: number = 0;
  @State distance: number = 0;
  @State elapsedTime: number = 0;
  @State avgSpeed: number = 0;
  @State maxSpeed: number = 0;

  // 服务实例
  private sensorService: SensorService = new SensorService();
  private actionDetector: ActionDetector = new ActionDetector();
  private stateMachine: RideStateMachine = new RideStateMachine();

  // 计时器
  private timerId: number = -1;
  private rideStartTime: number = 0;
  private totalDistance: number = 0;

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'HomePage aboutToAppear');
    this.setupStateMachine();
    this.startHeartRateMonitor();
  }

  aboutToDisappear() {
    hilog.info(DOMAIN, TAG, 'HomePage aboutToDisappear');
    this.stopHeartRateMonitor();
  }

  // 设置状态机回调
  private setupStateMachine(): void {
    this.stateMachine.onStateChange((event: RideEvent) => {
      hilog.info(DOMAIN, TAG, 'State change event: %{public}s', event);

      switch (event) {
        case RideEvent.RIDE_START:
          this.onRideStart();
          break;
        case RideEvent.RIDE_PAUSE:
          this.onRidePause();
          break;
        case RideEvent.RIDE_RESUME:
          this.onRideResume();
          break;
        case RideEvent.RIDE_END_REQUEST:
          this.onRideEndRequest();
          break;
        case RideEvent.RIDE_END_CONFIRMED:
          this.onRideEndConfirmed();
          break;
        case RideEvent.RIDE_CONTINUE:
          this.rideState = RideState.RIDING;
          break;
      }
    });
  }

  // 开始心率监测
  private startHeartRateMonitor(): void {
    try {
      sensor.on(sensor.SensorType.HEART_RATE, (data) => {
        this.heartRate = data.heartRate;
      }, { interval: 1000000000 }); // 1秒
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start heart rate: %{public}s', JSON.stringify(error));
    }
  }

  // 停止心率监测
  private stopHeartRateMonitor(): void {
    try {
      sensor.off(sensor.SensorType.HEART_RATE);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to stop heart rate: %{public}s', JSON.stringify(error));
    }
  }

  // 开始骑行
  private onRideStart(): void {
    hilog.info(DOMAIN, TAG, 'Ride started');
    this.rideState = RideState.RIDING;
    this.rideStartTime = Date.now();
    this.startTimer();
    this.startSensorServices();

    // 跳转到骑行页面
    router.pushUrl({ url: 'pages/RidingPage' });
  }

  // 暂停骑行
  private onRidePause(): void {
    hilog.info(DOMAIN, TAG, 'Ride paused');
    this.rideState = RideState.PAUSED;
    this.stopTimer();
  }

  // 恢复骑行
  private onRideResume(): void {
    hilog.info(DOMAIN, TAG, 'Ride resumed');
    this.rideState = RideState.RIDING;
    this.startTimer();
  }

  // 请求结束骑行
  private onRideEndRequest(): void {
    hilog.info(DOMAIN, TAG, 'Ride end requested');
    this.rideState = RideState.ENDING;
  }

  // 确认结束骑行
  private onRideEndConfirmed(): void {
    hilog.info(DOMAIN, TAG, 'Ride ended');
    this.rideState = RideState.IDLE;
    this.stopTimer();
    this.stopSensorServices();

    // 跳转到总结页面
    router.replaceUrl({
      url: 'pages/SummaryPage',
      params: {
        distance: this.totalDistance,
        duration: this.elapsedTime,
        avgSpeed: this.avgSpeed,
        maxSpeed: this.maxSpeed
      }
    });
  }

  // 启动计时器
  private startTimer(): void {
    this.timerId = setInterval(() => {
      this.elapsedTime = Math.floor((Date.now() - this.rideStartTime) / 1000);
    }, 1000);
  }

  // 停止计时器
  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  // 启动传感器服务
  private startSensorServices(): void {
    this.sensorService.setSensorDataCallback((data) => {
      // 处理传感器数据
      this.speed = data.speed;

      // 发送到动作检测器
      const result = this.actionDetector.addSensorData(data);
      if (result) {
        this.stateMachine.transition(result.action, this.speed);
      }
    });

    this.sensorService.start();
  }

  // 停止传感器服务
  private stopSensorServices(): void {
    this.sensorService.stop();
    this.actionDetector.reset();
  }

  // 手动开始骑行
  private manualStartRide(): void {
    hilog.info(DOMAIN, TAG, 'Manual start ride');
    this.stateMachine.transition(ActionType.MOUNT, 0);
    this.stateMachine.transition(ActionType.PEDALING, 0);
  }

  // 手动结束骑行
  private manualEndRide(): void {
    hilog.info(DOMAIN, TAG, 'Manual end ride');
    this.stateMachine.transition(ActionType.DISMOUNT, 0);
  }

  build() {
    Column() {
      // 顶部状态栏
      Row() {
        Text('RideRecord')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)

        Blank()

        MiniHeartRate({ heartRate: this.heartRate })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })

      // 状态指示
      StatusIndicator({ status: this.rideState, isActive: this.rideState !== RideState.IDLE })
        .margin({ top: 8 })

      // 主要内容区域
      if (this.rideState === RideState.IDLE) {
        // 空闲状态 - 等待开始
        Column() {
          Text('准备骑行')
            .fontSize(20)
            .fontColor('#182431')
            .margin({ bottom: 8 })

          Text('检测到上车动作后自动开始')
            .fontSize(12)
            .fontColor('#99182431')
            .textAlign(TextAlign.Center)

          // 心率预览
          HeartRateRing({
            heartRate: this.heartRate,
            maxHeartRate: 185,
            size: 100
          })
            .margin({ top: 24 })

          // 手动开始按钮
          Button('手动开始')
            .width('60%')
            .height(44)
            .fontSize(16)
            .margin({ top: 32 })
            .onClick(() => this.manualStartRide())
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // 骑行中/暂停 - 显示数据
        Column() {
          // 计时器
          TimerDisplay({ seconds: this.elapsedTime })
            .margin({ top: 16 })

          // 数据概览
          Row() {
            Column() {
              Text('距离')
                .fontSize(10)
                .fontColor('#99182431')
              DistanceDisplay({ distance: this.distance })
            }
            .layoutWeight(1)

            HeartRateRing({
              heartRate: this.heartRate,
              maxHeartRate: 185,
              size: 80
            })

            Column() {
              Text('速度')
                .fontSize(10)
                .fontColor('#99182431')
              SpeedDisplay({ speed: this.speed, fontSize: 24 })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 16 })

          // 跳转到详细页面
          Button('详细数据')
            .width('60%')
            .height(40)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .fontColor('#182431')
            .margin({ top: 24 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/RidingPage' });
            })

          // 结束按钮
          Button('结束骑行')
            .width('60%')
            .height(40)
            .fontSize(14)
            .backgroundColor('#F44336')
            .margin({ top: 12 })
            .onClick(() => this.manualEndRide())
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      // 底部提示
      Text('动作检测已启用')
        .fontSize(10)
        .fontColor('#99182431')
        .margin({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

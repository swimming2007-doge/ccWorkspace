/**
 * 骑行中页面（手机端）
 *
 * 功能说明：
 * - 显示实时骑行数据
 * - 地图轨迹显示
 * - 心率区间可视化
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';

const TAG = '[RidingPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct RidingPage {
  @State currentSpeed: number = 0;
  @State distance: number = 0;
  @State elapsedTime: number = 0;
  @State heartRate: number = 0;
  @State avgSpeed: number = 0;

  build() {
    Column() {
      // 顶部状态栏
      Row() {
        Button('结束')
          .onClick(() => router.back())

        Blank()

        Text('骑行中')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding(16)

      // 实时数据
      Column() {
        // 速度
        Text(`${this.currentSpeed.toFixed(1)}`)
          .fontSize(72)
          .fontWeight(FontWeight.Bold)

        Text('km/h')
          .fontSize(16)
          .fontColor('#99182431')

        // 距离和时间
        Row() {
          Column() {
            Text('距离')
              .fontSize(12)
              .fontColor('#99182431')
            Text(`${(this.distance / 1000).toFixed(2)} km`)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)

          Column() {
            Text('时间')
              .fontSize(12)
              .fontColor('#99182431')
            Text(this.formatTime())
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)

          Column() {
            Text('心率')
              .fontSize(12)
              .fontColor('#99182431')
            Text(`${this.heartRate} bpm`)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 24 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 地图占位
      Column() {
        Text('地图区域')
          .fontSize(14)
          .fontColor('#99182431')
      }
      .width('100%')
      .height(200)
      .backgroundColor('#F5F5F5')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  private formatTime(): string {
    const minutes = Math.floor(this.elapsedTime / 60);
    const seconds = this.elapsedTime % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }
}

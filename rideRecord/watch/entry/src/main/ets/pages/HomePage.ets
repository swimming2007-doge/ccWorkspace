/**
 * 手表端首页
 *
 * 功能说明：
 * - 显示骑行状态
 * - 显示实时数据（心率、速度、距离）
 * - 提供开始/结束骑行按钮
 */
import hilog from '@ohos.hilog';

const TAG = '[HomePage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct HomePage {
  @State message: string = 'RideRecord';
  @State rideState: string = 'IDLE';
  @State heartRate: number = 0;
  @State speed: number = 0;
  @State distance: number = 0;

  build() {
    Column() {
      // 标题
      Text(this.message)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })

      // 状态显示
      Text(`状态: ${this.rideState}`)
        .fontSize(16)
        .margin({ bottom: 10 })

      // 数据展示区域
      Row() {
        Column() {
          Text('心率')
            .fontSize(12)
          Text(`${this.heartRate}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
        }
        .layoutWeight(1)

        Column() {
          Text('速度')
            .fontSize(12)
          Text(`${this.speed.toFixed(1)}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
        }
        .layoutWeight(1)

        Column() {
          Text('距离')
            .fontSize(12)
          Text(`${(this.distance / 1000).toFixed(2)}km`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
        }
        .layoutWeight(1)
      }
      .margin({ top: 20, bottom: 20 })

      // 开始/结束按钮
      Button(this.rideState === 'IDLE' ? '开始骑行' : '结束骑行')
        .width('80%')
        .height(50)
        .fontSize(18)
        .onClick(() => {
          hilog.info(DOMAIN, TAG, 'Button clicked');
          // TODO: 调用动作检测服务
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}

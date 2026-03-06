/**
 * 骑行总结页面
 *
 * 功能说明：
 * - 显示骑行统计数据
 * - 总距离、时长、平均速度、热量消耗
 * - 心率分布
 * - 支持保存/放弃操作
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import { DataCard, CompactDataCard, TimerDisplay } from '../components/DataCard';
import { HeartRateZoneBar } from '../components/HeartRateRing';

const TAG = '[SummaryPage]';
const DOMAIN = 0xFF00;

interface RideSummary {
  distance: number;
  duration: number;
  avgSpeed: number;
  maxSpeed: number;
  calories: number;
  elevationGain: number;
  avgHeartRate: number;
}

@Entry
@Component
struct SummaryPage {
  // 骑行数据
  @State distance: number = 0;
  @State duration: number = 0;
  @State avgSpeed: number = 0;
  @State maxSpeed: number = 0;
  @State calories: number = 0;
  @State elevationGain: number = 0;
  @State avgHeartRate: number = 0;
  @State maxHeartRate: number = 0;

  // 心率区间分布 (模拟)
  @State heartRateZones: number[] = [15, 35, 30, 15, 5];

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'SummaryPage aboutToAppear');

    // 获取路由参数
    const params = router.getParams() as RideSummary;
    if (params) {
      this.distance = params.distance || 0;
      this.duration = params.duration || 0;
      this.avgSpeed = params.avgSpeed || 0;
      this.maxSpeed = params.maxSpeed || 0;
      this.calories = params.calories || 0;
      this.elevationGain = params.elevationGain || 0;
      this.avgHeartRate = params.avgHeartRate || 0;
    }
  }

  // 格式化时间
  private formatDuration(): string {
    const hours = Math.floor(this.duration / 3600);
    const minutes = Math.floor((this.duration % 3600) / 60);
    const seconds = this.duration % 60;

    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}分${seconds}秒`;
  }

  // 格式化距离
  private formatDistance(): string {
    if (this.distance >= 1000) {
      return (this.distance / 1000).toFixed(2);
    }
    return this.distance.toFixed(0);
  }

  // 获取距离单位
  private getDistanceUnit(): string {
    return this.distance >= 1000 ? 'km' : 'm';
  }

  // 保存骑行记录
  private saveRide(): void {
    hilog.info(DOMAIN, TAG, 'Save ride');
    // TODO: 保存到本地存储
    // 返回首页
    router.replaceUrl({ url: 'pages/HomePage' });
  }

  // 放弃骑行记录
  private discardRide(): void {
    hilog.info(DOMAIN, TAG, 'Discard ride');
    // 返回首页
    router.replaceUrl({ url: 'pages/HomePage' });
  }

  build() {
    Column() {
      // 标题
      Text('骑行完成')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16 })

      // 主要统计卡片
      Column() {
        // 距离
        Text('总距离')
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ top: 20 })

        Row() {
          Text(this.formatDistance())
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor('#007DFF')

          Text(this.getDistanceUnit())
            .fontSize(16)
            .fontColor('#99182431')
            .margin({ left: 4, bottom: 8 })
        }
        .alignItems(VerticalAlign.Bottom)

        // 时长
        Text(this.formatDuration())
          .fontSize(20)
          .fontColor('#182431')
          .margin({ top: 4 })
      }
      .margin({ top: 16 })

      // 数据网格
      Grid() {
        // 平均速度
        GridItem() {
          Column() {
            Text('平均速度')
              .fontSize(10)
              .fontColor('#99182431')
            Row() {
              Text(this.avgSpeed.toFixed(1))
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
              Text('km/h')
                .fontSize(10)
                .fontColor('#99182431')
            }
          }
          .padding(8)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
        }

        // 最高速度
        GridItem() {
          Column() {
            Text('最高速度')
              .fontSize(10)
              .fontColor('#99182431')
            Row() {
              Text(this.maxSpeed.toFixed(1))
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
              Text('km/h')
                .fontSize(10)
                .fontColor('#99182431')
            }
          }
          .padding(8)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
        }

        // 热量
        GridItem() {
          Column() {
            Text('消耗热量')
              .fontSize(10)
              .fontColor('#99182431')
            Row() {
              Text(`${this.calories}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
              Text('kcal')
                .fontSize(10)
                .fontColor('#99182431')
            }
          }
          .padding(8)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
        }

        // 爬升
        GridItem() {
          Column() {
            Text('累计爬升')
              .fontSize(10)
              .fontColor('#99182431')
            Row() {
              Text(`${Math.round(this.elevationGain)}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
              Text('m')
                .fontSize(10)
                .fontColor('#99182431')
            }
          }
          .padding(8)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
        }

        // 平均心率
        GridItem() {
          Column() {
            Text('平均心率')
              .fontSize(10)
              .fontColor('#99182431')
            Row() {
              Text(`${this.avgHeartRate}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
              Text('bpm')
                .fontSize(10)
                .fontColor('#99182431')
            }
          }
          .padding(8)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
        }

        // 最高心率
        GridItem() {
          Column() {
            Text('最高心率')
              .fontSize(10)
              .fontColor('#99182431')
            Row() {
              Text(`${this.maxHeartRate || this.avgHeartRate + 30}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
              Text('bpm')
                .fontSize(10)
                .fontColor('#99182431')
            }
          }
          .padding(8)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
        }
      }
      .columnsTemplate('1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .width('90%')
      .height(180)
      .margin({ top: 16 })

      // 心率区间分布
      Column() {
        Text('心率区间分布')
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ bottom: 8 })

        Row() {
          ForEach(this.heartRateZones, (percent: number, index: number) => {
            Column() {
              Column()
                .width(20)
                .height(percent * 1.5)
                .backgroundColor(this.getZoneColor(index))
                .borderRadius(4)

              Text(`Z${index + 1}`)
                .fontSize(8)
                .fontColor('#99182431')
                .margin({ top: 2 })

              Text(`${percent}%`)
                .fontSize(8)
                .fontColor(this.getZoneColor(index))
            }
            .layoutWeight(1)
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      }
      .width('90%')
      .margin({ top: 16 })

      Blank()

      // 操作按钮
      Row() {
        // 放弃
        Button('放弃')
          .width('40%')
          .height(44)
          .fontSize(16)
          .backgroundColor('#F5F5F5')
          .fontColor('#182431')
          .onClick(() => this.discardRide())

        // 保存
        Button('保存')
          .width('40%')
          .height(44)
          .fontSize(16)
          .type(ButtonType.Capsule)
          .onClick(() => this.saveRide())
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  // 获取心率区间颜色
  private getZoneColor(index: number): string {
    const colors = ['#90CAF9', '#4CAF50', '#FFEB3B', '#FF9800', '#F44336'];
    return colors[index] || '#99182431';
  }
}

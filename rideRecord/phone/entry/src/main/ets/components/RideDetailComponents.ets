/**
 * 骑行详情数据组件
 *
 * 功能说明：
 * - 数据摘要展示
 * - 心率区间分布图
 * - 速度/海拔折线图
 * - 分段数据展示
 */
import { RideRecordEntity, TrackPointEntity } from '../services/RideStorageService';

/**
 * 骑行数据摘要组件
 */
@Component
export struct RideDetailSummary {
  @Prop ride: RideRecordEntity | null = null;

  build() {
    Column() {
      // 日期和标题
      Row() {
        Column() {
          Text(this.formatDate(this.ride?.start_time || ''))
            .fontSize(14)
            .fontColor('#99182431')

          Text(this.ride?.title || '骑行记录')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#182431')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 分享按钮
        Button() {
          Text('分享')
            .fontSize(14)
            .fontColor('#1890FF')
        }
        .height(32)
        .backgroundColor('#E6F7FF')
        .borderRadius(16)
        .padding({ left: 16, right: 16 })
      }
      .width('100%')

      // 主要数据
      Row() {
        this.buildMainData('距离', `${((this.ride?.distance || 0) / 1000).toFixed(2)}`, 'km')
        this.buildMainData('时长', this.formatDuration(this.ride?.duration || 0), '')
        this.buildMainData('均速', `${(this.ride?.avg_speed || 0).toFixed(1)}`, 'km/h')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 20 })

      // 次要数据
      Row() {
        this.buildSubData('最高速度', `${(this.ride?.max_speed || 0).toFixed(1)}`, 'km/h')
        this.buildSubData('平均心率', `${this.ride?.avg_heart_rate || '--'}`, 'bpm')
        this.buildSubData('最高心率', `${this.ride?.max_heart_rate || '--'}`, 'bpm')
        this.buildSubData('消耗', `${this.ride?.calories || 0}`, 'kcal')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 16 })

      // 海拔数据
      Row() {
        this.buildSubData('累计爬升', `${Math.round(this.ride?.elevation_gain || 0)}`, 'm')
        this.buildSubData('累计下降', `${Math.round(this.ride?.elevation_loss || 0)}`, 'm')
        this.buildSubData('移动时间', this.formatDuration(this.ride?.moving_time || 0), '')
        this.buildSubData('轨迹点', `${this.ride?.track_point_count || 0}`, '个')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  buildMainData(label: string, value: string, unit: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#99182431')

      Row() {
        Text(value)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1890FF')

        if (unit) {
          Text(unit)
            .fontSize(12)
            .fontColor('#99182431')
            .margin({ left: 2, bottom: 8 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildSubData(label: string, value: string, unit: string) {
    Column() {
      Text(label)
        .fontSize(10)
        .fontColor('#80182431')

      Row() {
        Text(value)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)

        if (unit) {
          Text(unit)
            .fontSize(10)
            .fontColor('#99182431')
            .margin({ left: 2 })
        }
      }
    }
    .alignItems(HorizontalAlign.Center)
  }

  private formatDate(dateStr: string): string {
    if (!dateStr) return '--';
    const date = new Date(dateStr);
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${weekdays[date.getDay()]}`;
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  }
}

/**
 * 心率区间分布图
 */
@Component
export struct HeartRateZoneChart {
  @Prop zone1Time: number = 0;
  @Prop zone2Time: number = 0;
  @Prop zone3Time: number = 0;
  @Prop zone4Time: number = 0;
  @Prop zone5Time: number = 0;

  private zones = [
    { name: 'Z1 恢复', color: '#52C41A' },
    { name: 'Z2 有氧', color: '#1890FF' },
    { name: 'Z3 强化', color: '#FAAD14' },
    { name: 'Z4 阈值', color: '#FF7A45' },
    { name: 'Z5 极限', color: '#F5222D' }
  ];

  private getTotalTime(): number {
    return this.zone1Time + this.zone2Time + this.zone3Time + this.zone4Time + this.zone5Time;
  }

  private getPercent(time: number): number {
    const total = this.getTotalTime();
    if (total === 0) return 0;
    return Math.round((time / total) * 100);
  }

  build() {
    Column() {
      Text('心率区间分布')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      // 分布条
      Row() {
        ForEach([
          { time: this.zone1Time, color: '#52C41A' },
          { time: this.zone2Time, color: '#1890FF' },
          { time: this.zone3Time, color: '#FAAD14' },
          { time: this.zone4Time, color: '#FF7A45' },
          { time: this.zone5Time, color: '#F5222D' }
        ], (item: { time: number; color: string }) => {
          const percent = this.getPercent(item.time);
          if (percent > 0) {
            Row()
              .width(`${percent}%`)
              .height(24)
              .backgroundColor(item.color)
          }
        })
      }
      .width('100%')
      .height(24)
      .borderRadius(4)
      .clip(true)

      // 详细数据
      Column() {
        ForEach([
          { name: 'Z1 恢复区', time: this.zone1Time, color: '#52C41A', range: '50-60%' },
          { name: 'Z2 有氧区', time: this.zone2Time, color: '#1890FF', range: '60-70%' },
          { name: 'Z3 强化区', time: this.zone3Time, color: '#FAAD14', range: '70-80%' },
          { name: 'Z4 阈值区', time: this.zone4Time, color: '#FF7A45', range: '80-90%' },
          { name: 'Z5 极限区', time: this.zone5Time, color: '#F5222D', range: '90-100%' }
        ], (zone: { name: string; time: number; color: string; range: string }) => {
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill(zone.color)

            Text(zone.name)
              .fontSize(12)
              .margin({ left: 8 })

            Text(`(${zone.range})`)
              .fontSize(10)
              .fontColor('#99182431')
              .margin({ left: 4 })

            Blank()

            Text(this.formatTime(zone.time))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)

            Text(` (${this.getPercent(zone.time)}%)`)
              .fontSize(10)
              .fontColor('#99182431')
          }
          .width('100%')
          .padding({ top: 8 })
        })
      }
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  private formatTime(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  }
}

/**
 * 数据图表组件 (简化版)
 */
@Component
export struct RideDataChart {
  @Prop title: string = '';
  @Prop data: number[] = [];
  @Prop color: string = '#1890FF';
  @Prop unit: string = '';
  @Prop height: number = 120;

  private get min(): number {
    if (this.data.length === 0) return 0;
    return Math.min(...this.data);
  }

  private get max(): number {
    if (this.data.length === 0) return 0;
    return Math.max(...this.data);
  }

  private get avg(): number {
    if (this.data.length === 0) return 0;
    return this.data.reduce((a, b) => a + b, 0) / this.data.length;
  }

  build() {
    Column() {
      // 标题和统计
      Row() {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(`平均: ${this.avg.toFixed(1)}${this.unit}`)
          .fontSize(12)
          .fontColor('#99182431')

        Text(` | 最高: ${this.max.toFixed(1)}${this.unit}`)
          .fontSize(12)
          .fontColor(this.color)
          .margin({ left: 4 })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 图表区域
      Column() {
        if (this.data.length > 0) {
          // 简化的折线图显示
          Row() {
            ForEach(this.getSampledData(), (value: number, index: number) => {
              Column() {
                Column()
                  .width(2)
                  .height(this.getBarHeight(value))
                  .backgroundColor(this.color)
                  .borderRadius(1)
              }
              .height('100%')
              .justifyContent(FlexAlign.End)
            })
          }
          .width('100%')
          .height(this.height - 20)
          .alignItems(VerticalAlign.Bottom)
        } else {
          Text('暂无数据')
            .fontSize(12)
            .fontColor('#99182431')
        }
      }
      .width('100%')
      .height(this.height)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  private getSampledData(): number[] {
    // 采样数据，最多显示50个点
    if (this.data.length <= 50) {
      return this.data;
    }

    const step = Math.floor(this.data.length / 50);
    const sampled: number[] = [];
    for (let i = 0; i < this.data.length; i += step) {
      sampled.push(this.data[i]);
    }
    return sampled;
  }

  private getBarHeight(value: number): number {
    if (this.max === this.min) return 20;
    const percent = (value - this.min) / (this.max - this.min);
    return Math.max(4, percent * (this.height - 40));
  }
}

/**
 * 分段数据组件
 */
@Component
export struct RideSegments {
  @Prop segments: Array<{
    type: string;
    distance: number;
    duration: number;
    avgSpeed: number;
  }> = [];

  build() {
    Column() {
      Text('路段分析')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      if (this.segments.length > 0) {
        ForEach(this.segments, (segment: {
          type: string;
          distance: number;
          duration: number;
          avgSpeed: number;
        }, index: number) => {
          Row() {
            Text(`路段 ${index + 1}`)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)

            Blank()

            Text(`${(segment.distance / 1000).toFixed(2)}km`)
              .fontSize(12)
              .margin({ left: 8 })

            Text(`${this.formatDuration(segment.duration)}`)
              .fontSize(12)
              .fontColor('#99182431')
              .margin({ left: 8 })

            Text(`${segment.avgSpeed.toFixed(1)}km/h`)
              .fontSize(12)
              .fontColor('#1890FF')
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .border({ width: { bottom: 1 }, color: '#F0F0F0' })
        })
      } else {
        Text('暂无分段数据')
          .fontSize(12)
          .fontColor('#99182431')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  private formatDuration(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    return `${minutes}分`;
  }
}

/**
 * 操作按钮组件
 */
@Component
export struct RideActionButtons {
  onExport?: () => void;
  onDelete?: () => void;
  onShare?: () => void;

  build() {
    Row() {
      Button() {
        Column() {
          Text('📤')
            .fontSize(20)
          Text('导出')
            .fontSize(10)
            .fontColor('#182431')
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .height(64)
      .backgroundColor('#F7F8FA')
      .borderRadius(12)
      .onClick(() => this.onExport?.())

      Button() {
        Column() {
          Text('🔗')
            .fontSize(20)
          Text('分享')
            .fontSize(10)
            .fontColor('#182431')
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .height(64)
      .backgroundColor('#F7F8FA')
      .borderRadius(12)
      .margin({ left: 8, right: 8 })
      .onClick(() => this.onShare?.())

      Button() {
        Column() {
          Text('🗑️')
            .fontSize(20)
          Text('删除')
            .fontSize(10)
            .fontColor('#F5222D')
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .height(64)
      .backgroundColor('#F7F8FA')
      .borderRadius(12)
      .onClick(() => this.onDelete?.())
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}

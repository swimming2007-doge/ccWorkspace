/**
 * 统计界面组件
 *
 * 功能说明：
 * - 统计摘要卡片
 * - 趋势图表
 * - 心率区间图
 * - 热力图
 */

import { StatsData, TrendPoint, WeeklyStats, MonthlyStats, HRZoneDistribution } from '../services/StatsService';

/**
 * 统计摘要卡片
 */
@Component
export struct StatsSummaryCard {
  @Prop title: string = '';
  @Prop stats: StatsData | null = null;

  build() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      Row() {
        this.buildStatItem('骑行', `${this.stats?.totalRides || 0}`, '次')
        this.buildStatItem('距离', this.formatDistance(this.stats?.totalDistance || 0), '')
        this.buildStatItem('时长', this.formatDuration(this.stats?.totalDuration || 0), '')
        this.buildStatItem('热量', `${this.stats?.totalCalories || 0}`, 'kcal')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  buildStatItem(label: string, value: string, unit: string) {
    Column() {
      Row() {
        Text(value)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')

        if (unit) {
          Text(unit)
            .fontSize(10)
            .fontColor('#99182431')
            .margin({ left: 2 })
        }
      }

      Text(label)
        .fontSize(10)
        .fontColor('#99182431')
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  private formatDistance(meters: number): string {
    if (meters >= 1000000) {
      return `${(meters / 1000000).toFixed(1)}k`;
    }
    return `${(meters / 1000).toFixed(1)}`;
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    if (hours >= 100) {
      return `${hours}`;
    }
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) {
      return `${hours}h${minutes}m`;
    }
    return `${minutes}m`;
  }
}

/**
 * 心率区间分布图
 */
@Component
export struct HeartRateZoneChart {
  @Prop distribution: HRZoneDistribution | null = null;

  private get total(): number {
    if (!this.distribution) return 0;
    return this.distribution.zone1 + this.distribution.zone2 +
           this.distribution.zone3 + this.distribution.zone4 +
           this.distribution.zone5;
  }

  private get zones(): Array<{ name: string; time: number; percent: number; color: string }> {
    const total = this.total;
    if (total === 0 || !this.distribution) return [];

    return [
      { name: 'Z1 恢复', time: this.distribution.zone1, percent: this.distribution.zone1 / total * 100, color: '#91D5FF' },
      { name: 'Z2 有氧', time: this.distribution.zone2, percent: this.distribution.zone2 / total * 100, color: '#52C41A' },
      { name: 'Z3 节奏', time: this.distribution.zone3, percent: this.distribution.zone3 / total * 100, color: '#FAAD14' },
      { name: 'Z4 阈值', time: this.distribution.zone4, percent: this.distribution.zone4 / total * 100, color: '#FA8C16' },
      { name: 'Z5 极限', time: this.distribution.zone5, percent: this.distribution.zone5 / total * 100, color: '#F5222D' }
    ];
  }

  build() {
    Column() {
      Text('心率区间分布')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      // 条形图
      Column() {
        ForEach(this.zones, (zone: { name: string; time: number; percent: number; color: string }) => {
          Row() {
            Text(zone.name)
              .fontSize(12)
              .width(60)
              .fontColor('#182431')

            Row() {
              Row()
                .width(`${zone.percent}%`)
                .height(16)
                .backgroundColor(zone.color)
                .borderRadius(4)
            }
            .width(120)
            .height(16)
            .backgroundColor('#F0F0F0')
            .borderRadius(4)

            Text(this.formatTime(zone.time))
              .fontSize(12)
              .fontColor('#99182431')
              .width(50)
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ top: 8 })
        })
      }
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 12 })
  }

  private formatTime(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) {
      return `${hours}h${minutes}m`;
    }
    return `${minutes}m`;
  }
}

/**
 * 趋势图表
 */
@Component
export struct TrendChart {
  @Prop title: string = '';
  @Prop data: TrendPoint[] = [];
  @Prop unit: string = '';
  @Prop color: string = '#1890FF';

  private get maxValue(): number {
    if (this.data.length === 0) return 0;
    return Math.max(...this.data.map(d => d.value));
  }

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(`${this.formatValue(this.maxValue)} ${this.unit}`)
          .fontSize(12)
          .fontColor('#99182431')
      }
      .width('100%')

      // 简化图表 - 柱状图
      Row() {
        ForEach(this.data.slice(-7), (point: TrendPoint, index: number) => {
          Column() {
            Column()
              .width(20)
              .height(this.maxValue > 0 ? `${(point.value / this.maxValue) * 100}%` : '0%')
              .backgroundColor(this.color)
              .borderRadius({ topLeft: 4, topRight: 4 })

            Text(point.date.slice(5))
              .fontSize(8)
              .fontColor('#99182431')
              .margin({ top: 4 })
          }
          .height(100)
          .justifyContent(FlexAlign.End)
          .margin({ left: index > 0 ? 8 : 0 })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 12 })
  }

  private formatValue(value: number): string {
    if (value >= 1000000) {
      return `${(value / 1000000).toFixed(1)}M`;
    } else if (value >= 1000) {
      return `${(value / 1000).toFixed(1)}k`;
    }
    return value.toFixed(1);
  }
}

/**
 * 月度统计卡片
 */
@Component
export struct MonthlyStatsCard {
  @Prop monthStats: MonthlyStats | null = null;

  build() {
    Column() {
      Row() {
        Text(this.monthStats ? `${this.monthStats.year}年${this.monthStats.month}月` : '本月')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(`${this.monthStats?.rides || 0} 次骑行`)
          .fontSize(12)
          .fontColor('#1890FF')
      }
      .width('100%')

      Row() {
        this.buildStatItem('距离', `${((this.monthStats?.distance || 0) / 1000).toFixed(1)}`, 'km')
        this.buildStatItem('时长', this.formatDuration(this.monthStats?.duration || 0), '')
        this.buildStatItem('热量', `${this.monthStats?.calories || 0}`, 'kcal')
        this.buildStatItem('均速', `${(this.monthStats?.avgSpeed || 0).toFixed(1)}`, 'km/h')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 12 })
  }

  @Builder
  buildStatItem(label: string, value: string, unit: string) {
    Column() {
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

      Text(label)
        .fontSize(10)
        .fontColor('#99182431')
        .margin({ top: 2 })
    }
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) {
      return `${hours}h${minutes}m`;
    }
    return `${minutes}m`;
  }
}

/**
 * 个人记录卡片
 */
@Component
export struct PersonalRecordCard {
  @Prop recordType: string = '';
  @Prop value: string = '';
  @Prop date: string = '';
  @Prop icon: string = '🏆';

  build() {
    Row() {
      Text(this.icon)
        .fontSize(24)

      Column() {
        Text(this.recordType)
          .fontSize(12)
          .fontColor('#99182431')

        Text(this.value)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
          .margin({ top: 2 })

        if (this.date) {
          Text(this.date)
            .fontSize(10)
            .fontColor('#BFBFBF')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}

/**
 * 时间范围选择器
 */
@Component
export struct TimeRangeSelector {
  @Prop selectedRange: string = 'this_month';
  onSelect?: (range: string) => void;

  private ranges = [
    { key: 'this_week', label: '本周' },
    { key: 'this_month', label: '本月' },
    { key: 'this_year', label: '今年' },
    { key: 'all_time', label: '全部' }
  ];

  build() {
    Row() {
      ForEach(this.ranges, (range: { key: string; label: string }) => {
        Text(range.label)
          .fontSize(14)
          .fontColor(this.selectedRange === range.key ? '#1890FF' : '#182431')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.selectedRange === range.key ? '#E6F7FF' : '#F5F5F5')
          .borderRadius(16)
          .margin({ left: this.ranges.indexOf(range) > 0 ? 8 : 0 })
          .onClick(() => {
            this.onSelect?.(range.key);
          })
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding(16)
  }
}

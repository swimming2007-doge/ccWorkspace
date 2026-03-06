/**
 * 统计分析页面 - F019
 *
 * 功能说明：
 * - 骑行数据统计展示
 * - 趋势图表
 * - 心率区间分布
 * - 个人记录
 *
 * 依赖组件：
 * - StatsService: 统计服务
 * - StatsComponents: 统计组件
 */

import router from '@ohos.router';
import hilog from '@ohos.hilog';
import StatsService, { TimeRange, StatsData, TrendData, MonthlyStats } from '../services/StatsService';
import {
  StatsSummaryCard,
  HeartRateZoneChart,
  TrendChart,
  MonthlyStatsCard,
  PersonalRecordCard,
  TimeRangeSelector
} from '../components/StatsComponents';

const TAG = '[StatsPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct StatsPage {
  // 时间范围
  @State selectedRange: string = 'this_month';

  // 统计数据
  @State stats: StatsData | null = null;
  @State trendData: TrendData | null = null;
  @State monthlyStats: MonthlyStats[] = [];

  // 个人记录
  @State longestDistance: string = '--';
  @State longestDistanceDate: string = '';
  @State fastestSpeed: string = '--';
  @State fastestSpeedDate: string = '';
  @State longestDuration: string = '--';
  @State longestDurationDate: string = '';

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'StatsPage appearing');
    this.loadData();
  }

  private async loadData(): Promise<void> {
    const timeRange = this.selectedRange as TimeRange;

    // 加载统计
    this.stats = await StatsService.getStats(timeRange);

    // 加载趋势
    this.trendData = await StatsService.getTrends(timeRange);

    // 加载月度统计
    this.monthlyStats = await StatsService.getMonthlyStats(6);

    // 加载个人记录
    const records = await StatsService.getPersonalRecords();

    if (records.longestRide) {
      this.longestDistance = `${(records.longestRide.distance / 1000).toFixed(1)} km`;
      this.longestDistanceDate = this.formatDate(records.longestRide.start_time);
    }

    if (records.fastestRide) {
      this.fastestSpeed = `${records.fastestRide.avg_speed.toFixed(1)} km/h`;
      this.fastestSpeedDate = this.formatDate(records.fastestRide.start_time);
    }

    if (records.longestDuration) {
      this.longestDuration = this.formatDuration(records.longestDuration.duration);
      this.longestDurationDate = this.formatDate(records.longestDuration.start_time);
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      this.buildHeader()

      // 时间范围选择
      TimeRangeSelector({
        selectedRange: this.selectedRange,
        onSelect: (range: string) => {
          this.selectedRange = range;
          this.loadData();
        }
      })

      // 内容区域
      Scroll() {
        Column() {
          // 统计摘要
          if (this.stats) {
            StatsSummaryCard({
              title: this.getRangeTitle(),
              stats: this.stats
            })
          }

          // 趋势图表
          if (this.trendData && this.trendData.distance.length > 0) {
            TrendChart({
              title: '距离趋势',
              data: this.trendData.distance,
              unit: 'km',
              color: '#1890FF'
            })
          }

          // 心率区间
          if (this.stats && this.stats.hrZoneDistribution.zone1 + this.stats.hrZoneDistribution.zone2 + this.stats.hrZoneDistribution.zone3 + this.stats.hrZoneDistribution.zone4 + this.stats.hrZoneDistribution.zone5 > 0) {
            HeartRateZoneChart({
              distribution: this.stats.hrZoneDistribution
            })
          }

          // 月度统计
          if (this.monthlyStats.length > 0) {
            this.buildMonthlyStats()
          }

          // 个人记录
          this.buildPersonalRecords()

          // 底部间距
          Column()
            .height(32)
        }
        .padding({ left: 16, right: 16 })
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

      Text('统计分析')
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

  @Builder
  buildMonthlyStats() {
    Column() {
      Text('月度统计')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      Scroll() {
        Row() {
          ForEach(this.monthlyStats, (stat: MonthlyStats) => {
            Column() {
              Text(`${stat.month}月`)
                .fontSize(12)
                .fontColor('#99182431')

              Text(`${(stat.distance / 1000).toFixed(0)}`)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#182431')
                .margin({ top: 4 })

              Text('km')
                .fontSize(10)
                .fontColor('#99182431')
            }
            .width(60)
            .padding(12)
            .backgroundColor('#F7F8FA')
            .borderRadius(8)
            .margin({ left: this.monthlyStats.indexOf(stat) > 0 ? 8 : 0 })
            .alignItems(HorizontalAlign.Center)
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 12 })
  }

  @Builder
  buildPersonalRecords() {
    Column() {
      Text('个人记录')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      Row() {
        PersonalRecordCard({
          recordType: '最长距离',
          value: this.longestDistance,
          date: this.longestDistanceDate,
          icon: '🏃'
        })
          .layoutWeight(1)

        PersonalRecordCard({
          recordType: '最快速度',
          value: this.fastestSpeed,
          date: this.fastestSpeedDate,
          icon: '⚡'
        })
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 12 })

      Row() {
        PersonalRecordCard({
          recordType: '最长时间',
          value: this.longestDuration,
          date: this.longestDurationDate,
          icon: '⏱️'
        })
          .layoutWeight(1)

        PersonalRecordCard({
          recordType: '总骑行',
          value: `${this.stats?.totalRides || 0}`,
          date: '次',
          icon: '🚴'
        })
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 12 })
  }

  private getRangeTitle(): string {
    switch (this.selectedRange) {
      case 'this_week':
        return '本周统计';
      case 'this_month':
        return '本月统计';
      case 'this_year':
        return '今年统计';
      case 'all_time':
        return '全部统计';
      default:
        return '统计';
    }
  }

  private formatDate(dateStr: string): string {
    const date = new Date(dateStr);
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}分钟`;
  }
}

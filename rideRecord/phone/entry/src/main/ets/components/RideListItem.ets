/**
 * 骑行记录列表项组件
 *
 * 功能说明：
 * - 显示单条骑行记录摘要
 * - 日期、距离、时间、速度
 * - 心率和海拔概览
 * - 点击跳转详情
 */
import { RideRecordEntity } from '../services/RideStorageService';

/**
 * 骑行记录列表项组件
 */
@Component
export struct RideListItem {
  // 骑行记录数据
  @Prop ride: RideRecordEntity | null = null;
  // 点击回调
  onItemClick?: (rideId: string) => void;

  build() {
    if (!this.ride) {
      this.buildEmptyItem();
      return;
    }

    Row() {
      // 左侧日期
      this.buildDateSection()

      // 中间数据
      Column() {
        // 标题/日期
        Text(this.getDisplayTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 数据行
        Row() {
          // 距离
          this.buildDataItem('距离', this.formatDistance(this.ride.distance), 'km')

          // 时间
          this.buildDataItem('时间', this.formatDuration(this.ride.duration), '')

          // 平均速度
          this.buildDataItem('均速', this.ride.avg_speed.toFixed(1), 'km/h')
        }
        .width('100%')
        .margin({ top: 8 })

        // 心率和海拔
        Row() {
          if (this.ride.avg_heart_rate) {
            Row() {
              Text('❤')
                .fontSize(12)
              Text(`${this.ride.avg_heart_rate}`)
                .fontSize(12)
                .fontColor('#F5222D')
                .margin({ left: 2 })
              Text('bpm')
                .fontSize(10)
                .fontColor('#99182431')
                .margin({ left: 2 })
            }
            .margin({ right: 16 })
          }

          if (this.ride.elevation_gain > 0) {
            Row() {
              Text('↑')
                .fontSize(12)
                .fontColor('#52C41A')
              Text(`${Math.round(this.ride.elevation_gain)}m`)
                .fontSize(12)
                .margin({ left: 2 })
            }
            .margin({ right: 16 })
          }

          Blank()

          Text(this.formatDate(this.ride.start_time))
            .fontSize(10)
            .fontColor('#99182431')
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16 })

      // 右侧箭头
      Text('›')
        .fontSize(20)
        .fontColor('#D9D9D9')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(() => {
      if (this.ride && this.onItemClick) {
        this.onItemClick(this.ride.id);
      }
    })
  }

  @Builder
  buildEmptyItem() {
    Row() {
      Column() {
        Text('暂无骑行记录')
          .fontSize(14)
          .fontColor('#99182431')
      }
      .width('100%')
      .height(80)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  buildDateSection() {
    Column() {
      // 日期
      Text(this.getDay())
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1890FF')

      // 月份
      Text(this.getMonth())
        .fontSize(12)
        .fontColor('#99182431')
    }
    .width(50)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildDataItem(label: string, value: string, unit: string) {
    Column() {
      Text(label)
        .fontSize(10)
        .fontColor('#80182431')

      Row() {
        Text(value)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)

        if (unit) {
          Text(unit)
            .fontSize(10)
            .fontColor('#99182431')
            .margin({ left: 2 })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  private getDisplayTitle(): string {
    if (this.ride?.title) {
      return this.ride.title;
    }
    // 使用日期作为标题
    const date = new Date(this.ride!.start_time);
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${date.getMonth() + 1}月${date.getDate()}日 ${weekdays[date.getDay()]}`;
  }

  private getDay(): string {
    if (!this.ride) return '--';
    const date = new Date(this.ride.start_time);
    return date.getDate().toString().padStart(2, '0');
  }

  private getMonth(): string {
    if (!this.ride) return '--';
    const date = new Date(this.ride.start_time);
    return `${date.getMonth() + 1}月`;
  }

  private formatDistance(distance: number): string {
    if (distance >= 1000) {
      return (distance / 1000).toFixed(2);
    }
    return distance.toFixed(0);
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return `${hours}h${minutes}m`;
    }
    return `${minutes}分钟`;
  }

  private formatDate(dateStr: string): string {
    const date = new Date(dateStr);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days === 0) {
      return '今天';
    } else if (days === 1) {
      return '昨天';
    } else if (days < 7) {
      return `${days}天前`;
    } else {
      return `${date.getMonth() + 1}/${date.getDate()}`;
    }
  }
}

/**
 * 骑行统计摘要卡片
 */
@Component
export struct RideStatsCard {
  @Prop totalRides: number = 0;
  @Prop totalDistance: number = 0;
  @Prop totalDuration: number = 0;
  @Prop avgSpeed: number = 0;

  build() {
    Column() {
      Text('骑行统计')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      Row() {
        this.buildStatItem('总骑行', `${this.totalRides}`, '次')
        this.buildStatItem('总里程', `${(this.totalDistance / 1000).toFixed(1)}`, 'km')
        this.buildStatItem('总时长', this.formatTotalDuration(), '')
        this.buildStatItem('平均速度', `${this.avgSpeed.toFixed(1)}`, 'km/h')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  buildStatItem(label: string, value: string, unit: string) {
    Column() {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1890FF')

      Row() {
        Text(label)
          .fontSize(10)
          .fontColor('#99182431')

        if (unit) {
          Text(unit)
            .fontSize(10)
            .fontColor('#99182431')
            .margin({ left: 2 })
        }
      }
      .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
  }

  private formatTotalDuration(): string {
    const hours = Math.floor(this.totalDuration / 3600);
    if (hours >= 24) {
      const days = Math.floor(hours / 24);
      return `${days}天`;
    }
    return `${hours}h`;
  }
}

/**
 * 筛选标签组件
 */
@Component
export struct FilterChip {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onToggle?: () => void;

  build() {
    Text(this.label)
      .fontSize(12)
      .fontColor(this.selected ? '#1890FF' : '#182431')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.selected ? '#E6F7FF' : '#F5F5F5')
      .borderRadius(16)
      .onClick(() => {
        if (this.onToggle) {
          this.onToggle();
        }
      })
  }
}

/**
 * 空状态组件
 */
@Component
export struct EmptyRidesState {
  onStartRide?: () => void;

  build() {
    Column() {
      Text('🚴')
        .fontSize(48)
        .margin({ bottom: 16 })

      Text('还没有骑行记录')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#182431')

      Text('开始你的第一次骑行吧！')
        .fontSize(14)
        .fontColor('#99182431')
        .margin({ top: 8 })

      Button('开始骑行')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor('#1890FF')
        .borderRadius(24)
        .padding({ left: 32, right: 32, top: 12, bottom: 12 })
        .margin({ top: 24 })
        .onClick(() => {
          if (this.onStartRide) {
            this.onStartRide();
          }
        })
    }
    .width('100%')
    .padding(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

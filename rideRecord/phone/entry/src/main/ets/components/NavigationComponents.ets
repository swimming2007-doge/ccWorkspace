/**
 * 导航界面组件
 *
 * 功能说明：
 * - 转向提示卡片
 * - 导航信息面板
 * - 路线概览卡片
 * - 导航控制按钮
 */
import { Maneuver, NavigationRoute, NavigationStatus, NavigationState, ManeuverType } from '../services/NavigationService';

/**
 * 转向提示卡片
 */
@Component
export struct ManeuverCard {
  @Prop maneuver: Maneuver | null = null;
  @Prop distanceToManeuver: number = 0;

  private get maneuverIcon(): string {
    if (!this.maneuver) return '⬆️';

    const icons: Record<ManeuverType, string> = {
      [ManeuverType.TURN_LEFT]: '⬅️',
      [ManeuverType.TURN_RIGHT]: '➡️',
      [ManeuverType.TURN_SLIGHT_LEFT]: '↖️',
      [ManeuverType.TURN_SLIGHT_RIGHT]: '↗️',
      [ManeuverType.TURN_SHARP_LEFT]: '⬅️',
      [ManeuverType.TURN_SHARP_RIGHT]: '➡️',
      [ManeuverType.STRAIGHT]: '⬆️',
      [ManeuverType.U_TURN]: '🔄',
      [ManeuverType.MERGE_LEFT]: '↖️',
      [ManeuverType.MERGE_RIGHT]: '↗️',
      [ManeuverType.ROUNDABOUT]: '🔃',
      [ManeuverType.EXIT]: '🚪',
      [ManeuverType.ARRIVE]: '🏁',
      [ManeuverType.DEPART]: '🚴'
    };

    return icons[this.maneuver.type] || '⬆️';
  }

  private get distanceText(): string {
    if (this.distanceToManeuver >= 1000) {
      return `${(this.distanceToManeuver / 1000).toFixed(1)}公里`;
    }
    return `${Math.round(this.distanceToManeuver)}米`;
  }

  build() {
    Row() {
      // 转向图标
      Text(this.maneuverIcon)
        .fontSize(40)

      // 转向信息
      Column() {
        Text(this.distanceText)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')

        Text(this.maneuver?.instruction || '继续直行')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .opacity(0.9)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 16 })
      .layoutWeight(1)

      // 道路名称
      if (this.maneuver?.roadName) {
        Text(this.maneuver.roadName)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .opacity(0.8)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .linearGradient({
      angle: 90,
      colors: [
        ['#1890FF', 0],
        ['#096DD9', 1]
      ]
    })
  }
}

/**
 * 导航信息面板
 */
@Component
export struct NavigationInfoPanel {
  @Prop remainingDistance: number = 0;
  @Prop remainingDuration: number = 0;
  @Prop estimatedArrival: Date = new Date();
  @Prop currentSpeed: number = 0;

  build() {
    Row() {
      // 剩余距离
      Column() {
        Text(this.formatDistance(this.remainingDistance))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')

        Text('剩余距离')
          .fontSize(10)
          .fontColor('#99182431')
          .margin({ top: 2 })
      }
      .layoutWeight(1)

      // 分隔线
      Divider()
        .vertical(true)
        .height(40)
        .color('#E8E8E8')

      // 剩余时间
      Column() {
        Text(this.formatDuration(this.remainingDuration))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')

        Text('预计到达')
          .fontSize(10)
          .fontColor('#99182431')
          .margin({ top: 2 })
      }
      .layoutWeight(1)

      // 分隔线
      Divider()
        .vertical(true)
        .height(40)
        .color('#E8E8E8')

      // 当前速度
      Column() {
        Text(`${this.currentSpeed.toFixed(0)}`)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1890FF')

        Text('km/h')
          .fontSize(10)
          .fontColor('#99182431')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 16, topRight: 16 })
    .shadow({
      radius: 8,
      color: '#1A000000',
      offsetX: 0,
      offsetY: -2
    })
  }

  private formatDistance(distance: number): string {
    if (distance >= 1000) {
      return `${(distance / 1000).toFixed(1)}km`;
    }
    return `${Math.round(distance)}m`;
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return `${hours}h${minutes}m`;
    }
    return `${minutes}分钟`;
  }
}

/**
 * 路线概览卡片
 */
@Component
export struct RouteOverviewCard {
  @Prop route: NavigationRoute | null = null;

  build() {
    Column() {
      // 路线名称
      Row() {
        Text('路线信息')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.getModeText())
          .fontSize(12)
          .fontColor('#1890FF')
          .backgroundColor('#E6F7FF')
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .width('100%')

      // 路线统计
      Row() {
        this.buildStatItem('总距离', `${((this.route?.distance || 0) / 1000).toFixed(1)}`, 'km')
        this.buildStatItem('预计时间', this.formatDuration(this.route?.duration || 0), '')
        this.buildStatItem('爬升', `${Math.round(this.route?.elevationGain || 0)}`, 'm')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 16 })

      // 起点/终点
      Row() {
        Column() {
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill('#52C41A')
            Text('起点')
              .fontSize(12)
              .margin({ left: 8 })
          }

          Text(this.formatCoordinate(this.route?.startPoint))
            .fontSize(10)
            .fontColor('#99182431')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column() {
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill('#F5222D')
            Text('终点')
              .fontSize(12)
              .margin({ left: 8 })
          }

          Text(this.formatCoordinate(this.route?.endPoint))
            .fontSize(10)
            .fontColor('#99182431')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
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

  private getModeText(): string {
    switch (this.route?.mode) {
      case 'road':
        return '公路模式';
      case 'adventure':
        return '探险模式';
      case 'hybrid':
        return '混合模式';
      default:
        return '未知';
    }
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return `${hours}小时${minutes}分`;
    }
    return `${minutes}分钟`;
  }

  private formatCoordinate(point?: { latitude: number; longitude: number }): string {
    if (!point) return '--';
    return `${point.latitude.toFixed(4)}, ${point.longitude.toFixed(4)}`;
  }
}

/**
 * 导航控制按钮
 */
@Component
export struct NavigationControls {
  @Prop isNavigating: boolean = false;
  @Prop isPaused: boolean = false;
  onStart?: () => void;
  onPause?: () => void;
  onResume?: () => void;
  onStop?: () => void;

  build() {
    Row() {
      if (!this.isNavigating) {
        // 开始导航按钮
        Button() {
          Row() {
            Text('🧭')
              .fontSize(20)
            Text('开始导航')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor('#1890FF')
        .borderRadius(24)
        .onClick(() => this.onStart?.())
      } else {
        // 暂停/继续按钮
        Button() {
          Text(this.isPaused ? '继续' : '暂停')
            .fontSize(14)
            .fontColor('#182431')
        }
        .width(80)
        .height(48)
        .backgroundColor('#F5F5F5')
        .borderRadius(24)
        .onClick(() => {
          if (this.isPaused) {
            this.onResume?.();
          } else {
            this.onPause?.();
          }
        })

        // 结束导航按钮
        Button() {
          Text('结束')
            .fontSize(14)
            .fontColor('#FFFFFF')
        }
        .width(80)
        .height(48)
        .backgroundColor('#F5222D')
        .borderRadius(24)
        .margin({ left: 16 })
        .onClick(() => this.onStop?.())
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding(16)
  }
}

/**
 * 偏离路线提示
 */
@Component
export struct OffRouteAlert {
  @Prop distance: number = 0;
  onReroute?: () => void;

  build() {
    Row() {
      Column() {
        Text('已偏离路线')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')

        Text(`距离路线 ${Math.round(this.distance)} 米`)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .opacity(0.9)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('重新规划')
        .fontSize(14)
        .fontColor('#FAAD14')
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .onClick(() => this.onReroute?.())
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FAAD14')
    .borderRadius(12)
  }
}

/**
 * 到达目的地提示
 */
@Component
export struct ArrivedCard {
  onComplete?: () => void;

  build() {
    Column() {
      Text('🎉')
        .fontSize(48)

      Text('已到达目的地')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#182431')
        .margin({ top: 16 })

      Button('完成')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor('#52C41A')
        .borderRadius(24)
        .padding({ left: 32, right: 32, top: 12, bottom: 12 })
        .margin({ top: 16 })
        .onClick(() => this.onComplete?.())
    }
    .width('100%')
    .padding(32)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Center)
  }
}

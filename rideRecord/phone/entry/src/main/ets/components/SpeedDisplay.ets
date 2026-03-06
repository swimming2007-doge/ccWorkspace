/**
 * 速度显示组件
 *
 * 功能说明：
 * - 当前速度大字显示
 * - 平均/最大速度对比
 * - 速度趋势指示
 */
@Component
export struct SpeedDisplay {
  // 当前速度 (km/h)
  @Prop currentSpeed: number = 0;
  // 平均速度 (km/h)
  @Prop avgSpeed: number = 0;
  // 最大速度 (km/h)
  @Prop maxSpeed: number = 0;
  // 显示单位
  @Prop showUnit: boolean = true;
  // 尺寸模式
  @Prop sizeMode: 'large' | 'medium' | 'compact' = 'large';

  private get displayValue(): string {
    return this.currentSpeed.toFixed(1);
  }

  private get fontSize(): number {
    switch (this.sizeMode) {
      case 'large':
        return 72;
      case 'medium':
        return 48;
      case 'compact':
        return 24;
      default:
        return 48;
    }
  }

  build() {
    Column() {
      // 当前速度
      Row() {
        Text(this.displayValue)
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')

        if (this.showUnit) {
          Text('km/h')
            .fontSize(this.sizeMode === 'large' ? 18 : 12)
            .fontColor('#99182431')
            .margin({ left: 4, bottom: this.sizeMode === 'large' ? 16 : 8 })
        }
      }
      .alignItems(VerticalAlign.Bottom)

      // 平均/最大速度
      if (this.sizeMode !== 'compact') {
        Row() {
          Column() {
            Text('平均')
              .fontSize(10)
              .fontColor('#80182431')
            Text(`${this.avgSpeed.toFixed(1)}`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
          }
          .margin({ right: 16 })

          Column() {
            Text('最高')
              .fontSize(10)
              .fontColor('#80182431')
            Text(`${this.maxSpeed.toFixed(1)}`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1890FF')
          }
        }
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(this.sizeMode === 'large' ? HorizontalAlign.Center : HorizontalAlign.Start)
  }
}

/**
 * 距离显示组件
 */
@Component
export struct DistanceDisplay {
  // 距离 (米)
  @Prop distance: number = 0;
  // 显示单位
  @Prop showUnit: boolean = true;

  private get displayValue(): string {
    return (this.distance / 1000).toFixed(2);
  }

  build() {
    Row() {
      Text(this.displayValue)
        .fontSize(24)
        .fontWeight(FontWeight.Medium)

      if (this.showUnit) {
        Text('km')
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ left: 4 })
      }
    }
  }
}

/**
 * 时间显示组件
 */
@Component
export struct TimeDisplay {
  // 时间 (秒)
  @Prop time: number = 0;
  // 显示模式
  @Prop mode: 'full' | 'compact' = 'full';
  // 标签
  @Prop label: string = '';

  private formatTime(): string {
    const hours = Math.floor(this.time / 3600);
    const minutes = Math.floor((this.time % 3600) / 60);
    const seconds = this.time % 60;

    if (this.mode === 'compact') {
      if (hours > 0) {
        return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
      }
      return `${minutes}:${seconds.toString().padStart(2, '0')}`;
    }

    if (hours > 0) {
      return `${hours}时${minutes}分${seconds}秒`;
    }
    return `${minutes}分${seconds}秒`;
  }

  private get shortFormat(): string {
    const hours = Math.floor(this.time / 3600);
    const minutes = Math.floor((this.time % 3600) / 60);
    const seconds = this.time % 60;

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      if (this.label) {
        Text(this.label)
          .fontSize(10)
          .fontColor('#80182431')
      }

      Text(this.shortFormat)
        .fontSize(this.mode === 'full' ? 24 : 18)
        .fontWeight(FontWeight.Medium)
    }
  }
}

/**
 * 海拔显示组件
 */
@Component
export struct ElevationDisplay {
  // 当前海拔 (米)
  @Prop elevation: number = 0;
  // 累计爬升 (米)
  @Prop elevationGain: number = 0;
  // 累计下降 (米)
  @Prop elevationLoss: number = 0;
  // 坡度 (%)
  @Prop gradient: number = 0;

  private get gradientColor(): string {
    if (this.gradient > 8) {
      return '#F5222D'; // 红色 - 陡坡
    } else if (this.gradient > 4) {
      return '#FAAD14'; // 橙色 - 中等坡
    } else if (this.gradient > 0) {
      return '#52C41A'; // 绿色 - 轻微上坡
    } else if (this.gradient < -4) {
      return '#1890FF'; // 蓝色 - 下坡
    }
    return '#182431'; // 默认
  }

  private get gradientText(): string {
    const g = this.gradient.toFixed(1);
    if (this.gradient > 0) {
      return `+${g}%`;
    }
    return `${g}%`;
  }

  build() {
    Column() {
      // 当前海拔
      Row() {
        Text(`${Math.round(this.elevation)}`)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
        Text('m')
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ left: 2 })
      }

      // 坡度指示
      Row() {
        Text(this.gradientText)
          .fontSize(14)
          .fontColor(this.gradientColor)
          .fontWeight(FontWeight.Medium)
      }
      .margin({ top: 4 })

      // 爬升/下降
      Row() {
        Column() {
          Text('↑')
            .fontSize(10)
            .fontColor('#52C41A')
          Text(`${Math.round(this.elevationGain)}m`)
            .fontSize(10)
            .fontColor('#80182431')
        }
        .margin({ right: 12 })

        Column() {
          Text('↓')
            .fontSize(10)
            .fontColor('#1890FF')
          Text(`${Math.round(this.elevationLoss)}m`)
            .fontSize(10)
            .fontColor('#80182431')
        }
      }
      .margin({ top: 8 })
    }
  }
}

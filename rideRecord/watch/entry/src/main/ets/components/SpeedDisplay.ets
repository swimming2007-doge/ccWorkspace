/**
 * 速度显示组件
 *
 * 功能说明：
 * - 大字体显示当前速度
 * - 支持速度单位切换 (km/h, mph)
 * - 显示平均速度和最大速度
 */
@Component
export struct SpeedDisplay {
  @Prop speed: number = 0;
  @Prop unit: string = 'km/h';
  @Prop fontSize: number = 48;

  build() {
    Row() {
      // 速度值
      Text(this.speed.toFixed(1))
        .fontSize(this.fontSize)
        .fontWeight(FontWeight.Bold)
        .fontColor('#182431')

      // 单位
      Text(this.unit)
        .fontSize(12)
        .fontColor('#99182431')
        .margin({ left: 4, bottom: 8 })
    }
    .alignItems(VerticalAlign.Bottom)
  }
}

/**
 * 速度范围指示器
 * 显示当前速度在速度范围内的位置
 */
@Component
export struct SpeedRangeIndicator {
  @Prop currentSpeed: number = 0;
  @Prop maxSpeed: number = 60; // 最大显示速度

  build() {
    Column() {
      // 速度条
      Row() {
        ForEach([0, 1, 2, 3, 4], (_: number, index: number) => {
          Column()
            .layoutWeight(1)
            .height(4)
            .backgroundColor(this.currentSpeed > (index * 12) ? '#007DFF' : '#E0E0E0')
            .borderRadius(2)
            .margin({ left: index > 0 ? 2 : 0 })
        })
      }
      .width('100%')

      // 速度刻度
      Row() {
        Text('0')
          .fontSize(8)
          .fontColor('#99182431')
        Blank()
        Text(`${this.maxSpeed}`)
          .fontSize(8)
          .fontColor('#99182431')
      }
      .width('100%')
      .margin({ top: 2 })
    }
  }
}

/**
 * 距离显示组件
 */
@Component
export struct DistanceDisplay {
  @Prop distance: number = 0; // 单位：米
  @Prop showUnit: boolean = true;

  private formatDistance(): string {
    if (this.distance >= 1000) {
      return (this.distance / 1000).toFixed(2);
    }
    return this.distance.toString();
  }

  private getUnit(): string {
    if (this.distance >= 1000) {
      return 'km';
    }
    return 'm';
  }

  build() {
    Row() {
      Text(this.formatDistance())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#182431')

      if (this.showUnit) {
        Text(this.getUnit())
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ left: 4, bottom: 4 })
      }
    }
    .alignItems(VerticalAlign.Bottom)
  }
}

/**
 * 海拔显示组件
 */
@Component
export struct ElevationDisplay {
  @Prop elevation: number = 0; // 单位：米
  @Prop elevationGain: number = 0; // 爬升

  build() {
    Column() {
      // 当前海拔
      Row() {
        Text('↑')
          .fontSize(12)
          .fontColor('#4CAF50')
        Text(`${Math.round(this.elevation)}`)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        Text('m')
          .fontSize(10)
          .fontColor('#99182431')
      }

      // 累计爬升
      if (this.elevationGain > 0) {
        Text(`+${Math.round(this.elevationGain)}m`)
          .fontSize(10)
          .fontColor('#4CAF50')
      }
    }
  }
}

/**
 * 圆弧按钮组件
 * 手表特有的圆弧按钮交互
 */
@Component
export struct ArcButton {
  @Prop label: string = '';
  @Prop icon: string = '';
  @Prop isActive: boolean = false;
  @Prop size: number = 60;
  private onClick?: () => void;

  build() {
    Column() {
      if (this.icon) {
        Text(this.icon)
          .fontSize(24)
          .fontColor(this.isActive ? '#FFFFFF' : '#182431')
      }

      if (this.label) {
        Text(this.label)
          .fontSize(12)
          .fontColor(this.isActive ? '#FFFFFF' : '#182431')
          .margin({ top: 4 })
      }
    }
    .width(this.size)
    .height(this.size)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isActive ? '#007DFF' : '#F5F5F5')
    .borderRadius(this.size / 2)
    .onClick(() => {
      if (this.onClick) {
        this.onClick();
      }
    })
  }

  // 设置点击回调
  setOnClick(callback: () => void): ArcButton {
    this.onClick = callback;
    return this;
  }
}

/**
 * 导出所有组件
 */
export { ArcButton };

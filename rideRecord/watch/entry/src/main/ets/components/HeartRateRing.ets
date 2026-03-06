/**
 * 心率环形组件
 *
 * 功能说明：
 * - 圆形进度环显示心率
 * - 根据心率区间显示不同颜色
 * - 支持动画效果
 */
@Component
export struct HeartRateRing {
  @Prop heartRate: number = 0;
  @Prop maxHeartRate: number = 200;
  @Prop size: number = 100;
  @Prop strokeWidth: number = 8;

  // 心率区间颜色
  private getZoneColor(): string {
    const percentage = (this.heartRate / this.maxHeartRate) * 100;

    if (percentage < 60) {
      return '#90CAF9'; // Z1 恢复区 - 浅蓝
    } else if (percentage < 70) {
      return '#4CAF50'; // Z2 有氧区 - 绿色
    } else if (percentage < 80) {
      return '#FFEB3B'; // Z3 强化区 - 黄色
    } else if (percentage < 90) {
      return '#FF9800'; // Z4 阈值区 - 橙色
    } else {
      return '#F44336'; // Z5 极限区 - 红色
    }
  }

  // 心率区间名称
  private getZoneName(): string {
    const percentage = (this.heartRate / this.maxHeartRate) * 100;

    if (percentage < 60) return 'Z1';
    if (percentage < 70) return 'Z2';
    if (percentage < 80) return 'Z3';
    if (percentage < 90) return 'Z4';
    return 'Z5';
  }

  build() {
    Stack() {
      // 背景环
      Circle()
        .width(this.size)
        .height(this.size)
        .fill(Color.Transparent)
        .stroke('#E0E0E0')
        .strokeWidth(this.strokeWidth)

      // 进度环
      Progress({
        value: this.heartRate,
        total: this.maxHeartRate,
        type: ProgressType.Ring
      })
        .width(this.size)
        .height(this.size)
        .color(this.getZoneColor())
        .style({ strokeWidth: this.strokeWidth })

      // 中心内容
      Column() {
        // 心率值
        Text(`${this.heartRate}`)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')

        // 单位
        Text('BPM')
          .fontSize(10)
          .fontColor('#99182431')

        // 区间指示
        Text(this.getZoneName())
          .fontSize(12)
          .fontColor(this.getZoneColor())
          .fontWeight(FontWeight.Medium)
          .margin({ top: 2 })
      }
    }
  }
}

/**
 * 迷你心率显示
 * 用于小空间显示
 */
@Component
export struct MiniHeartRate {
  @Prop heartRate: number = 0;
  @Prop showIcon: boolean = true;

  private getHeartColor(): string {
    if (this.heartRate < 100) return '#4CAF50';
    if (this.heartRate < 140) return '#FF9800';
    return '#F44336';
  }

  build() {
    Row() {
      // 心形图标
      Text('❤')
        .fontSize(14)
        .fontColor(this.getHeartColor())

      // 心率值
      Text(`${this.heartRate}`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#182431')
        .margin({ left: 4 })

      Text('bpm')
        .fontSize(10)
        .fontColor('#99182431')
        .margin({ left: 2 })
    }
  }
}

/**
 * 心率区间条
 * 显示当前心率在哪个区间
 */
@Component
export struct HeartRateZoneBar {
  @Prop heartRate: number = 0;
  @Prop maxHeartRate: number = 200;

  private zones = [
    { name: 'Z1', min: 0, max: 60, color: '#90CAF9' },
    { name: 'Z2', min: 60, max: 70, color: '#4CAF50' },
    { name: 'Z3', min: 70, max: 80, color: '#FFEB3B' },
    { name: 'Z4', min: 80, max: 90, color: '#FF9800' },
    { name: 'Z5', min: 90, max: 100, color: '#F44336' }
  ];

  private getCurrentZone(): number {
    const percentage = (this.heartRate / this.maxHeartRate) * 100;
    if (percentage < 60) return 0;
    if (percentage < 70) return 1;
    if (percentage < 80) return 2;
    if (percentage < 90) return 3;
    return 4;
  }

  build() {
    Row() {
      ForEach(this.zones, (zone: { name: string; min: number; max: number; color: string }, index: number) => {
        Column() {
          Text(zone.name)
            .fontSize(8)
            .fontColor(this.getCurrentZone() === index ? zone.color : '#99182431')
        }
        .layoutWeight(1)
        .height(20)
        .backgroundColor(this.getCurrentZone() >= index ? zone.color : '#E0E0E0')
        .justifyContent(FlexAlign.Center)
        .borderRadius(2)
        .margin({ left: index > 0 ? 2 : 0 })
      })
    }
    .width('100%')
    .height(20)
  }
}

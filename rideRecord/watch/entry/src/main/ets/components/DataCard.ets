/**
 * 数据卡片组件
 *
 * 功能说明：
 * - 显示单个数据项（速度、距离、时间等）
 * - 支持标题、数值、单位显示
 * - 支持不同尺寸和样式
 */
@Component
export struct DataCard {
  @Prop title: string = '';
  @Prop value: string = '0';
  @Prop unit: string = '';
  @Prop icon?: Resource = undefined;
  @Prop fontSize: number = 28;
  @Prop titleSize: number = 12;
  @Prop cardColor: string = '#FFFFFF';
  @Prop textColor: string = '#182431';

  build() {
    Column() {
      // 标题
      if (this.title) {
        Text(this.title)
          .fontSize(this.titleSize)
          .fontColor('#99182431')
          .margin({ bottom: 4 })
      }

      // 数值
      Row() {
        if (this.icon) {
          Image(this.icon)
            .width(16)
            .height(16)
            .margin({ right: 4 })
        }

        Text(this.value)
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)

        if (this.unit) {
          Text(this.unit)
            .fontSize(this.titleSize)
            .fontColor('#99182431')
            .margin({ left: 2, top: 8 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(8)
    .backgroundColor(this.cardColor)
    .borderRadius(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * 紧凑数据卡片
 * 用于小空间显示
 */
@Component
export struct CompactDataCard {
  @Prop title: string = '';
  @Prop value: string = '0';
  @Prop unit: string = '';

  build() {
    Column() {
      Text(this.title)
        .fontSize(10)
        .fontColor('#99182431')

      Row() {
        Text(this.value)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')

        if (this.unit) {
          Text(this.unit)
            .fontSize(10)
            .fontColor('#99182431')
            .margin({ left: 2 })
        }
      }
    }
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor('#F5F5F5')
    .borderRadius(8)
  }
}

/**
 * 状态指示器
 * 显示骑行状态
 */
@Component
export struct StatusIndicator {
  @Prop status: string = 'IDLE';
  @Prop isActive: boolean = false;

  private getStatusColor(): string {
    switch (this.status) {
      case 'RIDING':
        return '#4CAF50'; // 绿色
      case 'PAUSED':
        return '#FF9800'; // 橙色
      case 'ENDING':
        return '#F44336'; // 红色
      default:
        return '#9E9E9E'; // 灰色
    }
  }

  private getStatusText(): string {
    switch (this.status) {
      case 'RIDING':
        return '骑行中';
      case 'PAUSED':
        return '已暂停';
      case 'ENDING':
        return '结束确认';
      default:
        return '空闲'
    }
  }

  build() {
    Row() {
      // 状态点
      Circle()
        .width(8)
        .height(8)
        .fill(this.getStatusColor())
        .margin({ right: 6 })

      Text(this.getStatusText())
        .fontSize(14)
        .fontColor(this.getStatusColor())
        .fontWeight(FontWeight.Medium)
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor(Color.White)
    .borderRadius(16)
  }
}

/**
 * 计时器显示组件
 */
@Component
export struct TimerDisplay {
  @Prop seconds: number = 0;

  private formatTime(): string {
    const hours = Math.floor(this.seconds / 3600);
    const minutes = Math.floor((this.seconds % 3600) / 60);
    const secs = this.seconds % 60;

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  }

  build() {
    Text(this.formatTime())
      .fontSize(32)
      .fontWeight(FontWeight.Bold)
      .fontColor('#182431')
      .fontFamily('monospace')
  }
}

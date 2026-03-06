/**
 * 数据卡片组件
 *
 * 功能说明：
 * - 展示单个数据指标
 * - 支持标题、数值、单位显示
 * - 支持图标和状态颜色
 */
@Component
export struct DataCard {
  // 标题
  @Prop title: string = '';
  // 数值
  @Prop value: string = '--';
  // 单位
  @Prop unit: string = '';
  // 图标
  @Prop icon: string = '';
  // 主题色
  @Prop themeColor: string = '#182431';
  // 是否高亮
  @Prop highlight: boolean = false;

  build() {
    Column() {
      // 标题行
      Row() {
        if (this.icon) {
          Text(this.icon)
            .fontSize(14)
            .margin({ right: 4 })
        }
        Text(this.title)
          .fontSize(12)
          .fontColor('#99182431')
      }
      .width('100%')

      // 数值
      Text(this.value)
        .fontSize(this.highlight ? 32 : 24)
        .fontWeight(this.highlight ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.themeColor)
        .margin({ top: 4 })

      // 单位
      if (this.unit) {
        Text(this.unit)
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.highlight ? '#F0F7FF' : '#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: this.highlight ? '#1A1890FF' : '#0A000000',
      offsetX: 0,
      offsetY: 2
    })
  }
}

/**
 * 大型数据卡片 (用于主指标)
 */
@Component
export struct LargeDataCard {
  @Prop title: string = '';
  @Prop value: string = '--';
  @Prop unit: string = '';
  @Prop themeColor: string = '#1890FF';

  build() {
    Column() {
      Text(this.title)
        .fontSize(14)
        .fontColor('#99182431')

      Row() {
        Text(this.value)
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColor)

        if (this.unit) {
          Text(this.unit)
            .fontSize(16)
            .fontColor('#99182431')
            .margin({ left: 4, bottom: 8 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({
      radius: 12,
      color: '#1A1890FF',
      offsetX: 0,
      offsetY: 4
    })
  }
}

/**
 * 紧凑数据卡片 (用于多列布局)
 */
@Component
export struct CompactDataCard {
  @Prop title: string = '';
  @Prop value: string = '--';
  @Prop unit: string = '';
  @Prop themeColor: string = '#182431';

  build() {
    Column() {
      Text(this.title)
        .fontSize(10)
        .fontColor('#80182431')

      Row() {
        Text(this.value)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColor)

        if (this.unit) {
          Text(this.unit)
            .fontSize(10)
            .fontColor('#80182431')
            .margin({ left: 2 })
        }
      }
      .margin({ top: 2 })
    }
    .padding(12)
    .backgroundColor('#F7F8FA')
    .borderRadius(8)
  }
}

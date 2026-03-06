/**
 * 心率环组件
 *
 * 功能说明：
 * - 心率区间可视化
 * - 环形进度显示
 * - 实时心率显示
 * - 区间颜色编码
 */
import { HeartRateZone } from '../services/RideDataService';

// 心率区间颜色
const ZONE_COLORS: Record<HeartRateZone, string> = {
  [HeartRateZone.Z1_RECOVERY]: '#52C41A',    // 绿色 - 恢复区
  [HeartRateZone.Z2_AEROBIC]: '#1890FF',      // 蓝色 - 有氧区
  [HeartRateZone.Z3_TEMPO]: '#FAAD14',        // 橙色 - 强化区
  [HeartRateZone.Z4_THRESHOLD]: '#FF7A45',    // 深橙 - 阈值区
  [HeartRateZone.Z5_MAX]: '#F5222D'           // 红色 - 极限区
};

// 区间名称
const ZONE_NAMES: Record<HeartRateZone, string> = {
  [HeartRateZone.Z1_RECOVERY]: '恢复',
  [HeartRateZone.Z2_AEROBIC]: '有氧',
  [HeartRateZone.Z3_TEMPO]: '强化',
  [HeartRateZone.Z4_THRESHOLD]: '阈值',
  [HeartRateZone.Z5_MAX]: '极限'
};

@Component
export struct HeartRateRing {
  // 当前心率
  @Prop heartRate: number = 0;
  // 当前区间
  @Prop zone: HeartRateZone = HeartRateZone.Z1_RECOVERY;
  // 最大心率 (用于计算百分比)
  @Prop maxHeartRate: number = 185;
  // 环形尺寸
  @Prop size: number = 120;
  // 环形宽度
  @Prop strokeWidth: number = 12;

  private get zoneColor(): string {
    return ZONE_COLORS[this.zone] || '#1890FF';
  }

  private get zoneName(): string {
    return ZONE_NAMES[this.zone] || '--';
  }

  private get heartRatePercent(): number {
    if (this.maxHeartRate <= 0) return 0;
    const percent = (this.heartRate / this.maxHeartRate) * 100;
    return Math.min(100, Math.max(0, percent));
  }

  build() {
    Stack() {
      // 背景环
      Circle()
        .width(this.size)
        .height(this.size)
        .fill('transparent')
        .stroke('#E8E8E8')
        .strokeWidth(this.strokeWidth)

      // 进度环 (使用 Canvas 绘制)
      Canvas(this.createCanvasContext())
        .width(this.size)
        .height(this.size)
        .onReady(() => {
          this.drawProgressRing();
        })

      // 中心内容
      Column() {
        // 心率值
        Text(`${this.heartRate}`)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.zoneColor)

        // 单位
        Text('bpm')
          .fontSize(12)
          .fontColor('#99182431')

        // 区间名称
        Text(this.zoneName)
          .fontSize(10)
          .fontColor('#FFFFFF')
          .backgroundColor(this.zoneColor)
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ top: 4 })
      }
    }
    .width(this.size)
    .height(this.size)
  }

  private createCanvasContext(): CanvasRenderingContext2D {
    const settings: RenderingContextSettings = {
      antialias: true
    };
    return new CanvasRenderingContext2D(settings);
  }

  private drawProgressRing(): void {
    const context = this.createCanvasContext();
    const centerX = this.size / 2;
    const centerY = this.size / 2;
    const radius = (this.size - this.strokeWidth) / 2;

    // 绘制进度弧
    context.beginPath();
    context.arc(
      centerX,
      centerY,
      radius,
      -Math.PI / 2, // 从顶部开始
      -Math.PI / 2 + (2 * Math.PI * this.heartRatePercent / 100),
      false
    );
    context.strokeStyle = this.zoneColor;
    context.lineWidth = this.strokeWidth;
    context.lineCap = 'round';
    context.stroke();
  }
}

/**
 * 心率区间分布条
 */
@Component
export struct HeartRateZoneBar {
  // 区间时间分布 (百分比)
  @Prop zoneDistribution: Map<HeartRateZone, number> = new Map();

  build() {
    Column() {
      Text('心率区间分布')
        .fontSize(12)
        .fontColor('#99182431')
        .margin({ bottom: 8 })

      // 分布条
      Row() {
        ForEach([
          HeartRateZone.Z1_RECOVERY,
          HeartRateZone.Z2_AEROBIC,
          HeartRateZone.Z3_TEMPO,
          HeartRateZone.Z4_THRESHOLD,
          HeartRateZone.Z5_MAX
        ], (zone: HeartRateZone) => {
          const percent = this.zoneDistribution.get(zone) || 0;
          if (percent > 0) {
            Row()
              .width(`${percent}%`)
              .height(24)
              .backgroundColor(ZONE_COLORS[zone])
          }
        })
      }
      .width('100%')
      .height(24)
      .borderRadius(4)
      .clip(true)

      // 图例
      Row() {
        ForEach([
          { zone: HeartRateZone.Z1_RECOVERY, name: 'Z1' },
          { zone: HeartRateZone.Z2_AEROBIC, name: 'Z2' },
          { zone: HeartRateZone.Z3_TEMPO, name: 'Z3' },
          { zone: HeartRateZone.Z4_THRESHOLD, name: 'Z4' },
          { zone: HeartRateZone.Z5_MAX, name: 'Z5' }
        ], (item: { zone: HeartRateZone; name: string }) => {
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill(ZONE_COLORS[item.zone])
            Text(item.name)
              .fontSize(10)
              .fontColor('#99182431')
              .margin({ left: 2 })
          }
          .margin({ right: 8 })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}

/**
 * 紧凑心率显示
 */
@Component
export struct CompactHeartRate {
  @Prop heartRate: number = 0;
  @Prop zone: HeartRateZone = HeartRateZone.Z1_RECOVERY;

  private get zoneColor(): string {
    return ZONE_COLORS[this.zone] || '#1890FF';
  }

  build() {
    Row() {
      // 心形图标
      Text('❤')
        .fontSize(16)

      // 心率值
      Text(`${this.heartRate}`)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.zoneColor)
        .margin({ left: 4 })

      Text('bpm')
        .fontSize(10)
        .fontColor('#99182431')
        .margin({ left: 2 })
    }
    .padding(8)
    .backgroundColor('#FFF5F5F5')
    .borderRadius(8)
  }
}

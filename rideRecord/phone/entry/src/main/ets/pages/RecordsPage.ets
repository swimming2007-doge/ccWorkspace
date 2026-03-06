/**
 * 骑行记录列表页面
 *
 * 功能说明：
 * - 显示历史骑行记录
 * - 支持筛选和排序
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';

const TAG = '[RecordsPage]';
const DOMAIN = 0xFF00;

interface RecordItem {
  id: string;
  date: string;
  distance: number;
  duration: number;
  avgSpeed: number;
}

@Entry
@Component
struct RecordsPage {
  @State records: RecordItem[] = [];

  aboutToAppear() {
    // 加载模拟数据
    this.loadRecords();
  }

  private loadRecords(): void {
    this.records = [
      { id: '1', date: '2026-03-06', distance: 25000, duration: 3600, avgSpeed: 25.0 },
      { id: '2', date: '2026-03-05', distance: 18000, duration: 2700, avgSpeed: 24.0 },
      { id: '3', date: '2026-03-04', distance: 32000, duration: 4800, avgSpeed: 24.5 }
    ];
  }

  build() {
    Column() {
      // 标题
      Row() {
        Text('骑行记录')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding(16)

      // 记录列表
      List() {
        ForEach(this.records, (record: RecordItem) => {
          ListItem() {
            this.RecordCard(record)
          }
          .onClick(() => {
            router.pushUrl({ url: 'pages/RecordDetailPage', params: { id: record.id } });
          })
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  RecordCard(record: RecordItem) {
    Column() {
      Row() {
        Column() {
          Text(record.date)
            .fontSize(14)
            .fontColor('#99182431')

          Text(`${(record.distance / 1000).toFixed(1)} km`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column() {
          Text(`${Math.floor(record.duration / 60)} 分钟`)
            .fontSize(16)
          Text(`${record.avgSpeed.toFixed(1)} km/h`)
            .fontSize(14)
            .fontColor('#99182431')
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F5F5F5')
      .borderRadius(12)
    }
    .margin({ bottom: 8 })
  }
}

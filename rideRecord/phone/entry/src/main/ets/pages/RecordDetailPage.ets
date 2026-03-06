/**
 * 骑行详情页面 - F012
 *
 * 功能说明：
 * - 轨迹地图展示
 * - 速度/心率/海拔图表
 * - 分段数据展示
 * - 照片展示
 * - 导出和分享功能
 *
 * 依赖组件：
 * - RideStorageService: 数据存储
 * - ExportService: 数据导出
 * - MapTrackComponent: 地图轨迹
 * - RideDetailComponents: 详情数据组件
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import { RideRecordEntity, TrackPointEntity } from '../services/RideStorageService';
import RideStorageService from '../services/RideStorageService';
import ExportService, { ExportFormat, ExportResult } from '../services/ExportService';
import { MapTrackComponent } from '../components/MapTrackComponent';
import {
  RideDetailSummary,
  HeartRateZoneChart,
  RideDataChart,
  RideSegments,
  RideActionButtons
} from '../components/RideDetailComponents';
import { TrackPoint } from '../utils/Types';

const TAG = '[RecordDetailPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct RecordDetailPage {
  // 骑行记录ID
  @State rideId: string = '';
  // 骑行记录
  @State ride: RideRecordEntity | null = null;
  // 轨迹点
  @State trackPoints: TrackPointEntity[] = [];
  // 加载状态
  @State isLoading: boolean = true;
  // 导出状态
  @State isExporting: boolean = false;
  // 显示导出选项
  @State showExportOptions: boolean = false;

  aboutToAppear() {
    // 获取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params && params['id']) {
      this.rideId = params['id'] as string;
      hilog.info(DOMAIN, TAG, 'Loading ride detail: %{public}s', this.rideId);
      this.loadRideDetail();
    } else {
      hilog.error(DOMAIN, TAG, 'No ride ID provided');
      this.isLoading = false;
    }
  }

  /**
   * 加载骑行详情
   */
  private async loadRideDetail(): Promise<void> {
    this.isLoading = true;

    try {
      // 并行加载记录和轨迹点
      const [ride, trackPoints] = await Promise.all([
        RideStorageService.getRideById(this.rideId),
        RideStorageService.getTrackPoints(this.rideId)
      ]);

      this.ride = ride;
      this.trackPoints = trackPoints;

      hilog.info(DOMAIN, TAG, 'Ride loaded: %{public}s, track points: %{public}d',
        this.ride?.id || 'null', this.trackPoints.length);

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load ride: %{public}s', JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 导出为GPX
   */
  private async exportToGpx(): Promise<void> {
    await this.exportRide(ExportFormat.GPX);
  }

  /**
   * 导出为TCX
   */
  private async exportToTcx(): Promise<void> {
    await this.exportRide(ExportFormat.TCX);
  }

  /**
   * 导出骑行记录
   */
  private async exportRide(format: ExportFormat): Promise<void> {
    if (this.isExporting) return;

    this.isExporting = true;
    this.showExportOptions = false;

    try {
      const result: ExportResult = await ExportService.exportRide(this.rideId, {
        format,
        includeHeartRate: true,
        includeElevation: true,
        includeSpeed: true
      });

      if (result.success) {
        hilog.info(DOMAIN, TAG, 'Export successful: %{public}s', result.filePath);
        // 显示成功提示
      } else {
        hilog.error(DOMAIN, TAG, 'Export failed: %{public}s', result.error);
        // 显示错误提示
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Export error: %{public}s', JSON.stringify(error));
    } finally {
      this.isExporting = false;
    }
  }

  /**
   * 分享骑行记录
   */
  private shareRide(): void {
    hilog.info(DOMAIN, TAG, 'Share ride');
    // TODO: 实现分享功能
  }

  /**
   * 删除骑行记录
   */
  private async deleteRide(): Promise<void> {
    try {
      await RideStorageService.deleteRide(this.rideId);
      hilog.info(DOMAIN, TAG, 'Ride deleted');
      router.back();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Delete failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 转换轨迹点格式
   */
  private getTrackPointsForMap(): TrackPoint[] {
    return this.trackPoints.map(tp => ({
      coordinate: {
        latitude: tp.latitude,
        longitude: tp.longitude,
        altitude: tp.altitude || 0,
        accuracy: tp.accuracy || 0,
        timestamp: new Date(tp.timestamp).getTime()
      },
      timestamp: new Date(tp.timestamp).getTime(),
      speed: tp.speed || 0,
      heartRate: tp.heart_rate || 0,
      elevation: tp.altitude || 0,
      distance: 0
    }));
  }

  /**
   * 获取速度数据
   */
  private getSpeedData(): number[] {
    return this.trackPoints
      .filter(tp => tp.speed !== null)
      .map(tp => tp.speed! * 3.6); // m/s -> km/h
  }

  /**
   * 获取心率数据
   */
  private getHeartRateData(): number[] {
    return this.trackPoints
      .filter(tp => tp.heart_rate !== null)
      .map(tp => tp.heart_rate!);
  }

  /**
   * 获取海拔数据
   */
  private getElevationData(): number[] {
    return this.trackPoints
      .filter(tp => tp.altitude !== null)
      .map(tp => tp.altitude!);
  }

  build() {
    Column() {
      // 顶部导航栏
      this.buildHeader()

      // 内容区域
      if (this.isLoading) {
        this.buildLoading()
      } else if (this.ride) {
        this.buildContent()
      } else {
        this.buildEmpty()
      }

      // 导出选项弹窗
      if (this.showExportOptions) {
        this.buildExportOptions()
      }
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

      Text('骑行详情')
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
  buildLoading() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#1890FF')

      Text('加载中...')
        .fontSize(14)
        .fontColor('#99182431')
        .margin({ top: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildEmpty() {
    Column() {
      Text('骑行记录不存在')
        .fontSize(16)
        .fontColor('#99182431')

      Button('返回')
        .margin({ top: 16 })
        .onClick(() => router.back())
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildContent() {
    Scroll() {
      Column() {
        // 地图轨迹
        this.buildMapSection()

        // 数据摘要
        RideDetailSummary({ ride: this.ride })
          .margin({ top: 8, left: 16, right: 16 })

        // 心率区间分布
        HeartRateZoneChart({
          zone1Time: this.ride?.hr_zone1_time || 0,
          zone2Time: this.ride?.hr_zone2_time || 0,
          zone3Time: this.ride?.hr_zone3_time || 0,
          zone4Time: this.ride?.hr_zone4_time || 0,
          zone5Time: this.ride?.hr_zone5_time || 0
        })
          .margin({ top: 8, left: 16, right: 16 })

        // 速度图表
        if (this.getSpeedData().length > 0) {
          RideDataChart({
            title: '速度变化',
            data: this.getSpeedData(),
            color: '#1890FF',
            unit: 'km/h'
          })
            .margin({ top: 8, left: 16, right: 16 })
        }

        // 心率图表
        if (this.getHeartRateData().length > 0) {
          RideDataChart({
            title: '心率变化',
            data: this.getHeartRateData(),
            color: '#F5222D',
            unit: 'bpm'
          })
            .margin({ top: 8, left: 16, right: 16 })
        }

        // 海拔图表
        if (this.getElevationData().length > 0) {
          RideDataChart({
            title: '海拔变化',
            data: this.getElevationData(),
            color: '#52C41A',
            unit: 'm'
          })
            .margin({ top: 8, left: 16, right: 16 })
        }

        // 操作按钮
        RideActionButtons({
          onExport: () => { this.showExportOptions = true; },
          onShare: () => this.shareRide(),
          onDelete: () => this.deleteRide()
        })
          .margin({ top: 8, left: 16, right: 16 })

        // 底部间距
        Column()
          .height(32)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  buildMapSection() {
    Column() {
      MapTrackComponent({
        trackPoints: this.getTrackPointsForMap(),
        currentLocation: this.trackPoints.length > 0 ? {
          coordinate: {
            latitude: this.trackPoints[this.trackPoints.length - 1].latitude,
            longitude: this.trackPoints[this.trackPoints.length - 1].longitude,
            altitude: this.trackPoints[this.trackPoints.length - 1].altitude || 0,
            accuracy: this.trackPoints[this.trackPoints.length - 1].accuracy || 0
          },
          timestamp: new Date(this.trackPoints[this.trackPoints.length - 1].timestamp).getTime(),
          speed: this.trackPoints[this.trackPoints.length - 1].speed || 0,
          heartRate: this.trackPoints[this.trackPoints.length - 1].heart_rate || 0,
          elevation: this.trackPoints[this.trackPoints.length - 1].altitude || 0,
          distance: 0
        } : null,
        showMode: 'speed',
        height: 200
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildExportOptions() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .onClick(() => { this.showExportOptions = false; })

      // 选项面板
      Column() {
        Text('选择导出格式')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 16 })

        Row() {
          Button() {
            Column() {
              Text('GPX')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Text('通用GPS格式')
                .fontSize(10)
                .fontColor('#99182431')
                .margin({ top: 4 })
            }
          }
          .layoutWeight(1)
          .height(80)
          .backgroundColor('#E6F7FF')
          .borderRadius(12)
          .onClick(() => this.exportToGpx())

          Button() {
            Column() {
              Text('TCX')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Text('Garmin格式')
                .fontSize(10)
                .fontColor('#99182431')
                .margin({ top: 4 })
            }
          }
          .layoutWeight(1)
          .height(80)
          .backgroundColor('#FFF7E6')
          .borderRadius(12)
          .margin({ left: 8 })
          .onClick(() => this.exportToTcx())

          Button() {
            Column() {
              Text('JSON')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Text('原始数据')
                .fontSize(10)
                .fontColor('#99182431')
                .margin({ top: 4 })
            }
          }
          .layoutWeight(1)
          .height(80)
          .backgroundColor('#F6FFED')
          .borderRadius(12)
          .margin({ left: 8 })
          .onClick(() => this.exportRide(ExportFormat.JSON))
        }
        .width('100%')

        Button('取消')
          .width('100%')
          .height(44)
          .backgroundColor('#F5F5F5')
          .borderRadius(22)
          .margin({ top: 16 })
          .onClick(() => { this.showExportOptions = false; })
      }
      .width('100%')
      .padding(24)
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .position({ x: 0, y: '100%' })
      .translate({ y: -280 })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }
}

/**
 * 导航页面 - F013
 *
 * 功能说明：
 * - 路线规划入口
 * - 导航界面展示
 * - 实时导航引导
 * - 转向语音提示
 * - 路线偏离处理
 *
 * 依赖组件：
 * - NavigationService: 导航服务
 * - NavigationComponents: 导航组件
 * - MapTrackComponent: 地图组件
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import {
  NavigationService,
  NavigationMode,
  NavigationState,
  NavigationStatus,
  NavigationRoute,
  Maneuver
} from '../services/NavigationService';
import GpsService from '../services/GpsService';
import {
  ManeuverCard,
  NavigationInfoPanel,
  RouteOverviewCard,
  NavigationControls,
  OffRouteAlert,
  ArrivedCard
} from '../components/NavigationComponents';
import { Coordinate } from '../utils/Types';

const TAG = '[NavigationPage]';
const DOMAIN = 0xFF00;

// 页面模式
type PageMode = 'search' | 'planning' | 'navigating';

@Entry
@Component
struct NavigationPage {
  // 页面状态
  @State pageMode: PageMode = 'search';
  @State navigationStatus: NavigationStatus | null = null;

  // 搜索
  @State startPoint: Coordinate | null = null;
  @State endPoint: Coordinate | null = null;
  @State startAddress: string = '';
  @State endAddress: string = '';
  @State searchQuery: string = '';

  // 导航选项
  @State navigationMode: NavigationMode = NavigationMode.ROAD;
  @State avoidTolls: boolean = false;
  @State avoidHighways: boolean = false;

  // 路线信息
  @State plannedRoute: NavigationRoute | null = null;
  @State isPlanning: boolean = false;

  // 当前位置
  @State currentLocation: Coordinate | null = null;
  @State currentSpeed: number = 0;

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'NavigationPage appearing');

    // 获取当前位置作为起点
    this.getCurrentLocation();

    // 注册导航状态回调
    NavigationService.onStatusChange((status: NavigationStatus) => {
      this.navigationStatus = status;

      if (status.state === NavigationState.ARRIVED) {
        this.pageMode = 'navigating';
      }
    });

    // 检查是否有传入的目的地参数
    const params = router.getParams() as Record<string, Object>;
    if (params && params['endPoint']) {
      this.endPoint = params['endPoint'] as Coordinate;
      this.endAddress = params['endAddress'] as string || '目的地';
    }
  }

  aboutToDisappear() {
    hilog.info(DOMAIN, TAG, 'NavigationPage disappearing');
    // 停止GPS
    GpsService.stop();
  }

  /**
   * 获取当前位置
   */
  private async getCurrentLocation(): Promise<void> {
    try {
      await GpsService.start();

      GpsService.onLocation((location) => {
        this.currentLocation = location.coordinate;
        this.currentSpeed = location.speed;

        // 更新导航服务
        if (this.pageMode === 'navigating') {
          NavigationService.updateLocation(location.coordinate, location.speed);
        }
      });

      // 等待第一个位置
      const lastLocation = GpsService.getLastLocation();
      if (lastLocation) {
        this.currentLocation = lastLocation.coordinate;
        this.startPoint = lastLocation.coordinate;
        this.startAddress = '当前位置';
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to get location: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 规划路线
   */
  private async planRoute(): Promise<void> {
    if (!this.startPoint || !this.endPoint) {
      hilog.warn(DOMAIN, TAG, 'Start or end point not set');
      return;
    }

    this.isPlanning = true;

    try {
      const route = await NavigationService.planRoute(
        this.startPoint,
        this.endPoint,
        {
          mode: this.navigationMode,
          avoidTolls: this.avoidTolls,
          avoidHighways: this.avoidHighways
        }
      );

      if (route) {
        this.plannedRoute = route;
        this.pageMode = 'planning';
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Plan route failed: %{public}s', JSON.stringify(error));
    } finally {
      this.isPlanning = false;
    }
  }

  /**
   * 开始导航
   */
  private startNavigation(): void {
    NavigationService.startNavigation();
    this.pageMode = 'navigating';
  }

  /**
   * 暂停导航
   */
  private pauseNavigation(): void {
    NavigationService.pauseNavigation();
  }

  /**
   * 恢复导航
   */
  private resumeNavigation(): void {
    NavigationService.resumeNavigation();
  }

  /**
   * 停止导航
   */
  private stopNavigation(): void {
    NavigationService.stopNavigation();
    this.pageMode = 'search';
    this.plannedRoute = null;
  }

  /**
   * 重新规划路线
   */
  private reroute(): void {
    if (this.currentLocation && this.endPoint) {
      this.planRoute();
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      this.buildHeader()

      // 根据页面模式显示不同内容
      if (this.pageMode === 'search') {
        this.buildSearchPage()
      } else if (this.pageMode === 'planning') {
        this.buildPlanningPage()
      } else {
        this.buildNavigatingPage()
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
      .onClick(() => {
        if (this.pageMode === 'navigating') {
          this.stopNavigation();
        } else if (this.pageMode === 'planning') {
          this.pageMode = 'search';
          this.plannedRoute = null;
        } else {
          router.back();
        }
      })

      Text(this.getPageTitle())
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
  buildSearchPage() {
    Column() {
      // 搜索框
      Column() {
        // 起点
        Row() {
          Circle()
            .width(12)
            .height(12)
            .fill('#52C41A')

          Column() {
            Text('起点')
              .fontSize(10)
              .fontColor('#99182431')

            Text(this.startAddress || '点击选择起点')
              .fontSize(14)
              .fontColor(this.startAddress ? '#182431' : '#BFBFBF')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .onClick(() => {
          // TODO: 选择起点
        })

        Divider()
          .width('100%')
          .margin({ left: 40 })

        // 终点
        Row() {
          Circle()
            .width(12)
            .height(12)
            .fill('#F5222D')

          Column() {
            Text('终点')
              .fontSize(10)
              .fontColor('#99182431')

            Text(this.endAddress || '点击选择终点')
              .fontSize(14)
              .fontColor(this.endAddress ? '#182431' : '#BFBFBF')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .onClick(() => {
          // TODO: 选择终点
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ top: 16, left: 16, right: 16 })

      // 导航选项
      Column() {
        Text('导航选项')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 12 })

        // 导航模式
        Row() {
          Text('导航模式')
            .fontSize(12)
            .fontColor('#99182431')

          Blank()

          Row() {
            this.buildModeChip('公路', NavigationMode.ROAD)
            this.buildModeChip('探险', NavigationMode.ADVENTURE)
            this.buildModeChip('混合', NavigationMode.HYBRID)
          }
        }
        .width('100%')

        // 避开选项
        Row() {
          Text('避开')
            .fontSize(12)
            .fontColor('#99182431')

          Blank()

          Row() {
            this.buildToggleChip('收费路', this.avoidTolls, () => {
              this.avoidTolls = !this.avoidTolls;
            })
            this.buildToggleChip('高速公路', this.avoidHighways, () => {
              this.avoidHighways = !this.avoidHighways;
            })
          }
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ top: 8, left: 16, right: 16 })

      // 规划按钮
      Button() {
        Text(this.isPlanning ? '规划中...' : '开始规划')
          .fontSize(16)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(48)
      .backgroundColor(this.isPlanning ? '#BFBFBF' : '#1890FF')
      .borderRadius(24)
      .margin({ top: 24, left: 16, right: 16 })
      .enabled(!this.isPlanning && this.startPoint !== null && this.endPoint !== null)
      .onClick(() => this.planRoute())

      Blank()
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildPlanningPage() {
    Column() {
      // 地图区域 (占位)
      Column() {
        Text('🗺️')
          .fontSize(48)

        Text('路线预览')
          .fontSize(14)
          .fontColor('#99182431')
          .margin({ top: 8 })

        if (this.plannedRoute) {
          Text(`${(this.plannedRoute.distance / 1000).toFixed(1)}km · ${this.formatDuration(this.plannedRoute.duration)}`)
            .fontSize(12)
            .fontColor('#80182431')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .height(300)
      .backgroundColor('#E8F4FF')
      .justifyContent(FlexAlign.Center)

      // 路线信息
      if (this.plannedRoute) {
        RouteOverviewCard({ route: this.plannedRoute })
          .margin({ top: 16, left: 16, right: 16 })
      }

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
      .backgroundColor('#52C41A')
      .borderRadius(24)
      .margin({ top: 16, left: 16, right: 16 })
      .onClick(() => this.startNavigation())

      Blank()
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildNavigatingPage() {
    Stack() {
      // 地图背景
      Column() {
        Text('🗺️ 导航地图')
          .fontSize(24)
          .fontColor('#99182431')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#E8F4FF')
      .justifyContent(FlexAlign.Center)

      // 导航界面层
      Column() {
        // 转向提示卡片
        if (this.navigationStatus?.nextManeuver) {
          ManeuverCard({
            maneuver: this.navigationStatus.nextManeuver,
            distanceToManeuver: this.navigationStatus.distanceToNextManeuver
          })
        }

        Blank()

        // 偏离路线提示
        if (this.navigationStatus?.offRoute) {
          OffRouteAlert({
            distance: this.navigationStatus.distanceOffRoute,
            onReroute: () => this.reroute()
          })
            .margin({ left: 16, right: 16 })
        }

        // 到达提示
        if (this.navigationStatus?.state === NavigationState.ARRIVED) {
          ArrivedCard({
            onComplete: () => this.stopNavigation()
          })
            .margin({ left: 16, right: 16, bottom: 16 })
        }

        // 导航信息面板
        NavigationInfoPanel({
          remainingDistance: this.navigationStatus?.remainingDistance || 0,
          remainingDuration: this.navigationStatus?.remainingDuration || 0,
          estimatedArrival: this.navigationStatus?.estimatedArrival || new Date(),
          currentSpeed: this.currentSpeed
        })

        // 导航控制按钮
        NavigationControls({
          isNavigating: this.navigationStatus?.state === NavigationState.NAVIGATING ||
                       this.navigationStatus?.state === NavigationState.PAUSED,
          isPaused: this.navigationStatus?.state === NavigationState.PAUSED,
          onPause: () => this.pauseNavigation(),
          onResume: () => this.resumeNavigation(),
          onStop: () => this.stopNavigation()
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildModeChip(label: string, mode: NavigationMode) {
    Text(label)
      .fontSize(12)
      .fontColor(this.navigationMode === mode ? '#1890FF' : '#182431')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.navigationMode === mode ? '#E6F7FF' : '#F5F5F5')
      .borderRadius(16)
      .margin({ left: 8 })
      .onClick(() => {
        this.navigationMode = mode;
      })
  }

  @Builder
  buildToggleChip(label: string, selected: boolean, onToggle: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor(selected ? '#1890FF' : '#182431')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(selected ? '#E6F7FF' : '#F5F5F5')
      .borderRadius(16)
      .margin({ left: 8 })
      .onClick(onToggle)
  }

  private getPageTitle(): string {
    switch (this.pageMode) {
      case 'search':
        return '路线规划';
      case 'planning':
        return '路线预览';
      case 'navigating':
        return '导航中';
      default:
        return '导航';
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
}

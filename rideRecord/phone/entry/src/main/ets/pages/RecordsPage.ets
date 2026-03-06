/**
 * 骑行记录列表页面 - F011
 *
 * 功能说明：
 * - 显示历史骑行记录
 * - 支持筛选和排序
 * - 下拉刷新
 * - 分页加载
 * - 骑行统计摘要
 *
 * 依赖组件：
 * - RideStorageService: 数据存储
 * - RideListItem: 列表项组件
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';
import RideStorageService, { RideRecordEntity, RideSummary, RideQueryOptions } from '../services/RideStorageService';
import { RideListItem, RideStatsCard, FilterChip, EmptyRidesState } from '../components/RideListItem';

const TAG = '[RecordsPage]';
const DOMAIN = 0xFF00;

// 每页加载数量
const PAGE_SIZE = 20;

// 排序选项
type SortOption = 'date_desc' | 'date_asc' | 'distance_desc' | 'duration_desc';

// 时间筛选选项
type TimeFilter = 'all' | 'week' | 'month' | 'year';

@Entry
@Component
struct RecordsPage {
  // 骑行记录列表
  @State rides: RideRecordEntity[] = [];
  // 骑行统计
  @State summary: RideSummary | null = null;
  // 加载状态
  @State isLoading: boolean = false;
  @State hasMore: boolean = true;
  @State currentPage: number = 0;
  // 筛选和排序
  @State currentSort: SortOption = 'date_desc';
  @State currentTimeFilter: TimeFilter = 'all';
  // 显示模式
  @State showStats: boolean = true;

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'RecordsPage appearing');
    this.loadInitialData();
  }

  /**
   * 加载初始数据
   */
  private async loadInitialData(): Promise<void> {
    this.isLoading = true;

    try {
      // 并行加载统计和列表
      await Promise.all([
        this.loadStats(),
        this.loadRides(true)
      ]);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load data: %{public}s', JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 加载骑行统计
   */
  private async loadStats(): Promise<void> {
    try {
      const options = this.getQueryOptions();
      this.summary = await RideStorageService.getRideSummary(options);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load stats: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 加载骑行记录
   */
  private async loadRides(refresh: boolean = false): Promise<void> {
    if (refresh) {
      this.currentPage = 0;
      this.hasMore = true;
    }

    if (!this.hasMore && !refresh) {
      return;
    }

    try {
      const options = this.getQueryOptions();
      options.limit = PAGE_SIZE;
      options.offset = this.currentPage * PAGE_SIZE;

      const newRides = await RideStorageService.getRides(options);

      if (refresh) {
        this.rides = newRides;
      } else {
        this.rides = [...this.rides, ...newRides];
      }

      this.hasMore = newRides.length >= PAGE_SIZE;
      this.currentPage++;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load rides: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 获取查询选项
   */
  private getQueryOptions(): RideQueryOptions {
    const options: RideQueryOptions = {};

    // 时间筛选
    const now = new Date();
    switch (this.currentTimeFilter) {
      case 'week':
        const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        options.startDate = weekAgo.toISOString();
        break;
      case 'month':
        const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        options.startDate = monthAgo.toISOString();
        break;
      case 'year':
        const yearAgo = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
        options.startDate = yearAgo.toISOString();
        break;
    }

    // 排序
    switch (this.currentSort) {
      case 'date_desc':
        options.orderBy = 'start_time';
        options.orderDirection = 'DESC';
        break;
      case 'date_asc':
        options.orderBy = 'start_time';
        options.orderDirection = 'ASC';
        break;
      case 'distance_desc':
        options.orderBy = 'distance';
        options.orderDirection = 'DESC';
        break;
      case 'duration_desc':
        options.orderBy = 'duration';
        options.orderDirection = 'DESC';
        break;
    }

    options.status = 'completed';

    return options;
  }

  /**
   * 下拉刷新
   */
  private async onRefresh(): Promise<void> {
    await this.loadInitialData();
  }

  /**
   * 加载更多
   */
  private async onLoadMore(): Promise<void> {
    if (this.isLoading || !this.hasMore) {
      return;
    }

    this.isLoading = true;
    try {
      await this.loadRides(false);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 跳转到骑行详情
   */
  private navigateToDetail(rideId: string): void {
    router.pushUrl({
      url: 'pages/RecordDetailPage',
      params: { id: rideId }
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to navigate: %{public}s', error.message);
    });
  }

  /**
   * 跳转到骑行页面
   */
  private navigateToRide(): void {
    router.pushUrl({
      url: 'pages/RidingPage'
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to navigate: %{public}s', error.message);
    });
  }

  build() {
    Column() {
      // 标题栏
      this.buildHeader()

      // 内容区域
      if (this.rides.length === 0 && !this.isLoading) {
        // 空状态
        EmptyRidesState({
          onStartRide: () => this.navigateToRide()
        })
      } else {
        // 列表
        this.buildContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }

  @Builder
  buildHeader() {
    Row() {
      Text('骑行记录')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#182431')

      Blank()

      // 开始骑行按钮
      Button() {
        Text('+ 骑行')
          .fontSize(14)
          .fontColor('#FFFFFF')
      }
      .height(32)
      .backgroundColor('#1890FF')
      .borderRadius(16)
      .padding({ left: 16, right: 16 })
      .onClick(() => this.navigateToRide())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildContent() {
    Scroll() {
      Column() {
        // 统计卡片
        if (this.showStats && this.summary) {
          RideStatsCard({
            totalRides: this.summary.totalRides,
            totalDistance: this.summary.totalDistance,
            totalDuration: this.summary.totalDuration,
            avgSpeed: this.summary.avgSpeed
          })
            .margin({ top: 16, left: 16, right: 16 })
        }

        // 筛选和排序
        this.buildFilters()

        // 骑行记录列表
        this.buildRidesList()

        // 加载更多
        if (this.hasMore && this.rides.length > 0) {
          this.buildLoadMore()
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  buildFilters() {
    Column() {
      // 时间筛选
      Row() {
        Text('时间:')
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ right: 8 })

        FilterChip({
          label: '全部',
          selected: this.currentTimeFilter === 'all',
          onToggle: () => {
            this.currentTimeFilter = 'all';
            this.loadInitialData();
          }
        })

        FilterChip({
          label: '本周',
          selected: this.currentTimeFilter === 'week',
          onToggle: () => {
            this.currentTimeFilter = 'week';
            this.loadInitialData();
          }
        })

        FilterChip({
          label: '本月',
          selected: this.currentTimeFilter === 'month',
          onToggle: () => {
            this.currentTimeFilter = 'month';
            this.loadInitialData();
          }
        })

        FilterChip({
          label: '今年',
          selected: this.currentTimeFilter === 'year',
          onToggle: () => {
            this.currentTimeFilter = 'year';
            this.loadInitialData();
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })

      // 排序
      Row() {
        Text('排序:')
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ right: 8 })

        FilterChip({
          label: '最新',
          selected: this.currentSort === 'date_desc',
          onToggle: () => {
            this.currentSort = 'date_desc';
            this.loadInitialData();
          }
        })

        FilterChip({
          label: '最早',
          selected: this.currentSort === 'date_asc',
          onToggle: () => {
            this.currentSort = 'date_asc';
            this.loadInitialData();
          }
        })

        FilterChip({
          label: '距离',
          selected: this.currentSort === 'distance_desc',
          onToggle: () => {
            this.currentSort = 'distance_desc';
            this.loadInitialData();
          }
        })

        FilterChip({
          label: '时长',
          selected: this.currentSort === 'duration_desc',
          onToggle: () => {
            this.currentSort = 'duration_desc';
            this.loadInitialData();
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 12 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .margin({ top: 8 })
  }

  @Builder
  buildRidesList() {
    Column() {
      ForEach(this.rides, (ride: RideRecordEntity, index: number) => {
        RideListItem({
          ride: ride,
          onItemClick: (rideId: string) => this.navigateToDetail(rideId)
        })
          .margin({ top: index === 0 ? 16 : 8, left: 16, right: 16 })
      })

      // 空状态
      if (this.rides.length === 0 && !this.isLoading) {
        Column() {
          Text('暂无骑行记录')
            .fontSize(14)
            .fontColor('#99182431')
            .margin({ top: 40 })
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  buildLoadMore() {
    Column() {
      if (this.isLoading) {
        Row() {
          LoadingProgress()
            .width(24)
            .height(24)
            .color('#1890FF')
          Text('加载中...')
            .fontSize(14)
            .fontColor('#99182431')
            .margin({ left: 8 })
        }
        .padding(16)
      } else {
        Button('加载更多')
          .fontSize(14)
          .fontColor('#1890FF')
          .backgroundColor('#FFFFFF')
          .borderRadius(24)
          .onClick(() => this.onLoadMore())
          .padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .margin({ top: 8, bottom: 16 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * 地图轨迹组件
 *
 * 功能说明：
 * - 实时轨迹绘制
 * - 当前位置标记
 * - 轨迹颜色变化 (根据速度/心率)
 * - 地图缩放和拖拽
 *
 * 技术说明：
 * - 使用 Canvas 绘制轨迹
 * - 支持地图SDK集成 (华为地图/高德地图)
 * - 支持离线轨迹渲染
 */
import hilog from '@ohos.hilog';
import { TrackPoint, Coordinate } from '../utils/Types';

const TAG = '[MapTrackComponent]';
const DOMAIN = 0xFF00;

// 轨迹颜色 (根据速度)
const SPEED_COLORS = [
  { maxSpeed: 10, color: '#52C41A' },   // 慢速 - 绿色
  { maxSpeed: 20, color: '#1890FF' },   // 中速 - 蓝色
  { maxSpeed: 30, color: '#FAAD14' },   // 快速 - 橙色
  { maxSpeed: 100, color: '#F5222D' }   // 极快 - 红色
];

// 默认颜色
const DEFAULT_TRACK_COLOR = '#1890FF';

/**
 * 地图轨迹组件
 */
@Component
export struct MapTrackComponent {
  // 轨迹点列表
  @Prop trackPoints: TrackPoint[] = [];
  // 当前位置
  @Prop currentLocation: TrackPoint | null = null;
  // 地图中心点
  @Prop center: Coordinate | null = null;
  // 缩放级别
  @Prop zoomLevel: number = 15;
  // 显示模式
  @Prop showMode: 'speed' | 'heartRate' | 'default' = 'default';
  // 是否显示当前位置标记
  @Prop showCurrentMarker: boolean = true;
  // 组件尺寸
  @Prop width: string | number = '100%';
  @Prop height: string | number = 200;

  // Canvas 上下文
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 视图参数
  private minLat: number = 0;
  private maxLat: number = 0;
  private minLon: number = 0;
  private maxLon: number = 0;
  private padding: number = 20;

  build() {
    Stack() {
      // 背景地图 (占位)
      Column() {
        Canvas(this.context)
          .width(this.width)
          .height(this.height)
          .onReady(() => {
            this.drawTrack();
          })
      }
      .width(this.width)
      .height(this.height)
      .backgroundColor('#E8F4FF')
      .borderRadius(12)

      // 当前位置标记
      if (this.showCurrentMarker && this.currentLocation) {
        Column() {
          Text('📍')
            .fontSize(24)
        }
        .position({
          x: '50%',
          y: '50%'
        })
        .translate({ x: -12, y: -24 })
      }

      // 指南针
      Column() {
        Text('N')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
      }
      .width(32)
      .height(32)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .justifyContent(FlexAlign.Center)
      .position({ x: '100%', y: 10 })
      .translate({ x: -42 })
      .shadow({
        radius: 4,
        color: '#20000000',
        offsetX: 0,
        offsetY: 2
      })
    }
    .width(this.width)
    .height(this.height)
  }

  /**
   * 绘制轨迹
   */
  private drawTrack(): void {
    if (this.trackPoints.length < 2) {
      this.drawEmptyState();
      return;
    }

    // 计算边界
    this.calculateBounds();

    // 清除画布
    this.context.clearRect(0, 0, this.getWidth(), this.getHeight());

    // 绘制轨迹
    this.drawTrackLine();

    // 绘制起点和终点
    this.drawEndpoints();

    // 绘制当前位置
    if (this.showCurrentMarker && this.currentLocation) {
      this.drawCurrentPosition();
    }
  }

  /**
   * 绘制空状态
   */
  private drawEmptyState(): void {
    const width = this.getWidth();
    const height = this.getHeight();

    this.context.clearRect(0, 0, width, height);

    // 绘制网格背景
    this.context.strokeStyle = '#D9E8F5';
    this.context.lineWidth = 1;

    const gridSize = 30;
    for (let x = 0; x < width; x += gridSize) {
      this.context.beginPath();
      this.context.moveTo(x, 0);
      this.context.lineTo(x, height);
      this.context.stroke();
    }
    for (let y = 0; y < height; y += gridSize) {
      this.context.beginPath();
      this.context.moveTo(0, y);
      this.context.lineTo(width, y);
      this.context.stroke();
    }
  }

  /**
   * 计算轨迹边界
   */
  private calculateBounds(): void {
    if (this.trackPoints.length === 0) return;

    this.minLat = this.trackPoints[0].coordinate.latitude;
    this.maxLat = this.minLat;
    this.minLon = this.trackPoints[0].coordinate.longitude;
    this.maxLon = this.minLon;

    for (const point of this.trackPoints) {
      const lat = point.coordinate.latitude;
      const lon = point.coordinate.longitude;

      if (lat < this.minLat) this.minLat = lat;
      if (lat > this.maxLat) this.maxLat = lat;
      if (lon < this.minLon) this.minLon = lon;
      if (lon > this.maxLon) this.maxLon = lon;
    }

    // 添加边距
    const latPadding = (this.maxLat - this.minLat) * 0.1 || 0.001;
    const lonPadding = (this.maxLon - this.minLon) * 0.1 || 0.001;

    this.minLat -= latPadding;
    this.maxLat += latPadding;
    this.minLon -= lonPadding;
    this.maxLon += lonPadding;
  }

  /**
   * 绘制轨迹线
   */
  private drawTrackLine(): void {
    if (this.trackPoints.length < 2) return;

    const width = this.getWidth();
    const height = this.getHeight();

    // 根据显示模式选择颜色
    if (this.showMode === 'speed') {
      // 按速度分段着色
      this.drawSpeedColoredTrack();
    } else {
      // 默认颜色
      this.context.beginPath();
      this.context.strokeStyle = DEFAULT_TRACK_COLOR;
      this.context.lineWidth = 4;
      this.context.lineCap = 'round';
      this.context.lineJoin = 'round';

      let first = true;
      for (const point of this.trackPoints) {
        const x = this.lonToX(point.coordinate.longitude, width);
        const y = this.latToY(point.coordinate.latitude, height);

        if (first) {
          this.context.moveTo(x, y);
          first = false;
        } else {
          this.context.lineTo(x, y);
        }
      }

      this.context.stroke();
    }
  }

  /**
   * 绘制速度着色轨迹
   */
  private drawSpeedColoredTrack(): void {
    const width = this.getWidth();
    const height = this.getHeight();

    for (let i = 1; i < this.trackPoints.length; i++) {
      const prev = this.trackPoints[i - 1];
      const curr = this.trackPoints[i];

      const x1 = this.lonToX(prev.coordinate.longitude, width);
      const y1 = this.latToY(prev.coordinate.latitude, height);
      const x2 = this.lonToX(curr.coordinate.longitude, width);
      const y2 = this.latToY(curr.coordinate.latitude, height);

      // 根据速度选择颜色
      const color = this.getSpeedColor(curr.speed);

      this.context.beginPath();
      this.context.strokeStyle = color;
      this.context.lineWidth = 4;
      this.context.lineCap = 'round';
      this.context.moveTo(x1, y1);
      this.context.lineTo(x2, y2);
      this.context.stroke();
    }
  }

  /**
   * 获取速度对应颜色
   */
  private getSpeedColor(speed: number): string {
    for (const item of SPEED_COLORS) {
      if (speed < item.maxSpeed) {
        return item.color;
      }
    }
    return DEFAULT_TRACK_COLOR;
  }

  /**
   * 绘制起点和终点
   */
  private drawEndpoints(): void {
    if (this.trackPoints.length < 1) return;

    const width = this.getWidth();
    const height = this.getHeight();

    // 起点 (绿色圆点)
    const startPoint = this.trackPoints[0];
    const startX = this.lonToX(startPoint.coordinate.longitude, width);
    const startY = this.latToY(startPoint.coordinate.latitude, height);

    this.context.beginPath();
    this.context.arc(startX, startY, 8, 0, 2 * Math.PI);
    this.context.fillStyle = '#52C41A';
    this.context.fill();
    this.context.strokeStyle = '#FFFFFF';
    this.context.lineWidth = 2;
    this.context.stroke();

    // 终点 (红色圆点)
    if (this.trackPoints.length > 1) {
      const endPoint = this.trackPoints[this.trackPoints.length - 1];
      const endX = this.lonToX(endPoint.coordinate.longitude, width);
      const endY = this.latToY(endPoint.coordinate.latitude, height);

      this.context.beginPath();
      this.context.arc(endX, endY, 8, 0, 2 * Math.PI);
      this.context.fillStyle = '#F5222D';
      this.context.fill();
      this.context.strokeStyle = '#FFFFFF';
      this.context.lineWidth = 2;
      this.context.stroke();
    }
  }

  /**
   * 绘制当前位置
   */
  private drawCurrentPosition(): void {
    if (!this.currentLocation) return;

    const width = this.getWidth();
    const height = this.getHeight();

    const x = this.lonToX(this.currentLocation.coordinate.longitude, width);
    const y = this.latToY(this.currentLocation.coordinate.latitude, height);

    // 外圈 (脉冲效果)
    this.context.beginPath();
    this.context.arc(x, y, 16, 0, 2 * Math.PI);
    this.context.fillStyle = '#331890FF';
    this.context.fill();

    // 内圈
    this.context.beginPath();
    this.context.arc(x, y, 10, 0, 2 * Math.PI);
    this.context.fillStyle = '#1890FF';
    this.context.fill();

    // 中心点
    this.context.beginPath();
    this.context.arc(x, y, 4, 0, 2 * Math.PI);
    this.context.fillStyle = '#FFFFFF';
    this.context.fill();
  }

  /**
   * 经度转X坐标
   */
  private lonToX(lon: number, width: number): number {
    if (this.maxLon === this.minLon) return width / 2;
    return this.padding + (lon - this.minLon) / (this.maxLon - this.minLon) * (width - 2 * this.padding);
  }

  /**
   * 纬度转Y坐标
   */
  private latToY(lat: number, height: number): number {
    if (this.maxLat === this.minLat) return height / 2;
    // 注意：纬度越大，Y坐标越小 (屏幕坐标系)
    return this.padding + (this.maxLat - lat) / (this.maxLat - this.minLat) * (height - 2 * this.padding);
  }

  /**
   * 获取组件宽度
   */
  private getWidth(): number {
    if (typeof this.width === 'number') {
      return this.width;
    }
    return 300; // 默认宽度
  }

  /**
   * 获取组件高度
   */
  private getHeight(): number {
    if (typeof this.height === 'number') {
      return this.height;
    }
    return 200; // 默认高度
  }
}

/**
 * 地图控制组件
 */
@Component
export struct MapControls {
  onZoomIn: () => void = () => {};
  onZoomOut: () => void = () => {};
  onLocate: () => void = () => {};

  build() {
    Column() {
      // 放大
      Button() {
        Text('+')
          .fontSize(20)
          .fontColor('#182431')
      }
      .width(40)
      .height(40)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .onClick(() => this.onZoomIn())

      // 定位
      Button() {
        Text('📍')
          .fontSize(16)
      }
      .width(40)
      .height(40)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .margin({ top: 8 })
      .onClick(() => this.onLocate())

      // 缩小
      Button() {
        Text('-')
          .fontSize(20)
          .fontColor('#182431')
      }
      .width(40)
      .height(40)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .margin({ top: 8 })
      .onClick(() => this.onZoomOut())
    }
    .padding(8)
    .backgroundColor('#00000000')
  }
}

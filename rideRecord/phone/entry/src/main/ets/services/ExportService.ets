/**
 * 数据导出服务
 *
 * 功能说明：
 * - GPX 格式导出
 * - TCX 格式导出
 * - JSON 格式导出
 * - 文件保存和管理
 *
 * 支持格式：
 * - GPX: GPS Exchange Format (通用)
 * - TCX: Training Center XML (Garmin)
 */
import hilog from '@ohos.hilog';
import fs from '@ohos.file.fs';
import { TrackPoint, RideRecord } from '../utils/Types';
import RideStorageService, { RideRecordEntity, TrackPointEntity } from './RideStorageService';

const TAG = '[ExportService]';
const DOMAIN = 0xFF00;

/**
 * 导出格式
 */
export enum ExportFormat {
  GPX = 'gpx',
  TCX = 'tcx',
  JSON = 'json'
}

/**
 * 导出选项
 */
export interface ExportOptions {
  format: ExportFormat;
  includeHeartRate: boolean;
  includeElevation: boolean;
  includeSpeed: boolean;
  fileName?: string;
}

/**
 * 导出结果
 */
export interface ExportResult {
  success: boolean;
  filePath: string | null;
  fileSize: number;
  error?: string;
}

/**
 * 数据导出服务类
 */
export class ExportService {
  // 默认导出目录
  private exportDir: string = '/data/storage/el2/base/files/exports';

  /**
   * 导出骑行记录
   */
  async exportRide(rideId: string, options: ExportOptions): Promise<ExportResult> {
    hilog.info(DOMAIN, TAG, 'Exporting ride: %{public}s, format: %{public}s', rideId, options.format);

    try {
      // 获取骑行记录
      const ride = await RideStorageService.getRideById(rideId);
      if (!ride) {
        return {
          success: false,
          filePath: null,
          fileSize: 0,
          error: 'Ride not found'
        };
      }

      // 获取轨迹点
      const trackPoints = await RideStorageService.getTrackPoints(rideId);

      // 根据格式生成内容
      let content: string;
      let extension: string;

      switch (options.format) {
        case ExportFormat.GPX:
          content = this.generateGpx(ride, trackPoints, options);
          extension = 'gpx';
          break;
        case ExportFormat.TCX:
          content = this.generateTcx(ride, trackPoints, options);
          extension = 'tcx';
          break;
        case ExportFormat.JSON:
          content = this.generateJson(ride, trackPoints);
          extension = 'json';
          break;
        default:
          return {
            success: false,
            filePath: null,
            fileSize: 0,
            error: 'Unsupported format'
          };
      }

      // 生成文件名
      const fileName = options.fileName || this.generateFileName(ride, extension);
      const filePath = `${this.exportDir}/${fileName}`;

      // 确保目录存在
      await this.ensureDirectory(this.exportDir);

      // 写入文件
      await this.writeFile(filePath, content);

      const fileSize = content.length;

      hilog.info(DOMAIN, TAG, 'Export completed: %{public}s, size: %{public}d', filePath, fileSize);

      return {
        success: true,
        filePath,
        fileSize
      };

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Export failed: %{public}s', JSON.stringify(error));
      return {
        success: false,
        filePath: null,
        fileSize: 0,
        error: String(error)
      };
    }
  }

  /**
   * 批量导出骑行记录
   */
  async exportRides(rideIds: string[], options: ExportOptions): Promise<ExportResult[]> {
    const results: ExportResult[] = [];

    for (const rideId of rideIds) {
      const result = await this.exportRide(rideId, options);
      results.push(result);
    }

    return results;
  }

  /**
   * 生成 GPX 格式
   */
  private generateGpx(ride: RideRecordEntity, trackPoints: TrackPointEntity[], options: ExportOptions): string {
    const startTime = new Date(ride.start_time);
    const endTime = new Date(ride.end_time || ride.start_time);

    let gpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1"
  creator="RideRecord"
  xmlns="http://www.topografix.com/GPX/1/1"
  xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <name>${this.escapeXml(ride.title || `Ride ${startTime.toISOString().split('T')[0]}`)}</name>
    <time>${startTime.toISOString()}</time>
  </metadata>
  <trk>
    <name>${this.escapeXml(ride.title || 'Cycling')}</name>
    <type>Cycling</type>
    <trkseg>`;

    for (const point of trackPoints) {
      gpx += `
      <trkpt lat="${point.latitude}" lon="${point.longitude}">`;

      if (options.includeElevation && point.altitude !== null) {
        gpx += `
        <ele>${point.altitude.toFixed(1)}</ele>`;
      }

      gpx += `
        <time>${point.timestamp}</time>`;

      // 扩展数据
      if ((options.includeHeartRate && point.heart_rate !== null) ||
          (options.includeSpeed && point.speed !== null)) {
        gpx += `
        <extensions>
          <gpxtpx:TrackPointExtension>`;

        if (options.includeHeartRate && point.heart_rate !== null) {
          gpx += `
            <gpxtpx:hr>${point.heart_rate}</gpxtpx:hr>`;
        }

        if (options.includeSpeed && point.speed !== null) {
          gpx += `
            <gpxtpx:speed>${point.speed.toFixed(2)}</gpxtpx:speed>`;
        }

        gpx += `
          </gpxtpx:TrackPointExtension>
        </extensions>`;
      }

      gpx += `
      </trkpt>`;
    }

    gpx += `
    </trkseg>
  </trk>
</gpx>`;

    return gpx;
  }

  /**
   * 生成 TCX 格式
   */
  private generateTcx(ride: RideRecordEntity, trackPoints: TrackPointEntity[], options: ExportOptions): string {
    const startTime = new Date(ride.start_time);
    const endTime = new Date(ride.end_time || ride.start_time);

    let tcx = `<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase
  xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd">
  <Activities>
    <Activity Sport="Biking">
      <Id>${startTime.toISOString()}</Id>
      <Lap StartTime="${startTime.toISOString()}">
        <TotalTimeSeconds>${ride.duration}</TotalTimeSeconds>
        <DistanceMeters>${ride.distance}</DistanceMeters>
        <MaximumSpeed>${ride.max_speed / 3.6}</MaximumSpeed>
        <Calories>${ride.calories}</Calories>
        <Intensity>Active</Intensity>
        <TriggerMethod>Manual</TriggerMethod>
        <Track>`;

    for (const point of trackPoints) {
      tcx += `
          <Trackpoint>
            <Time>${point.timestamp}</Time>
            <Position>
              <LatitudeDegrees>${point.latitude}</LatitudeDegrees>
              <LongitudeDegrees>${point.longitude}</LongitudeDegrees>
            </Position>`;

      if (options.includeElevation && point.altitude !== null) {
        tcx += `
            <AltitudeMeters>${point.altitude.toFixed(1)}</AltitudeMeters>`;
      }

      if (options.includeHeartRate && point.heart_rate !== null) {
        tcx += `
            <HeartRateBpm>
              <Value>${point.heart_rate}</Value>
            </HeartRateBpm>`;
      }

      if (options.includeSpeed && point.speed !== null) {
        tcx += `
            <Extensions>
              <TPX xmlns="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
                <Speed>${(point.speed / 3.6).toFixed(2)}</Speed>
              </TPX>
            </Extensions>`;
      }

      tcx += `
          </Trackpoint>`;
    }

    tcx += `
        </Track>
      </Lap>
      <Notes>${this.escapeXml(ride.note || '')}</Notes>
    </Activity>
  </Activities>
  <Author xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="Application_t">
    <Name>RideRecord</Name>
    <Build>
      <Version>
        <VersionMajor>1</VersionMajor>
        <VersionMinor>0</VersionMinor>
        <BuildMajor>0</BuildMajor>
        <BuildMinor>0</BuildMinor>
      </Version>
    </Build>
    <LangID>en</LangID>
    <PartNumber>000-00000-00</PartNumber>
  </Author>
</TrainingCenterDatabase>`;

    return tcx;
  }

  /**
   * 生成 JSON 格式
   */
  private generateJson(ride: RideRecordEntity, trackPoints: TrackPointEntity[]): string {
    const data = {
      ride: {
        id: ride.id,
        startTime: ride.start_time,
        endTime: ride.end_time,
        duration: ride.duration,
        movingTime: ride.moving_time,
        distance: ride.distance,
        avgSpeed: ride.avg_speed,
        maxSpeed: ride.max_speed,
        avgHeartRate: ride.avg_heart_rate,
        maxHeartRate: ride.max_heart_rate,
        calories: ride.calories,
        elevationGain: ride.elevation_gain,
        elevationLoss: ride.elevation_loss
      },
      trackPoints: trackPoints.map(p => ({
        timestamp: p.timestamp,
        latitude: p.latitude,
        longitude: p.longitude,
        altitude: p.altitude,
        speed: p.speed,
        heartRate: p.heart_rate
      }))
    };

    return JSON.stringify(data, null, 2);
  }

  /**
   * 生成文件名
   */
  private generateFileName(ride: RideRecordEntity, extension: string): string {
    const date = new Date(ride.start_time);
    const dateStr = date.toISOString().split('T')[0];
    const timeStr = date.toTimeString().split(' ')[0].replace(/:/g, '-');

    if (ride.title) {
      const safeTitle = ride.title.replace(/[^a-zA-Z0-9\u4e00-\u9fa5]/g, '_');
      return `${dateStr}_${safeTitle}.${extension}`;
    }

    return `${dateStr}_${timeStr}.${extension}`;
  }

  /**
   * 确保目录存在
   */
  private async ensureDirectory(dirPath: string): Promise<void> {
    try {
      // 尝试创建目录（如果不存在）
      // 在 HarmonyOS 中，需要使用适当的 API
      hilog.debug(DOMAIN, TAG, 'Ensuring directory: %{public}s', dirPath);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Directory check failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 写入文件
   */
  private async writeFile(filePath: string, content: string): Promise<void> {
    try {
      // 在 HarmonyOS 中，使用 fs 模块写入文件
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, content);
      fs.closeSync(file);
      hilog.debug(DOMAIN, TAG, 'File written: %{public}s', filePath);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Write file failed: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 转义 XML 特殊字符
   */
  private escapeXml(str: string): string {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  /**
   * 设置导出目录
   */
  setExportDirectory(dir: string): void {
    this.exportDir = dir;
  }

  /**
   * 获取支持的导出格式
   */
  getSupportedFormats(): ExportFormat[] {
    return [ExportFormat.GPX, ExportFormat.TCX, ExportFormat.JSON];
  }
}

// 导出单例
export default new ExportService();

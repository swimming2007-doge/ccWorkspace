/**
 * 统计分析服务
 *
 * 功能说明：
 * - 骑行数据统计计算
 * - 日/周/月/年统计
 * - 趋势分析
 * - 心率区间分布
 * - 热量消耗计算
 *
 * 依赖：
 * - RideStorageService: 骑行数据存储
 */

import hilog from '@ohos.hilog';
import { RideStorageService, RideRecordEntity, RideSummary } from './RideStorageService';

const TAG = '[StatsService]';
const DOMAIN = 0xFF00;

/**
 * 时间范围
 */
export enum TimeRange {
  TODAY = 'today',
  THIS_WEEK = 'this_week',
  THIS_MONTH = 'this_month',
  THIS_YEAR = 'this_year',
  ALL_TIME = 'all_time'
}

/**
 * 统计数据
 */
export interface StatsData {
  // 基础统计
  totalRides: number;
  totalDistance: number; // 米
  totalDuration: number; // 秒
  totalMovingTime: number;
  totalCalories: number;

  // 速度统计
  avgSpeed: number;
  maxSpeed: number;

  // 心率统计
  avgHeartRate: number;
  maxHeartRate: number;
  hrZoneDistribution: HRZoneDistribution;

  // 海拔统计
  totalElevationGain: number;
  totalElevationLoss: number;

  // 记录
  longestRide: number;
  fastestRide: number;
  longestDuration: number;

  // 平均值
  avgDistance: number;
  avgDuration: number;
}

/**
 * 心率区间分布
 */
export interface HRZoneDistribution {
  zone1: number; // 秒
  zone2: number;
  zone3: number;
  zone4: number;
  zone5: number;
}

/**
 * 趋势数据点
 */
export interface TrendPoint {
  date: string;
  value: number;
}

/**
 * 趋势数据
 */
export interface TrendData {
  distance: TrendPoint[];
  duration: TrendPoint[];
  speed: TrendPoint[];
  calories: TrendPoint[];
}

/**
 * 周统计
 */
export interface WeeklyStats {
  weekStart: string;
  weekEnd: string;
  rides: number;
  distance: number;
  duration: number;
  calories: number;
}

/**
 * 月统计
 */
export interface MonthlyStats {
  year: number;
  month: number;
  rides: number;
  distance: number;
  duration: number;
  calories: number;
  avgSpeed: number;
}

/**
 * 统计分析服务类
 */
export class StatsService {

  /**
   * 获取时间范围统计
   */
  async getStats(timeRange: TimeRange): Promise<StatsData> {
    const { startDate, endDate } = this.getDateRange(timeRange);
    const rides = await RideStorageService.getRides({
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
      status: 'completed'
    });

    return this.calculateStats(rides);
  }

  /**
   * 获取所有时间统计
   */
  async getAllTimeStats(): Promise<StatsData> {
    const rides = await RideStorageService.getRides({
      status: 'completed'
    });

    return this.calculateStats(rides);
  }

  /**
   * 获取趋势数据
   */
  async getTrends(timeRange: TimeRange): Promise<TrendData> {
    const { startDate, endDate } = this.getDateRange(timeRange);
    const rides = await RideStorageService.getRides({
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
      status: 'completed',
      orderBy: 'start_time',
      orderDirection: 'ASC'
    });

    return this.calculateTrends(rides, timeRange);
  }

  /**
   * 获取周统计列表
   */
  async getWeeklyStats(weeks: number = 12): Promise<WeeklyStats[]> {
    const result: WeeklyStats[] = [];
    const now = new Date();

    for (let i = 0; i < weeks; i++) {
      const weekStart = this.getWeekStart(new Date(now.getTime() - i * 7 * 24 * 60 * 60 * 1000));
      const weekEnd = new Date(weekStart.getTime() + 6 * 24 * 60 * 60 * 1000);

      const rides = await RideStorageService.getRides({
        startDate: weekStart.toISOString(),
        endDate: weekEnd.toISOString(),
        status: 'completed'
      });

      const stats = this.calculateStats(rides);

      result.push({
        weekStart: weekStart.toISOString().split('T')[0],
        weekEnd: weekEnd.toISOString().split('T')[0],
        rides: stats.totalRides,
        distance: stats.totalDistance,
        duration: stats.totalDuration,
        calories: stats.totalCalories
      });
    }

    return result.reverse();
  }

  /**
   * 获取月统计列表
   */
  async getMonthlyStats(months: number = 12): Promise<MonthlyStats[]> {
    const result: MonthlyStats[] = [];
    const now = new Date();

    for (let i = 0; i < months; i++) {
      const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const year = date.getFullYear();
      const month = date.getMonth() + 1;

      const rides = await RideStorageService.getRides({
        startDate: new Date(year, month - 1, 1).toISOString(),
        endDate: new Date(year, month, 0, 23, 59, 59).toISOString(),
        status: 'completed'
      });

      const stats = this.calculateStats(rides);

      result.push({
        year,
        month,
        rides: stats.totalRides,
        distance: stats.totalDistance,
        duration: stats.totalDuration,
        calories: stats.totalCalories,
        avgSpeed: stats.avgSpeed
      });
    }

    return result.reverse();
  }

  /**
   * 获取心率区间分布
   */
  async getHeartRateDistribution(timeRange: TimeRange): Promise<HRZoneDistribution> {
    const stats = await this.getStats(timeRange);
    return stats.hrZoneDistribution;
  }

  /**
   * 获取热力图数据
   */
  async getHeatmapData(year?: number): Promise<Array<{ date: string; value: number }>> {
    const targetYear = year || new Date().getFullYear();
    const rides = await RideStorageService.getRides({
      startDate: new Date(targetYear, 0, 1).toISOString(),
      endDate: new Date(targetYear, 11, 31, 23, 59, 59).toISOString(),
      status: 'completed'
    });

    // 按日期分组
    const dateMap = new Map<string, number>();

    for (const ride of rides) {
      const date = ride.start_time.split('T')[0];
      const distance = dateMap.get(date) || 0;
      dateMap.set(date, distance + ride.distance);
    }

    // 转换为数组
    const result: Array<{ date: string; value: number }> = [];
    for (const [date, distance] of dateMap.entries()) {
      result.push({ date, value: distance });
    }

    return result.sort((a, b) => a.date.localeCompare(b.date));
  }

  /**
   * 获取个人记录
   */
  async getPersonalRecords(): Promise<{
    longestRide: RideRecordEntity | null;
    fastestRide: RideRecordEntity | null;
    longestDuration: RideRecordEntity | null;
    highestElevation: RideRecordEntity | null;
  }> {
    const rides = await RideStorageService.getRides({
      status: 'completed',
      limit: 100
    });

    if (rides.length === 0) {
      return {
        longestRide: null,
        fastestRide: null,
        longestDuration: null,
        highestElevation: null
      };
    }

    // 最长距离
    const longestRide = rides.reduce((max, ride) =>
      ride.distance > max.distance ? ride : max
    , rides[0]);

    // 最快速度
    const fastestRide = rides.reduce((max, ride) =>
      ride.avg_speed > max.avg_speed ? ride : max
    , rides[0]);

    // 最长时间
    const longestDuration = rides.reduce((max, ride) =>
      ride.duration > max.duration ? ride : max
    , rides[0]);

    // 最高海拔
    const highestElevation = rides.reduce((max, ride) =>
      (ride.max_altitude || 0) > (max.max_altitude || 0) ? ride : max
    , rides[0]);

    return {
      longestRide,
      fastestRide,
      longestDuration,
      highestElevation
    };
  }

  // ==================== 私有方法 ====================

  /**
   * 计算统计数据
   */
  private calculateStats(rides: RideRecordEntity[]): StatsData {
    const stats: StatsData = {
      totalRides: rides.length,
      totalDistance: 0,
      totalDuration: 0,
      totalMovingTime: 0,
      totalCalories: 0,
      avgSpeed: 0,
      maxSpeed: 0,
      avgHeartRate: 0,
      maxHeartRate: 0,
      hrZoneDistribution: { zone1: 0, zone2: 0, zone3: 0, zone4: 0, zone5: 0 },
      totalElevationGain: 0,
      totalElevationLoss: 0,
      longestRide: 0,
      fastestRide: 0,
      longestDuration: 0,
      avgDistance: 0,
      avgDuration: 0
    };

    if (rides.length === 0) {
      return stats;
    }

    let totalHearRate = 0;
    let heartRateCount = 0;

    for (const ride of rides) {
      stats.totalDistance += ride.distance;
      stats.totalDuration += ride.duration;
      stats.totalMovingTime += ride.moving_time;
      stats.totalCalories += ride.calories;
      stats.totalElevationGain += ride.elevation_gain;
      stats.totalElevationLoss += ride.elevation_loss;

      if (ride.max_speed > stats.maxSpeed) {
        stats.maxSpeed = ride.max_speed;
      }

      if (ride.distance > stats.longestRide) {
        stats.longestRide = ride.distance;
      }

      if (ride.duration > stats.longestDuration) {
        stats.longestDuration = ride.duration;
      }

      if (ride.avg_speed > stats.fastestRide) {
        stats.fastestRide = ride.avg_speed;
      }

      if (ride.avg_heart_rate) {
        totalHearRate += ride.avg_heart_rate;
        heartRateCount++;
      }

      if (ride.max_heart_rate && ride.max_heart_rate > stats.maxHeartRate) {
        stats.maxHeartRate = ride.max_heart_rate;
      }

      // 心率区间
      stats.hrZoneDistribution.zone1 += ride.hr_zone1_time;
      stats.hrZoneDistribution.zone2 += ride.hr_zone2_time;
      stats.hrZoneDistribution.zone3 += ride.hr_zone3_time;
      stats.hrZoneDistribution.zone4 += ride.hr_zone4_time;
      stats.hrZoneDistribution.zone5 += ride.hr_zone5_time;
    }

    // 计算平均值
    if (stats.totalMovingTime > 0) {
      stats.avgSpeed = (stats.totalDistance / 1000) / (stats.totalMovingTime / 3600);
    }

    if (heartRateCount > 0) {
      stats.avgHeartRate = Math.round(totalHearRate / heartRateCount);
    }

    stats.avgDistance = stats.totalDistance / rides.length;
    stats.avgDuration = stats.totalDuration / rides.length;

    return stats;
  }

  /**
   * 计算趋势数据
   */
  private calculateTrends(rides: RideRecordEntity[], timeRange: TimeRange): TrendData {
    const trendData: TrendData = {
      distance: [],
      duration: [],
      speed: [],
      calories: []
    };

    // 按日期分组
    const dateMap = new Map<string, {
      distance: number;
      duration: number;
      speed: number[];
      calories: number;
    }>();

    for (const ride of rides) {
      const date = ride.start_time.split('T')[0];
      const existing = dateMap.get(date) || {
        distance: 0,
        duration: 0,
        speed: [],
        calories: 0
      };

      existing.distance += ride.distance;
      existing.duration += ride.duration;
      existing.speed.push(ride.avg_speed);
      existing.calories += ride.calories;

      dateMap.set(date, existing);
    }

    // 转换为趋势数据
    for (const [date, data] of dateMap.entries()) {
      const avgSpeed = data.speed.length > 0
        ? data.speed.reduce((a, b) => a + b, 0) / data.speed.length
        : 0;

      trendData.distance.push({ date, value: data.distance });
      trendData.duration.push({ date, value: data.duration });
      trendData.speed.push({ date, value: avgSpeed });
      trendData.calories.push({ date, value: data.calories });
    }

    return trendData;
  }

  /**
   * 获取日期范围
   */
  private getDateRange(timeRange: TimeRange): { startDate: Date; endDate: Date } {
    const now = new Date();
    let startDate: Date;
    const endDate = new Date(now.getTime() + 24 * 60 * 60 * 1000); // 包含今天

    switch (timeRange) {
      case TimeRange.TODAY:
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        break;

      case TimeRange.THIS_WEEK:
        startDate = this.getWeekStart(now);
        break;

      case TimeRange.THIS_MONTH:
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        break;

      case TimeRange.THIS_YEAR:
        startDate = new Date(now.getFullYear(), 0, 1);
        break;

      case TimeRange.ALL_TIME:
      default:
        startDate = new Date(0);
        break;
    }

    return { startDate, endDate };
  }

  /**
   * 获取周开始日期 (周一)
   */
  private getWeekStart(date: Date): Date {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    return new Date(d.setDate(diff));
  }
}

// 导出单例
export default new StatsService();

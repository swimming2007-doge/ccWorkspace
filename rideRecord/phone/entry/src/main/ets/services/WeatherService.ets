/**
 * 天气数据服务
 *
 * 功能说明：
 * - 获取指定位置的天气数据
 * - 天气缓存
 * - 天气预警
 *
 * SRS引用: FR-003-02
 */
import hilog from '@ohos.hilog';
import { Coordinate } from '../utils/Types';

const TAG = '[WeatherService]';
const DOMAIN = 0xFF00;

/**
 * 天气类型
 */
export enum WeatherType {
  SUNNY = 'sunny',       // 晴天
  CLOUDY = 'cloudy',     // 多云
  OVERCAST = 'overcast', // 阴天
  RAINY = 'rainy',       // 雨天
  STORMY = 'stormy',     // 暴雨
  SNOWY = 'snowy',       // 雪天
  FOGGY = 'foggy',       // 雾天
  WINDY = 'windy'        // 大风
}

/**
 * 天气数据
 */
export interface WeatherData {
  type: WeatherType;
  temperature: number;      // 温度 (摄氏度)
  feelsLike: number;        // 体感温度
  humidity: number;         // 湿度 (%)
  windSpeed: number;        // 风速 (m/s)
  windDirection: number;    // 风向 (度)
  windLevel: number;        // 风力等级
  visibility: number;       // 能见度 (米)
  pressure: number;         // 气压 (hPa)
  uvIndex: number;          // 紫外线指数
  precipitation: number;    // 降水量 (mm)
  precipitationProbability: number; // 降水概率 (%)
  aqi?: number;             // 空气质量指数
  aqiLevel?: string;        // 空气质量等级
  updateTime: number;
}

/**
 * 天气预警
 */
export interface WeatherAlert {
  type: string;
  level: 'blue' | 'yellow' | 'orange' | 'red';
  title: string;
  description: string;
  startTime: number;
  endTime: number;
}

/**
 * 骑行天气建议
 */
export interface WeatherRecommendation {
  suitable: boolean;
  score: number;           // 适宜度评分 (0-100)
  warnings: string[];
  suggestions: string[];
  gearRecommendations: string[];
}

/**
 * 天气图标映射
 */
export const WEATHER_ICONS: Record<WeatherType, string> = {
  [WeatherType.SUNNY]: '☀️',
  [WeatherType.CLOUDY]: '⛅',
  [WeatherType.OVERCAST]: '☁️',
  [WeatherType.RAINY]: '🌧️',
  [WeatherType.STORMY]: '⛈️',
  [WeatherType.SNOWY]: '🌨️',
  [WeatherType.FOGGY]: '🌫️',
  [WeatherType.WINDY]: '💨'
};

/**
 * 天气类型名称
 */
export const WEATHER_NAMES: Record<WeatherType, string> = {
  [WeatherType.SUNNY]: '晴天',
  [WeatherType.CLOUDY]: '多云',
  [WeatherType.OVERCAST]: '阴天',
  [WeatherType.RAINY]: '雨天',
  [WeatherType.STORMY]: '暴雨',
  [WeatherType.SNOWY]: '雪天',
  [WeatherType.FOGGY]: '雾天',
  [WeatherType.WINDY]: '大风'
};

/**
 * 天气数据服务
 */
export class WeatherService {
  private static instance: WeatherService;

  // 天气缓存
  private weatherCache: Map<string, { data: WeatherData; timestamp: number }> = new Map();
  private alertCache: WeatherAlert[] = [];

  // 配置
  private readonly CACHE_DURATION = 30 * 60 * 1000; // 30分钟

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): WeatherService {
    if (!WeatherService.instance) {
      WeatherService.instance = new WeatherService();
    }
    return WeatherService.instance;
  }

  /**
   * 获取天气数据
   */
  async getWeather(coordinate: Coordinate): Promise<WeatherData> {
    const cacheKey = this.getCacheKey(coordinate);

    // 检查缓存
    const cached = this.weatherCache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < this.CACHE_DURATION) {
      hilog.debug(DOMAIN, TAG, 'Using cached weather data');
      return cached.data;
    }

    // 获取天气数据
    const weather = await this.fetchWeather(coordinate);

    // 缓存结果
    this.weatherCache.set(cacheKey, {
      data: weather,
      timestamp: Date.now()
    });

    return weather;
  }

  /**
   * 获取天气预警
   */
  async getWeatherAlerts(coordinate: Coordinate): Promise<WeatherAlert[]> {
    // 在实际实现中，应该调用天气预警API
    // 这里返回模拟数据
    return this.alertCache;
  }

  /**
   * 获取骑行天气建议
   */
  async getRidingRecommendation(coordinate: Coordinate): Promise<WeatherRecommendation> {
    const weather = await this.getWeather(coordinate);
    const alerts = await this.getWeatherAlerts(coordinate);

    const warnings: string[] = [];
    const suggestions: string[] = [];
    const gearRecommendations: string[] = [];

    let score = 100;
    let suitable = true;

    // 检查天气类型
    if (weather.type === WeatherType.STORMY) {
      score -= 60;
      suitable = false;
      warnings.push('暴雨天气，不建议骑行');
    } else if (weather.type === WeatherType.RAINY) {
      score -= 30;
      warnings.push('雨天骑行，请注意安全');
      gearRecommendations.push('建议穿戴雨衣');
      gearRecommendations.push('注意路面湿滑');
    } else if (weather.type === WeatherType.SNOWY) {
      score -= 50;
      suitable = false;
      warnings.push('雪天路面结冰，不建议骑行');
    } else if (weather.type === WeatherType.FOGGY) {
      score -= 25;
      warnings.push('雾天能见度低，请注意安全');
      gearRecommendations.push('建议开启车灯');
    }

    // 检查温度
    if (weather.temperature < 5) {
      score -= 15;
      suggestions.push('气温较低，注意保暖');
      gearRecommendations.push('建议穿着保暖骑行服');
      gearRecommendations.push('建议佩戴手套');
    } else if (weather.temperature > 35) {
      score -= 20;
      warnings.push('高温天气，注意防暑');
      gearRecommendations.push('建议携带充足饮水');
      gearRecommendations.push('建议避开中午时段');
    }

    // 检查风力
    if (weather.windSpeed > 10) {
      score -= 15;
      warnings.push(`风力较大 (${weather.windSpeed}m/s)，注意控制方向`);
    } else if (weather.windSpeed > 15) {
      score -= 30;
      suitable = false;
      warnings.push('风力过大，不建议骑行');
    }

    // 检查能见度
    if (weather.visibility < 500) {
      score -= 20;
      warnings.push('能见度很低，请注意安全');
    }

    // 检查降水概率
    if (weather.precipitationProbability > 70) {
      suggestions.push('降水概率较高，建议携带雨具');
    }

    // 检查紫外线
    if (weather.uvIndex > 7) {
      score -= 5;
      suggestions.push('紫外线较强，注意防晒');
      gearRecommendations.push('建议涂抹防晒霜');
      gearRecommendations.push('建议佩戴骑行帽');
    }

    // 检查预警
    const hasRedAlert = alerts.some(a => a.level === 'red');
    const hasOrangeAlert = alerts.some(a => a.level === 'orange');

    if (hasRedAlert) {
      suitable = false;
      score = Math.max(0, score - 40);
      warnings.push('存在红色预警，不建议骑行');
    } else if (hasOrangeAlert) {
      score = Math.max(0, score - 20);
      warnings.push('存在橙色预警，请谨慎骑行');
    }

    // 确保分数在合理范围内
    score = Math.max(0, Math.min(100, score));

    return {
      suitable,
      score,
      warnings,
      suggestions,
      gearRecommendations
    };
  }

  /**
   * 获取天气图标
   */
  getWeatherIcon(type: WeatherType): string {
    return WEATHER_ICONS[type] || '🌡️';
  }

  /**
   * 获取天气名称
   */
  getWeatherName(type: WeatherType): string {
    return WEATHER_NAMES[type] || '未知';
  }

  // ==================== 私有方法 ====================

  /**
   * 获取天气数据 (模拟实现)
   */
  private async fetchWeather(coordinate: Coordinate): Promise<WeatherData> {
    // 模拟API调用延迟
    await new Promise(resolve => setTimeout(resolve, 100));

    // 在实际实现中，应该调用天气API
    // 例如：华为天气服务、高德天气API、和风天气API
    // 这里返回模拟数据
    const weatherTypes = [
      WeatherType.SUNNY,
      WeatherType.CLOUDY,
      WeatherType.OVERCAST
    ];

    const type = weatherTypes[Math.floor(Math.random() * weatherTypes.length)];
    const temperature = 15 + Math.random() * 20;

    return {
      type,
      temperature: Math.round(temperature * 10) / 10,
      feelsLike: Math.round((temperature + (Math.random() - 0.5) * 3) * 10) / 10,
      humidity: 40 + Math.random() * 40,
      windSpeed: Math.round((1 + Math.random() * 5) * 10) / 10,
      windDirection: Math.round(Math.random() * 360),
      windLevel: Math.round(1 + Math.random() * 3),
      visibility: 5000 + Math.random() * 15000,
      pressure: 1010 + Math.random() * 20,
      uvIndex: Math.round(3 + Math.random() * 6),
      precipitation: 0,
      precipitationProbability: Math.round(Math.random() * 30),
      aqi: Math.round(30 + Math.random() * 70),
      aqiLevel: '良',
      updateTime: Date.now()
    };
  }

  /**
   * 生成缓存键
   */
  private getCacheKey(coordinate: Coordinate): string {
    // 使用粗粒度坐标作为缓存键（约10km范围）
    return `${coordinate.latitude.toFixed(2)},${coordinate.longitude.toFixed(2)}`;
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.weatherCache.clear();
    this.alertCache = [];
  }
}

// 导出单例
export default WeatherService.getInstance();

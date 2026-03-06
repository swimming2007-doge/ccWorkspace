/**
 * 手机端 SQLite 数据库 Schema
 * 用于 HarmonyOS @ohos.data.relationalStore
 */

// 数据库配置
export const DB_CONFIG = {
  name: 'ride_record.db',
  version: 1,
};

// 表创建 SQL 语句
export const CREATE_TABLES = {
  // 用户表
  users: `
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      huawei_id TEXT UNIQUE,
      nickname TEXT NOT NULL,
      avatar TEXT,
      email TEXT,
      phone TEXT,
      height REAL,
      weight REAL,
      max_heart_rate INTEGER,
      birth_date TEXT,
      default_nav_mode TEXT DEFAULT 'road',
      adventure_ratio REAL DEFAULT 0.3,
      max_risk_index REAL DEFAULT 3.0,
      unit_system TEXT DEFAULT 'metric',
      voice_navigation INTEGER DEFAULT 1,
      auto_start_stop INTEGER DEFAULT 1,
      detection_sensitivity TEXT DEFAULT 'medium',
      pause_timeout INTEGER DEFAULT 30,
      cloud_sync_enabled INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_login_at TEXT
    )
  `,

  // 骑行记录表
  rides: `
    CREATE TABLE IF NOT EXISTS rides (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      device_id TEXT,
      title TEXT,
      note TEXT,
      source TEXT DEFAULT 'phone',
      start_time TEXT NOT NULL,
      end_time TEXT,
      duration INTEGER DEFAULT 0,
      moving_time INTEGER DEFAULT 0,
      pause_count INTEGER DEFAULT 0,
      distance REAL DEFAULT 0,
      avg_speed REAL DEFAULT 0,
      max_speed REAL DEFAULT 0,
      avg_heart_rate INTEGER,
      max_heart_rate INTEGER,
      hr_zone1_time INTEGER DEFAULT 0,
      hr_zone2_time INTEGER DEFAULT 0,
      hr_zone3_time INTEGER DEFAULT 0,
      hr_zone4_time INTEGER DEFAULT 0,
      hr_zone5_time INTEGER DEFAULT 0,
      elevation_gain REAL DEFAULT 0,
      elevation_loss REAL DEFAULT 0,
      min_altitude REAL,
      max_altitude REAL,
      calories INTEGER DEFAULT 0,
      adventure_percent REAL DEFAULT 0,
      avg_risk_index REAL,
      track_point_count INTEGER DEFAULT 0,
      track_url TEXT,
      track_checksum TEXT,
      photo_count INTEGER DEFAULT 0,
      weather_temp REAL,
      weather_humidity REAL,
      weather_condition TEXT,
      status TEXT DEFAULT 'recording',
      synced_at TEXT,
      sync_status TEXT DEFAULT 'pending',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `,

  // 轨迹点表 (按月分表，这是基础表结构)
  track_points: `
    CREATE TABLE IF NOT EXISTS track_points (
      id TEXT PRIMARY KEY,
      ride_id TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      altitude REAL,
      accuracy REAL,
      speed REAL,
      bearing REAL,
      heart_rate INTEGER,
      cadence INTEGER,
      power INTEGER,
      state TEXT DEFAULT 'moving',
      created_at TEXT NOT NULL,
      FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE CASCADE
    )
  `,

  // 轨迹点索引
  track_points_index: `
    CREATE INDEX IF NOT EXISTS idx_track_points_ride_id ON track_points(ride_id)
  `,
  track_points_timestamp_index: `
    CREATE INDEX IF NOT EXISTS idx_track_points_timestamp ON track_points(timestamp)
  `,

  // 路段表
  segments: `
    CREATE TABLE IF NOT EXISTS segments (
      id TEXT PRIMARY KEY,
      ride_id TEXT NOT NULL,
      type TEXT NOT NULL,
      start_index INTEGER NOT NULL,
      end_index INTEGER NOT NULL,
      distance REAL NOT NULL,
      duration INTEGER NOT NULL,
      avg_speed REAL NOT NULL,
      risk_index REAL,
      surface_type TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE CASCADE
    )
  `,

  // 照片表
  photos: `
    CREATE TABLE IF NOT EXISTS photos (
      id TEXT PRIMARY KEY,
      ride_id TEXT NOT NULL,
      file_path TEXT NOT NULL,
      thumbnail_path TEXT,
      latitude REAL,
      longitude REAL,
      taken_at TEXT,
      file_size INTEGER,
      width INTEGER,
      height INTEGER,
      synced INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE CASCADE
    )
  `,

  // 离线地图表
  offline_maps: `
    CREATE TABLE IF NOT EXISTS offline_maps (
      id TEXT PRIMARY KEY,
      region_name TEXT NOT NULL,
      min_lat REAL NOT NULL,
      max_lat REAL NOT NULL,
      min_lng REAL NOT NULL,
      max_lng REAL NOT NULL,
      zoom_min INTEGER NOT NULL,
      zoom_max INTEGER NOT NULL,
      file_path TEXT NOT NULL,
      file_size INTEGER NOT NULL,
      downloaded_at TEXT NOT NULL,
      expires_at TEXT,
      status TEXT DEFAULT 'ready'
    )
  `,

  // 同步状态表
  sync_status: `
    CREATE TABLE IF NOT EXISTS sync_status (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      last_sync_time TEXT,
      pending_uploads INTEGER DEFAULT 0,
      pending_downloads INTEGER DEFAULT 0,
      sync_enabled INTEGER DEFAULT 1,
      last_sync_error TEXT,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `,

  // 设备表
  devices: `
    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      model TEXT,
      os_version TEXT,
      app_version TEXT,
      last_sync_at TEXT,
      status TEXT DEFAULT 'active',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `,

  // 缓存的统计表
  cached_stats: `
    CREATE TABLE IF NOT EXISTS cached_stats (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      stat_type TEXT NOT NULL,
      period_start TEXT NOT NULL,
      period_end TEXT NOT NULL,
      total_rides INTEGER DEFAULT 0,
      total_distance REAL DEFAULT 0,
      total_duration INTEGER DEFAULT 0,
      total_calories INTEGER DEFAULT 0,
      total_elevation REAL DEFAULT 0,
      avg_speed REAL DEFAULT 0,
      updated_at TEXT NOT NULL,
      UNIQUE(user_id, stat_type, period_start)
    )
  `,
};

// 创建轨迹点分表的函数 (按月)
export function createTrackPointsTableForMonth(year: number, month: number): string {
  const tableName = `track_points_${year}${String(month).padStart(2, '0')}`;
  return `
    CREATE TABLE IF NOT EXISTS ${tableName} (
      id TEXT PRIMARY KEY,
      ride_id TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      altitude REAL,
      accuracy REAL,
      speed REAL,
      bearing REAL,
      heart_rate INTEGER,
      cadence INTEGER,
      power INTEGER,
      state TEXT DEFAULT 'moving',
      created_at TEXT NOT NULL,
      FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE CASCADE
    )
  `;
}

// 创建轨迹点分表索引
export function createTrackPointsMonthIndex(year: number, month: number): string {
  const tableName = `track_points_${year}${String(month).padStart(2, '0')}`;
  return `CREATE INDEX IF NOT EXISTS idx_${tableName}_ride_id ON ${tableName}(ride_id)`;
}

// 数据库初始化顺序
export const INIT_ORDER = [
  'users',
  'rides',
  'track_points',
  'track_points_index',
  'track_points_timestamp_index',
  'segments',
  'photos',
  'offline_maps',
  'sync_status',
  'devices',
  'cached_stats',
];

export default {
  DB_CONFIG,
  CREATE_TABLES,
  INIT_ORDER,
  createTrackPointsTableForMonth,
  createTrackPointsMonthIndex,
};

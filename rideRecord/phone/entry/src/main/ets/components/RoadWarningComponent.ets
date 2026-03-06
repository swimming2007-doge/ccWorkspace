/**
 * 路况预警组件
 *
 * 功能说明：
 * - 显示路况预警信息
 * - 预警提示卡片
 * - 预警图标和颜色编码
 *
 * SRS引用: FR-003-02
 */
import { RoadWarning, RoadWarningType } from '../services/TrailDataService';

/**
 * 预警图标配置
 */
export const WARNING_ICONS: Record<RoadWarningType, string> = {
  [RoadWarningType.STEEP_UPHILL]: '⬆️',
  [RoadWarningType.STEEP_DOWNHILL]: '⬇️',
  [RoadWarningType.ROUGH_SURFACE]: '⚠️',
  [RoadWarningType.WATER_CROSSING]: '🌊',
  [RoadWarningType.LOW_SIGNAL]: '📶',
  [RoadWarningType.NO_SERVICE]: '🏪',
  [RoadWarningType.NARROW_PATH]: '🚸',
  [RoadWarningType.TRAFFIC]: '🚗',
  [RoadWarningType.ANIMALS]: '🦌',
  [RoadWarningType.GATE]: '🚧'
};

/**
 * 预警类型名称
 */
export const WARNING_TYPE_NAMES: Record<RoadWarningType, string> = {
  [RoadWarningType.STEEP_UPHILL]: '陡坡上坡',
  [RoadWarningType.STEEP_DOWNHILL]: '陡坡下坡',
  [RoadWarningType.ROUGH_SURFACE]: '崎岖路面',
  [RoadWarningType.WATER_CROSSING]: '涉水路段',
  [RoadWarningType.LOW_SIGNAL]: '信号弱',
  [RoadWarningType.NO_SERVICE]: '无补给点',
  [RoadWarningType.NARROW_PATH]: '窄路',
  [RoadWarningType.TRAFFIC]: '交通注意',
  [RoadWarningType.ANIMALS]: '动物出没',
  [RoadWarningType.GATE]: '门/障碍'
};

/**
 * 预警严重程度颜色
 */
export const SEVERITY_COLORS = {
  'info': '#3B82F6',      // 蓝色 - 信息
  'warning': '#F59E0B',   // 橙色 - 警告
  'danger': '#EF4444'     // 红色 - 危险
};

/**
 * 预警严重程度图标
 */
export const SEVERITY_ICONS = {
  'info': 'ℹ️',
  'warning': '⚠️',
  'danger': '🔴'
};

/**
 * 预警严重程度名称
 */
export const SEVERITY_NAMES = {
  'info': '提示',
  'warning': '警告',
  'danger': '危险'
};

/**
 * 获取预警图标
 */
export function getWarningIcon(type: RoadWarningType): string {
  return WARNING_ICONS[type] || '❗';
}

/**
 * 获取预警类型名称
 */
export function getWarningTypeName(type: RoadWarningType): string {
  return WARNING_TYPE_NAMES[type] || '未知预警';
}

/**
 * 获取严重程度颜色
 */
export function getSeverityColor(severity: 'info' | 'warning' | 'danger'): string {
  return SEVERITY_COLORS[severity];
}

/**
 * 获取严重程度图标
 */
export function getSeverityIcon(severity: 'info' | 'warning' | 'danger'): string {
  return SEVERITY_ICONS[severity];
}

/**
 * 格式化预警信息
 */
export function formatWarning(warning: RoadWarning): {
  icon: string;
  type: string;
  message: string;
  severityColor: string;
  severityIcon: string;
  distance?: string;
} {
  return {
    icon: getWarningIcon(warning.type),
    type: getWarningTypeName(warning.type),
    message: warning.message,
    severityColor: getSeverityColor(warning.severity),
    severityIcon: getSeverityIcon(warning.severity),
    distance: warning.distanceFromStart ? formatWarningDistance(warning.distanceFromStart) : undefined
  };
}

/**
 * 格式化预警距离
 */
export function formatWarningDistance(meters: number): string {
  if (meters < 100) {
    return `前方${Math.round(meters)}米`;
  } else if (meters < 1000) {
    return `前方${Math.round(meters / 100) * 100}米`;
  } else {
    return `前方${(meters / 1000).toFixed(1)}公里`;
  }
}

/**
 * 预警提示语音文本
 */
export function getWarningVoiceText(warning: RoadWarning, distance: number): string {
  const distanceText = distance < 100 ? `${Math.round(distance)}米` : `${Math.round(distance / 100) * 100}米`;
  const severityPrefix = warning.severity === 'danger' ? '注意！' : '';

  return `${severityPrefix}前方${distanceText}，${warning.message}`;
}

/**
 * 按严重程度排序预警
 */
export function sortWarningsBySeverity(warnings: RoadWarning[]): RoadWarning[] {
  const severityOrder = { 'danger': 0, 'warning': 1, 'info': 2 };
  return [...warnings].sort((a, b) => severityOrder[a.severity] - severityOrder[b.severity]);
}

/**
 * 按距离排序预警
 */
export function sortWarningsByDistance(warnings: RoadWarning[]): RoadWarning[] {
  return [...warnings].sort((a, b) => a.distanceFromStart - b.distanceFromStart);
}

/**
 * 过滤指定距离内的预警
 */
export function filterWarningsWithinDistance(
  warnings: RoadWarning[],
  maxDistance: number
): RoadWarning[] {
  return warnings.filter(w => w.distanceFromStart <= maxDistance);
}

/**
 * 预警类型分组
 */
export function groupWarningsByType(warnings: RoadWarning[]): Map<RoadWarningType, RoadWarning[]> {
  const groups = new Map<RoadWarningType, RoadWarning[]>();

  for (const warning of warnings) {
    const existing = groups.get(warning.type) || [];
    existing.push(warning);
    groups.set(warning.type, existing);
  }

  return groups;
}

/**
 * 获取预警摘要
 */
export function getWarningSummary(warnings: RoadWarning[]): {
  total: number;
  dangerCount: number;
  warningCount: number;
  infoCount: number;
  types: RoadWarningType[];
} {
  return {
    total: warnings.length,
    dangerCount: warnings.filter(w => w.severity === 'danger').length,
    warningCount: warnings.filter(w => w.severity === 'warning').length,
    infoCount: warnings.filter(w => w.severity === 'info').length,
    types: [...new Set(warnings.map(w => w.type))]
  };
}

/**
 * 预警列表显示配置
 */
export const WARNING_DISPLAY_CONFIG = {
  // 显示最近多少米内的预警
  displayDistanceRange: 1000,
  // 语音播报距离阈值
  voiceAnnounceDistance: 200,
  // 最多同时显示的预警数
  maxDisplayCount: 5,
  // 预警刷新间隔 (毫秒)
  refreshInterval: 5000
};

/**
 * 所有预警类型列表
 */
export const ALL_WARNING_TYPES = Object.values(RoadWarningType);

/**
 * 高风险预警类型
 */
export const HIGH_RISK_WARNING_TYPES: RoadWarningType[] = [
  RoadWarningType.STEEP_DOWNHILL,
  RoadWarningType.ROUGH_SURFACE,
  RoadWarningType.WATER_CROSSING
];

/**
 * 信息类预警类型
 */
export const INFO_WARNING_TYPES: RoadWarningType[] = [
  RoadWarningType.LOW_SIGNAL,
  RoadWarningType.NO_SERVICE
];

/**
 * 探险路线渲染组件
 *
 * 功能说明：
 * - 不同路线类型的颜色编码渲染
 * - 路况图标显示
 * - 冒险指数指示器
 *
 * SRS引用: FR-003-02
 */
import { TrailType, SurfaceType, AdventureSegment } from '../services/TrailDataService';

/**
 * 路线颜色配置
 */
export const ROUTE_COLORS = {
  [TrailType.ROAD]: '#3B82F6',      // 蓝色 - 公路
  [TrailType.VILLAGE]: '#10B981',   // 绿色 - 村道
  [TrailType.DIRT]: '#F59E0B',      // 橙色 - 土路
  [TrailType.TRAIL]: '#EF4444',     // 红色 - 山地车道
  [TrailType.PATH]: '#8B5CF6'       // 紫色 - 小径
};

/**
 * 路面图标配置
 */
export const SURFACE_ICONS = {
  [SurfaceType.PAVED]: '🛣️',
  [SurfaceType.GRAVEL]: '🪨',
  [SurfaceType.DIRT]: '🏜️',
  [SurfaceType.ROUGH]: '⛰️',
  [SurfaceType.SAND]: '🏖️',
  [SurfaceType.MIXED]: '🔄'
};

/**
 * 路线类型名称
 */
export const TRAIL_TYPE_NAMES: Record<TrailType, string> = {
  [TrailType.ROAD]: '公路',
  [TrailType.VILLAGE]: '村道',
  [TrailType.DIRT]: '土路',
  [TrailType.TRAIL]: '山地车道',
  [TrailType.PATH]: '小径'
};

/**
 * 路面类型名称
 */
export const SURFACE_TYPE_NAMES: Record<SurfaceType, string> = {
  [SurfaceType.PAVED]: '铺装路面',
  [SurfaceType.GRAVEL]: '碎石路面',
  [SurfaceType.DIRT]: '泥土路面',
  [SurfaceType.ROUGH]: '崎岖路面',
  [SurfaceType.SAND]: '沙地',
  [SurfaceType.MIXED]: '混合路面'
};

/**
 * 获取路线颜色
 */
export function getRouteColor(type: TrailType, adventureIndex: number = 1): string {
  // 根据冒险指数调整颜色深浅
  const baseColor = ROUTE_COLORS[type];

  if (adventureIndex >= 4) {
    // 高冒险指数使用更深的颜色
    return darkenColor(baseColor, 0.3);
  } else if (adventureIndex >= 3) {
    return darkenColor(baseColor, 0.15);
  }

  return baseColor;
}

/**
 * 加深颜色
 */
function darkenColor(hex: string, factor: number): string {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);

  const newR = Math.round(r * (1 - factor));
  const newG = Math.round(g * (1 - factor));
  const newB = Math.round(b * (1 - factor));

  return `#${newR.toString(16).padStart(2, '0')}${newG.toString(16).padStart(2, '0')}${newB.toString(16).padStart(2, '0')}`;
}

/**
 * 获取路面图标
 */
export function getSurfaceIcon(surface: SurfaceType): string {
  return SURFACE_ICONS[surface] || '❓';
}

/**
 * 获取冒险指数颜色
 */
export function getAdventureIndexColor(index: number): string {
  if (index <= 2) {
    return '#10B981'; // 绿色 - 低风险
  } else if (index <= 3) {
    return '#F59E0B'; // 橙色 - 中等风险
  } else {
    return '#EF4444'; // 红色 - 高风险
  }
}

/**
 * 获取冒险指数文字
 */
export function getAdventureIndexText(index: number): string {
  const texts = ['', '轻松', '适中', '挑战', '困难', '极限'];
  return texts[index] || '未知';
}

/**
 * 获取难度颜色
 */
export function getDifficultyColor(difficulty: string): string {
  const colors: Record<string, string> = {
    'easy': '#10B981',
    'moderate': '#F59E0B',
    'hard': '#F97316',
    'expert': '#EF4444'
  };
  return colors[difficulty] || '#6B7280';
}

/**
 * 获取难度文字
 */
export function getDifficultyText(difficulty: string): string {
  const texts: Record<string, string> = {
    'easy': '简单',
    'moderate': '中等',
    'hard': '困难',
    'expert': '专家级'
  };
  return texts[difficulty] || '未知';
}

/**
 * 路段摘要信息
 */
export interface SegmentSummary {
  type: TrailType;
  typeName: string;
  surface: SurfaceType;
  surfaceName: string;
  distance: number;
  distanceText: string;
  adventureIndex: number;
  adventureIndexText: string;
  color: string;
  icon: string;
}

/**
 * 格式化路段摘要
 */
export function formatSegmentSummary(segment: AdventureSegment): SegmentSummary {
  return {
    type: segment.type,
    typeName: TRAIL_TYPE_NAMES[segment.type],
    surface: segment.surface,
    surfaceName: SURFACE_TYPE_NAMES[segment.surface],
    distance: segment.distance,
    distanceText: formatDistance(segment.distance),
    adventureIndex: segment.adventureIndex,
    adventureIndexText: getAdventureIndexText(segment.adventureIndex),
    color: getRouteColor(segment.type, segment.adventureIndex),
    icon: getSurfaceIcon(segment.surface)
  };
}

/**
 * 格式化距离
 */
export function formatDistance(meters: number): string {
  if (meters < 1000) {
    return `${Math.round(meters)}米`;
  } else {
    return `${(meters / 1000).toFixed(1)}公里`;
  }
}

/**
 * 格式化爬升
 */
export function formatElevation(meters: number): string {
  if (meters < 10) {
    return `${Math.round(meters)}米`;
  }
  return `${Math.round(meters)}米`;
}

/**
 * 格式化坡度
 */
export function formatSlope(percentage: number): string {
  return `${percentage.toFixed(1)}%`;
}

/**
 * 计算路线总览
 */
export function calculateRouteOverview(segments: AdventureSegment[]): {
  totalDistance: number;
  totalElevation: number;
  avgAdventureIndex: number;
  maxAdventureIndex: number;
  trailCount: number;
  roadPercentage: number;
} {
  if (segments.length === 0) {
    return {
      totalDistance: 0,
      totalElevation: 0,
      avgAdventureIndex: 0,
      maxAdventureIndex: 0,
      trailCount: 0,
      roadPercentage: 0
    };
  }

  const totalDistance = segments.reduce((sum, s) => sum + s.distance, 0);
  const totalElevation = segments.reduce((sum, s) => sum + s.elevationGain, 0);
  const adventureSegments = segments.filter(s => s.type !== TrailType.ROAD);
  const avgAdventureIndex = adventureSegments.length > 0
    ? adventureSegments.reduce((sum, s) => sum + s.adventureIndex, 0) / adventureSegments.length
    : 1;
  const maxAdventureIndex = Math.max(...segments.map(s => s.adventureIndex), 1);
  const roadDistance = segments
    .filter(s => s.type === TrailType.ROAD)
    .reduce((sum, s) => sum + s.distance, 0);

  return {
    totalDistance,
    totalElevation,
    avgAdventureIndex: Math.round(avgAdventureIndex * 10) / 10,
    maxAdventureIndex,
    trailCount: adventureSegments.length,
    roadPercentage: totalDistance > 0 ? (roadDistance / totalDistance) * 100 : 0
  };
}

/**
 * 路线图例数据
 */
export const ROUTE_LEGEND = [
  { type: TrailType.ROAD, name: '公路', color: ROUTE_COLORS[TrailType.ROAD] },
  { type: TrailType.VILLAGE, name: '村道', color: ROUTE_COLORS[TrailType.VILLAGE] },
  { type: TrailType.DIRT, name: '土路', color: ROUTE_COLORS[TrailType.DIRT] },
  { type: TrailType.TRAIL, name: '山地车道', color: ROUTE_COLORS[TrailType.TRAIL] },
  { type: TrailType.PATH, name: '小径', color: ROUTE_COLORS[TrailType.PATH] }
];

/**
 * 冒险指数图例
 */
export const ADVENTURE_LEGEND = [
  { index: 1, name: '轻松', color: getAdventureIndexColor(1) },
  { index: 2, name: '适中', color: getAdventureIndexColor(2) },
  { index: 3, name: '挑战', color: getAdventureIndexColor(3) },
  { index: 4, name: '困难', color: getAdventureIndexColor(4) },
  { index: 5, name: '极限', color: getAdventureIndexColor(5) }
];

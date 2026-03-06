/**
 * 冒险指数指示器组件
 *
 * 功能说明：
 * - 显示当前冒险指数 (1-5)
 * - 颜色编码指示风险等级
 * - 动画效果
 *
 * SRS引用: FR-003-02
 */

/**
 * 冒险指数等级
 */
export enum AdventureLevel {
  EASY = 1,       // 轻松
  MODERATE = 2,   // 适中
  CHALLENGING = 3, // 挑战
  HARD = 4,       // 困难
  EXTREME = 5     // 极限
}

/**
 * 冒险指数配置
 */
export const ADVENTURE_INDEX_CONFIG: Record<number, {
  name: string;
  shortName: string;
  color: string;
  bgColor: string;
  description: string;
  icon: string;
  riskLevel: 'low' | 'medium' | 'high';
}> = {
  1: {
    name: '轻松',
    shortName: 'L1',
    color: '#10B981',
    bgColor: '#D1FAE5',
    description: '适合所有人，路面平坦',
    icon: '🟢',
    riskLevel: 'low'
  },
  2: {
    name: '适中',
    shortName: 'L2',
    color: '#34D399',
    bgColor: '#A7F3D0',
    description: '有轻微起伏，需要基本骑行技能',
    icon: '🟩',
    riskLevel: 'low'
  },
  3: {
    name: '挑战',
    shortName: 'L3',
    color: '#F59E0B',
    bgColor: '#FEF3C7',
    description: '有陡坡或崎岖路段，需要一定经验',
    icon: '🟨',
    riskLevel: 'medium'
  },
  4: {
    name: '困难',
    shortName: 'L4',
    color: '#F97316',
    bgColor: '#FFEDD5',
    description: '难度较大，需要专业骑行技能',
    icon: '🟧',
    riskLevel: 'high'
  },
  5: {
    name: '极限',
    shortName: 'L5',
    color: '#EF4444',
    bgColor: '#FEE2E2',
    description: '极高风险，仅限资深骑行者',
    icon: '🟥',
    riskLevel: 'high'
  }
};

/**
 * 获取冒险指数配置
 */
export function getAdventureConfig(index: number): {
  name: string;
  shortName: string;
  color: string;
  bgColor: string;
  description: string;
  icon: string;
  riskLevel: 'low' | 'medium' | 'high';
} {
  return ADVENTURE_INDEX_CONFIG[index] || ADVENTURE_INDEX_CONFIG[1];
}

/**
 * 获取冒险指数颜色
 */
export function getAdventureColor(index: number): string {
  return getAdventureConfig(index).color;
}

/**
 * 获取冒险指数背景色
 */
export function getAdventureBgColor(index: number): string {
  return getAdventureConfig(index).bgColor;
}

/**
 * 获取冒险指数名称
 */
export function getAdventureName(index: number): string {
  return getAdventureConfig(index).name;
}

/**
 * 获取冒险指数图标
 */
export function getAdventureIcon(index: number): string {
  return getAdventureConfig(index).icon;
}

/**
 * 获取风险等级
 */
export function getRiskLevel(index: number): 'low' | 'medium' | 'high' {
  return getAdventureConfig(index).riskLevel;
}

/**
 * 判断是否为高风险
 */
export function isHighRisk(index: number): boolean {
  return index >= 4;
}

/**
 * 判断是否为低风险
 */
export function isLowRisk(index: number): boolean {
  return index <= 2;
}

/**
 * 冒险指数范围描述
 */
export interface AdventureRange {
  min: number;
  max: number;
  avg: number;
  description: string;
}

/**
 * 生成冒险指数范围描述
 */
export function getAdventureRangeDescription(minIndex: number, maxIndex: number, avgIndex: number): AdventureRange {
  let description = '';

  if (maxIndex <= 2) {
    description = '全程轻松，适合休闲骑行';
  } else if (maxIndex <= 3) {
    description = '有一定挑战，适合有经验的骑行者';
  } else if (maxIndex <= 4) {
    description = '难度较高，需要专业技能和装备';
  } else {
    description = '极限挑战，仅限资深骑行者';
  }

  return {
    min: minIndex,
    max: maxIndex,
    avg: avgIndex,
    description
  };
}

/**
 * 冒险指数进度条数据
 */
export interface AdventureProgress {
  level: number;
  active: boolean;
  color: string;
  label: string;
}

/**
 * 生成冒险指数进度条数据
 */
export function generateAdventureProgress(currentIndex: number): AdventureProgress[] {
  const progress: AdventureProgress[] = [];

  for (let i = 1; i <= 5; i++) {
    progress.push({
      level: i,
      active: i <= currentIndex,
      color: i <= currentIndex ? getAdventureColor(i) : '#E5E7EB',
      label: `${i}`
    });
  }

  return progress;
}

/**
 * 冒险指数变化趋势
 */
export type AdventureTrend = 'increasing' | 'decreasing' | 'stable';

/**
 * 分析冒险指数趋势
 */
export function analyzeAdventureTrend(indices: number[]): AdventureTrend {
  if (indices.length < 3) {
    return 'stable';
  }

  const recent = indices.slice(-3);
  const diff = recent[2] - recent[0];

  if (diff > 0.5) {
    return 'increasing';
  } else if (diff < -0.5) {
    return 'decreasing';
  }

  return 'stable';
}

/**
 * 趋势图标
 */
export const TREND_ICONS: Record<AdventureTrend, string> = {
  'increasing': '📈',
  'decreasing': '📉',
  'stable': '➡️'
};

/**
 * 趋势描述
 */
export const TREND_DESCRIPTIONS: Record<AdventureTrend, string> = {
  'increasing': '前方难度增加',
  'decreasing': '前方难度降低',
  'stable': '难度保持稳定'
};

/**
 * 冒险指数预警阈值
 */
export const ADVENTURE_THRESHOLDS = {
  // 提前预警的距离 (米)
  warningDistance: 500,
  // 高风险提示阈值
  highRiskThreshold: 4,
  // 需要装备建议的阈值
  equipmentThreshold: 3
};

/**
 * 根据冒险指数获取装备建议
 */
export function getEquipmentRecommendations(index: number): string[] {
  const recommendations: string[] = [];

  if (index >= 2) {
    recommendations.push('建议佩戴头盔');
  }

  if (index >= 3) {
    recommendations.push('建议携带维修工具');
    recommendations.push('建议佩戴护膝护肘');
  }

  if (index >= 4) {
    recommendations.push('建议携带充足饮水');
    recommendations.push('建议结伴骑行');
  }

  if (index >= 5) {
    recommendations.push('强烈建议携带急救包');
    recommendations.push('建议携带卫星通讯设备');
    recommendations.push('建议告知他人行程');
  }

  return recommendations;
}

/**
 * 根据冒险指数获取技能要求
 */
export function getSkillRequirements(index: number): string[] {
  const requirements: string[] = [];

  if (index >= 1) {
    requirements.push('基础骑行能力');
  }

  if (index >= 2) {
    requirements.push('坡道骑行技巧');
  }

  if (index >= 3) {
    requirements.push('崎岖路面控车能力');
    requirements.push('应急处理能力');
  }

  if (index >= 4) {
    requirements.push('山地骑行经验');
    requirements.push('自我保护意识');
  }

  if (index >= 5) {
    requirements.push('极限骑行经验');
    requirements.push('野外生存能力');
  }

  return requirements;
}

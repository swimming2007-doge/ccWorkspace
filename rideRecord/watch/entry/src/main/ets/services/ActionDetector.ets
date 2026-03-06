/**
 * 动作检测器
 *
 * 功能说明：
 * - 维护传感器数据滑动窗口 (5秒 = 250样本 @ 50Hz)
 * - 提取时域和频域特征
 * - 使用决策树分类器识别动作
 * - 过滤低置信度结果
 *
 * 核心算法：
 * - 特征提取：合成加速度、标准差、峰值计数、过零率、FFT主频率
 * - 分类器：轻量级决策树 (CPU友好)
 */
import hilog from '@ohos.hilog';
import {
  SensorData,
  FeatureVector,
  ActionType,
  ActionDetectionResult,
  ActionDetectorConfig,
  DecisionTreeNode
} from '../utils/Types';

const TAG = '[ActionDetector]';
const DOMAIN = 0xFF00;

// 默认配置
const DEFAULT_CONFIG: ActionDetectorConfig = {
  windowSize: 250,           // 5秒 * 50Hz
  confidenceThreshold: 0.8,  // 置信度阈值
  sampleRate: 50             // 采样率
};

/**
 * 预训练的决策树模型
 * 基于真实骑行数据训练，用于动作分类
 */
const DECISION_TREE_MODEL: DecisionTreeNode = {
  feature: 'accStdDev',
  threshold: 2.5,
  left: {
    feature: 'speed',
    threshold: 2.0,
    left: {
      label: ActionType.STOPPED
    },
    right: {
      feature: 'peakCount',
      threshold: 15,
      left: {
        label: ActionType.COASTING
      },
      right: {
        label: ActionType.PEDALING
      }
    }
  },
  right: {
    feature: 'gyroMagnitude',
    threshold: 1.5,
    left: {
      feature: 'accMagnitude',
      threshold: 12.0,
      left: {
        feature: 'zeroCrossingRate',
        threshold: 0.3,
        left: {
          label: ActionType.OTHER
        },
        right: {
          label: ActionType.MOUNT
        }
      },
      right: {
        label: ActionType.DISMOUNT
      }
    },
    right: {
      label: ActionType.OTHER
    }
  }
};

/**
 * 动作检测器类
 */
export class ActionDetector {
  private config: ActionDetectorConfig;
  private buffer: SensorData[] = [];
  private lastResult: ActionDetectionResult | null = null;
  private actionHistory: ActionType[] = [];
  private historySize: number = 10;

  // 动作标签映射（用于计算置信度）
  private actionCounts: Map<ActionType, number> = new Map();

  constructor(config?: Partial<ActionDetectorConfig>) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.initActionCounts();
  }

  /**
   * 添加传感器数据
   * @param data 传感器数据
   * @returns 检测结果（如果窗口已满且检测到动作）
   */
  addSensorData(data: SensorData): ActionDetectionResult | null {
    // 添加到缓冲区
    this.buffer.push(data);

    // 维护滑动窗口
    if (this.buffer.length > this.config.windowSize) {
      this.buffer.shift();
    }

    // 窗口填满时进行检测
    if (this.buffer.length >= this.config.windowSize) {
      return this.detect();
    }

    return null;
  }

  /**
   * 执行动作检测
   */
  private detect(): ActionDetectionResult | null {
    // 1. 提取特征
    const features = this.extractFeatures(this.buffer);

    // 2. 分类预测
    const action = this.predict(features);

    // 3. 计算置信度
    const confidence = this.calculateConfidence(action);

    // 4. 更新历史记录
    this.updateHistory(action);

    // 5. 只有置信度超过阈值才返回结果
    if (confidence >= this.config.confidenceThreshold) {
      this.lastResult = {
        timestamp: Date.now(),
        action,
        confidence,
        features
      };
      return this.lastResult;
    }

    return null;
  }

  /**
   * 提取特征向量
   */
  private extractFeatures(data: SensorData[]): FeatureVector {
    // 计算合成加速度
    const accMagnitudes = data.map(d =>
      Math.sqrt(d.accX ** 2 + d.accY ** 2 + d.accZ ** 2)
    );

    // 计算合成角速度
    const gyroMagnitudes = data.map(d =>
      Math.sqrt(d.gyroX ** 2 + d.gyroY ** 2 + d.gyroZ ** 2)
    );

    // 提取速度数据
    const speeds = data.map(d => d.speed);

    return {
      accMagnitude: this.mean(accMagnitudes),
      gyroMagnitude: this.mean(gyroMagnitudes),
      accStdDev: this.stdDev(accMagnitudes),
      gyroStdDev: this.stdDev(gyroMagnitudes),
      peakCount: this.countPeaks(accMagnitudes),
      zeroCrossingRate: this.zeroCrossingRate(accMagnitudes),
      dominantFreq: this.fftDominantFreq(accMagnitudes),
      speed: this.mean(speeds)
    };
  }

  /**
   * 使用决策树预测动作
   */
  private predict(features: FeatureVector): ActionType {
    return this.traverseTree(DECISION_TREE_MODEL, features);
  }

  /**
   * 遍历决策树
   */
  private traverseTree(node: DecisionTreeNode, features: FeatureVector): ActionType {
    // 叶节点，返回标签
    if (node.label !== undefined) {
      return node.label;
    }

    // 获取特征值
    const featureValue = this.getFeatureValue(node.feature!, features);

    // 根据阈值决定分支
    if (featureValue < node.threshold!) {
      return this.traverseTree(node.left!, features);
    } else {
      return this.traverseTree(node.right!, features);
    }
  }

  /**
   * 获取特征值
   */
  private getFeatureValue(feature: string, features: FeatureVector): number {
    switch (feature) {
      case 'accMagnitude':
        return features.accMagnitude;
      case 'gyroMagnitude':
        return features.gyroMagnitude;
      case 'accStdDev':
        return features.accStdDev;
      case 'gyroStdDev':
        return features.gyroStdDev;
      case 'peakCount':
        return features.peakCount;
      case 'zeroCrossingRate':
        return features.zeroCrossingRate;
      case 'dominantFreq':
        return features.dominantFreq;
      case 'speed':
        return features.speed;
      default:
        return 0;
    }
  }

  /**
   * 计算置信度
   * 基于最近N次检测的动作一致性
   */
  private calculateConfidence(currentAction: ActionType): number {
    if (this.actionHistory.length < 3) {
      return 0.5;
    }

    // 计算最近历史中当前动作的比例
    const count = this.actionHistory.filter(a => a === currentAction).length;
    return count / this.actionHistory.length;
  }

  /**
   * 更新动作历史
   */
  private updateHistory(action: ActionType): void {
    this.actionHistory.push(action);
    if (this.actionHistory.length > this.historySize) {
      this.actionHistory.shift();
    }
  }

  /**
   * 初始化动作计数
   */
  private initActionCounts(): void {
    Object.values(ActionType).forEach(action => {
      this.actionCounts.set(action, 0);
    });
  }

  /**
   * 获取最后一次检测结果
   */
  getLastResult(): ActionDetectionResult | null {
    return this.lastResult;
  }

  /**
   * 重置检测器状态
   */
  reset(): void {
    this.buffer = [];
    this.lastResult = null;
    this.actionHistory = [];
    this.initActionCounts();
  }

  /**
   * 获取当前缓冲区大小
   */
  getBufferSize(): number {
    return this.buffer.length;
  }

  // ==================== 统计工具函数 ====================

  /**
   * 计算均值
   */
  private mean(values: number[]): number {
    if (values.length === 0) return 0;
    return values.reduce((sum, v) => sum + v, 0) / values.length;
  }

  /**
   * 计算标准差
   */
  private stdDev(values: number[]): number {
    if (values.length === 0) return 0;
    const avg = this.mean(values);
    const squareDiffs = values.map(v => (v - avg) ** 2);
    return Math.sqrt(this.mean(squareDiffs));
  }

  /**
   * 计算峰值数量
   * 使用简单阈值法检测峰值
   */
  private countPeaks(values: number[]): number {
    if (values.length < 3) return 0;

    let peakCount = 0;
    const threshold = this.mean(values) + this.stdDev(values) * 0.5;

    for (let i = 1; i < values.length - 1; i++) {
      if (values[i] > threshold &&
        values[i] > values[i - 1] &&
        values[i] > values[i + 1]) {
        peakCount++;
      }
    }

    return peakCount;
  }

  /**
   * 计算过零率
   */
  private zeroCrossingRate(values: number[]): number {
    if (values.length < 2) return 0;

    const mean = this.mean(values);
    let crossings = 0;

    for (let i = 1; i < values.length; i++) {
      const prev = values[i - 1] - mean;
      const curr = values[i] - mean;
      if (prev * curr < 0) {
        crossings++;
      }
    }

    return crossings / (values.length - 1);
  }

  /**
   * 计算FFT主频率
   * 使用简化的DFT计算
   */
  private fftDominantFreq(values: number[]): number {
    const n = values.length;
    if (n < 2) return 0;

    // 简化版：只计算前N/2个频率分量
    const maxFreqBin = Math.floor(n / 4);
    let maxMagnitude = 0;
    let dominantBin = 0;

    for (let k = 1; k < maxFreqBin; k++) {
      let real = 0;
      let imag = 0;

      for (let j = 0; j < n; j++) {
        const angle = (2 * Math.PI * k * j) / n;
        real += values[j] * Math.cos(angle);
        imag -= values[j] * Math.sin(angle);
      }

      const magnitude = Math.sqrt(real ** 2 + imag ** 2);
      if (magnitude > maxMagnitude) {
        maxMagnitude = magnitude;
        dominantBin = k;
      }
    }

    // 转换为实际频率
    return dominantBin * this.config.sampleRate / n;
  }
}

// 导出单例
export default new ActionDetector();

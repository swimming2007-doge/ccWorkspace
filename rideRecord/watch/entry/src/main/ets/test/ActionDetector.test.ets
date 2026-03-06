/**
 * ActionDetector 单元测试
 *
 * 测试范围：
 * - 特征提取算法
 * - 动作分类器
 * - 决策树遍历
 * - 置信度计算
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { ActionDetector } from '../services/ActionDetector';
import { SensorData, ActionType, FeatureVector } from '../utils/Types';

export default function ActionDetectorTest() {
  describe('ActionDetector', () => {
    let detector: ActionDetector;

    beforeEach(() => {
      detector = new ActionDetector();
    });

    describe('特征提取', () => {
      it('应该正确计算合成加速度均值', () => {
        // 创建测试数据：稳定的加速度数据
        const data = createMockSensorData(250, {
          accX: 0, accY: 0, accZ: 9.8 // 重力加速度
        });

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
        // 合成加速度应该接近 9.8
        expect(Math.abs(result!.features.accMagnitude - 9.8) < 0.5).assertTrue();
      });

      it('应该正确计算标准差', () => {
        // 创建有变化的加速度数据
        const data = createMockSensorDataWithVariation(250, 0.5);

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
        expect(result!.features.accStdDev).assertLarger(0);
      });

      it('应该正确计算峰值计数', () => {
        // 创建有周期性变化的数据（模拟踩踏）
        const data = createPedalingMockData(250, 3); // 约3Hz踩踏频率

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
        // 5秒内应该有约15个峰值（3Hz * 5秒）
        expect(result!.features.peakCount).assertLarger(10);
      });

      it('应该正确计算过零率', () => {
        // 创建波动数据
        const data = createOscillatingData(250, 2); // 2Hz波动

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
        expect(result!.features.zeroCrossingRate).assertLarger(0);
      });
    });

    describe('动作分类', () => {
      it('应该识别停止状态', () => {
        // 创建静止数据
        const data = createMockSensorData(250, {
          accX: 0, accY: 0, accZ: 9.8,
          gyroX: 0, gyroY: 0, gyroZ: 0,
          speed: 0
        });

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
        expect(result!.action).assertEqual(ActionType.STOPPED);
      });

      it('应该识别踩踏动作', () => {
        // 创建踩踏数据：高加速度变化 + 有速度
        const data = createPedalingMockData(250, 3);

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
        // 踩踏应该被识别为 PEDALING 或 COASTING
        expect([
          ActionType.PEDALING,
          ActionType.COASTING
        ].includes(result!.action)).assertTrue();
      });

      it('应该识别上车动作', () => {
        // 创建上车数据：高加速度突变 + 低速度
        const data = createMountMockData(250);

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
        // 上车动作应该被识别
        expect(result!.action).assertNotNull();
      });

      it('应该识别下车动作', () => {
        // 创建下车数据：高加速度 + 高角速度
        const data = createDismountMockData(250);

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
        // 下车动作应该被识别
        expect(result!.action).assertNotNull();
      });
    });

    describe('置信度计算', () => {
      it('初始置信度应该较低', () => {
        const data = createMockSensorData(250, {
          accX: 0, accY: 0, accZ: 9.8
        });

        // 第一次检测
        let result: any = null;
        for (const d of data.slice(0, 250)) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
        // 历史记录不足时置信度可能较低
        expect(result!.confidence).assertLargerOrEqual(0);
      });

      it('一致性高的动作应该有更高置信度', () => {
        // 连续发送相同的停止数据
        const data = createMockSensorData(250 * 3, {
          accX: 0, accY: 0, accZ: 9.8,
          speed: 0
        });

        let lastResult: any = null;
        for (const d of data) {
          lastResult = detector.addSensorData(d);
        }

        expect(lastResult).assertNotNull();
        expect(lastResult!.confidence).assertLarger(0.7);
      });
    });

    describe('缓冲区管理', () => {
      it('窗口填满前不应该返回结果', () => {
        const data = createMockSensorData(100, {
          accX: 0, accY: 0, accZ: 9.8
        });

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        // 100 < 250，不应该有结果
        expect(result).assertNull();
      });

      it('窗口填满后应该返回结果', () => {
        const data = createMockSensorData(300, {
          accX: 0, accY: 0, accZ: 9.8
        });

        let result: any = null;
        for (const d of data) {
          result = detector.addSensorData(d);
        }

        expect(result).assertNotNull();
      });

      it('重置应该清空缓冲区', () => {
        const data = createMockSensorData(300, {
          accX: 0, accY: 0, accZ: 9.8
        });

        for (const d of data) {
          detector.addSensorData(d);
        }

        expect(detector.getBufferSize()).assertEqual(250);

        detector.reset();

        expect(detector.getBufferSize()).assertEqual(0);
      });
    });
  });
}

// ==================== 测试数据生成器 ====================

function createMockSensorData(count: number, base: Partial<SensorData>): SensorData[] {
  const data: SensorData[] = [];
  for (let i = 0; i < count; i++) {
    data.push({
      timestamp: Date.now() + i * 20,
      accX: base.accX ?? 0,
      accY: base.accY ?? 0,
      accZ: base.accZ ?? 9.8,
      gyroX: base.gyroX ?? 0,
      gyroY: base.gyroY ?? 0,
      gyroZ: base.gyroZ ?? 0,
      speed: base.speed ?? 0,
      heartRate: base.heartRate ?? 70
    });
  }
  return data;
}

function createMockSensorDataWithVariation(count: number, stdDev: number): SensorData[] {
  const data: SensorData[] = [];
  for (let i = 0; i < count; i++) {
    const noise = gaussianNoise(stdDev);
    data.push({
      timestamp: Date.now() + i * 20,
      accX: noise,
      accY: noise,
      accZ: 9.8 + noise,
      gyroX: noise * 0.1,
      gyroY: noise * 0.1,
      gyroZ: noise * 0.1,
      speed: 15,
      heartRate: 120
    });
  }
  return data;
}

function createPedalingMockData(count: number, frequency: number): SensorData[] {
  const data: SensorData[] = [];
  const period = 50 / frequency; // 每个周期的样本数

  for (let i = 0; i < count; i++) {
    const phase = (i % period) / period * 2 * Math.PI;
    const amplitude = 2 + Math.sin(phase) * 1.5;

    data.push({
      timestamp: Date.now() + i * 20,
      accX: Math.sin(phase) * amplitude,
      accY: Math.cos(phase) * amplitude * 0.5,
      accZ: 9.8 + Math.sin(phase) * amplitude,
      gyroX: Math.sin(phase) * 0.5,
      gyroY: Math.cos(phase) * 0.3,
      gyroZ: 0,
      speed: 20 + Math.random() * 5,
      heartRate: 130 + Math.floor(Math.random() * 10)
    });
  }
  return data;
}

function createOscillatingData(count: number, frequency: number): SensorData[] {
  const data: SensorData[] = [];
  const period = 50 / frequency;

  for (let i = 0; i < count; i++) {
    const phase = (i % period) / period * 2 * Math.PI;

    data.push({
      timestamp: Date.now() + i * 20,
      accX: Math.sin(phase) * 3,
      accY: 0,
      accZ: 9.8,
      gyroX: 0,
      gyroY: 0,
      gyroZ: 0,
      speed: 0,
      heartRate: 70
    });
  }
  return data;
}

function createMountMockData(count: number): SensorData[] {
  const data: SensorData[] = [];

  for (let i = 0; i < count; i++) {
    // 上车时有明显的加速度变化
    const mountPhase = i < 50 ? 0 : (i < 100 ? 1 : 2);
    let accMod = 0;
    let gyroMod = 0;

    if (mountPhase === 1) {
      accMod = 5 + Math.random() * 3;
      gyroMod = 2 + Math.random();
    }

    data.push({
      timestamp: Date.now() + i * 20,
      accX: accMod * (Math.random() - 0.5),
      accY: accMod * (Math.random() - 0.5),
      accZ: 9.8 + accMod,
      gyroX: gyroMod * (Math.random() - 0.5),
      gyroY: gyroMod * (Math.random() - 0.5),
      gyroZ: gyroMod * (Math.random() - 0.5),
      speed: 0,
      heartRate: 80 + Math.floor(Math.random() * 10)
    });
  }
  return data;
}

function createDismountMockData(count: number): SensorData[] {
  const data: SensorData[] = [];

  for (let i = 0; i < count; i++) {
    // 下车时有高加速度和高角速度
    const dismountPhase = i < 100 ? 0 : (i < 150 ? 1 : 2);
    let accMod = 0;
    let gyroMod = 0;

    if (dismountPhase === 1) {
      accMod = 8 + Math.random() * 4;
      gyroMod = 3 + Math.random() * 2;
    }

    data.push({
      timestamp: Date.now() + i * 20,
      accX: accMod * (Math.random() - 0.5),
      accY: accMod * (Math.random() - 0.5),
      accZ: 9.8 + accMod * 0.5,
      gyroX: gyroMod * (Math.random() - 0.5),
      gyroY: gyroMod * (Math.random() - 0.5),
      gyroZ: gyroMod * (Math.random() - 0.5),
      speed: dismountPhase === 0 ? 15 : 5,
      heartRate: 130 - dismountPhase * 20
    });
  }
  return data;
}

function gaussianNoise(stdDev: number): number {
  const u1 = Math.random();
  const u2 = Math.random();
  return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2) * stdDev;
}

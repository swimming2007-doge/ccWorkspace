/**
 * RideStateMachine 单元测试
 *
 * 测试范围：
 * - 状态转换逻辑
 * - 动作序列检测
 * - 暂停超时处理
 * - 事件回调
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { RideStateMachine } from '../services/RideStateMachine';
import { ActionType, RideState, RideEvent } from '../utils/Types';

export default function RideStateMachineTest() {
  describe('RideStateMachine', () => {
    let stateMachine: RideStateMachine;
    let capturedEvents: RideEvent[] = [];

    beforeEach(() => {
      stateMachine = new RideStateMachine();
      capturedEvents = [];

      stateMachine.onStateChange((event) => {
        capturedEvents.push(event);
      });
    });

    describe('初始状态', () => {
      it('初始状态应该是 IDLE', () => {
        expect(stateMachine.getCurrentState()).assertEqual(RideState.IDLE);
      });

      it('初始骑行时长应该是 0', () => {
        expect(stateMachine.getRideDuration()).assertEqual(0);
      });
    });

    describe('IDLE → RIDING 转换', () => {
      it('检测到上车+踩踏动作应该进入骑行状态', () => {
        // 模拟上车动作序列
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 10);
        stateMachine.transition(ActionType.PEDALING, 15);

        expect(stateMachine.getCurrentState()).assertEqual(RideState.RIDING);
        expect(capturedEvents).assertContain(RideEvent.RIDE_START);
      });

      it('只有踩踏没有上车不应该转换', () => {
        stateMachine.transition(ActionType.PEDALING, 15);
        stateMachine.transition(ActionType.PEDALING, 20);

        expect(stateMachine.getCurrentState()).assertEqual(RideState.IDLE);
      });

      it('骑行开始后应该记录开始时间', () => {
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 10);

        expect(stateMachine.getRideDuration()).assertLarger(0);
      });
    });

    describe('RIDING → PAUSED 转换', () => {
      it('停止+低速度应该进入暂停状态', () => {
        // 先进入骑行状态
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);

        capturedEvents = [];

        // 模拟停止
        for (let i = 0; i < 5; i++) {
          stateMachine.transition(ActionType.STOPPED, 1);
        }

        expect(stateMachine.getCurrentState()).assertEqual(RideState.PAUSED);
        expect(capturedEvents).assertContain(RideEvent.RIDE_PAUSE);
      });

      it('高速度时不应该暂停', () => {
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);

        capturedEvents = [];

        // 高速度下的停止动作
        for (let i = 0; i < 5; i++) {
          stateMachine.transition(ActionType.STOPPED, 20);
        }

        expect(stateMachine.getCurrentState()).assertEqual(RideState.RIDING);
      });

      it('暂停时应该记录暂停时间', () => {
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);

        for (let i = 0; i < 5; i++) {
          stateMachine.transition(ActionType.STOPPED, 0);
        }

        expect(stateMachine.getPauseDuration()).assertLargerOrEqual(0);
      });
    });

    describe('PAUSED → RIDING 转换', () => {
      it('检测到踩踏应该恢复骑行', () => {
        // 进入暂停状态
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);
        for (let i = 0; i < 5; i++) {
          stateMachine.transition(ActionType.STOPPED, 0);
        }

        capturedEvents = [];

        // 恢复踩踏
        stateMachine.transition(ActionType.PEDALING, 10);

        expect(stateMachine.getCurrentState()).assertEqual(RideState.RIDING);
        expect(capturedEvents).assertContain(RideEvent.RIDE_RESUME);
      });
    });

    describe('RIDING → ENDING 转换', () => {
      it('检测到下车动作应该进入结束确认状态', () => {
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);

        capturedEvents = [];

        stateMachine.transition(ActionType.DISMOUNT, 5);

        expect(stateMachine.getCurrentState()).assertEqual(RideState.ENDING);
        expect(capturedEvents).assertContain(RideEvent.RIDE_END_REQUEST);
      });
    });

    describe('用户确认/取消', () => {
      it('确认结束应该回到 IDLE', () => {
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);
        stateMachine.transition(ActionType.DISMOUNT, 5);

        capturedEvents = [];

        stateMachine.confirmEnd();

        expect(stateMachine.getCurrentState()).assertEqual(RideState.IDLE);
        expect(capturedEvents).assertContain(RideEvent.RIDE_END_CONFIRMED);
      });

      it('取消结束应该回到 RIDING', () => {
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);
        stateMachine.transition(ActionType.DISMOUNT, 5);

        capturedEvents = [];

        stateMachine.cancelEnd();

        expect(stateMachine.getCurrentState()).assertEqual(RideState.RIDING);
        expect(capturedEvents).assertContain(RideEvent.RIDE_CONTINUE);
      });

      it('非 ENDING 状态确认结束无效', () => {
        stateMachine.confirmEnd();
        expect(stateMachine.getCurrentState()).assertEqual(RideState.IDLE);
      });
    });

    describe('重置', () => {
      it('重置应该清除所有状态', () => {
        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);

        stateMachine.reset();

        expect(stateMachine.getCurrentState()).assertEqual(RideState.IDLE);
        expect(stateMachine.getRideDuration()).assertEqual(0);
        expect(stateMachine.getPauseDuration()).assertEqual(0);
      });
    });

    describe('事件回调', () => {
      it('应该支持多个回调', () => {
        const events2: RideEvent[] = [];
        stateMachine.onStateChange((event) => {
          events2.push(event);
        });

        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);

        expect(capturedEvents.length).assertLarger(0);
        expect(events2.length).assertEqual(capturedEvents.length);
      });

      it('应该支持移除回调', () => {
        const callback = (event: RideEvent) => {
          capturedEvents.push(event);
        };

        stateMachine.onStateChange(callback);
        stateMachine.offStateChange(callback);

        stateMachine.transition(ActionType.MOUNT, 0);
        stateMachine.transition(ActionType.PEDALING, 15);

        // 回调已被移除，不应该记录事件
        expect(capturedEvents.length).assertEqual(0);
      });
    });
  });
}

// 辅助函数：检查数组是否包含元素
declare module '@ohos/hypium' {
  interface Assert {
    assertContain<T>(array: T[], element: T): void;
  }
}

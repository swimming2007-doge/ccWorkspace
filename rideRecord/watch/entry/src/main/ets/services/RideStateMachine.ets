/**
 * 骑行状态机
 *
 * 功能说明：
 * - 管理骑行状态转换 (IDLE → RIDING → PAUSED → ENDING)
 * - 基于动作检测结果触发状态变化
 * - 提供事件回调通知状态变化
 * - 处理暂停超时自动结束
 *
 * 状态转换规则：
 * - IDLE → RIDING: 检测到上车 + 踩踏动作
 * - RIDING → PAUSED: 检测到停止 + 低速度
 * - PAUSED → RIDING: 检测到踩踏动作
 * - PAUSED → ENDING: 暂停超过30分钟
 * - RIDING → ENDING: 检测到下车动作
 * - ENDING → IDLE: 用户确认结束
 * - ENDING → RIDING: 用户取消结束
 */
import hilog from '@ohos.hilog';
import { ActionType, RideState, RideEvent, StateTransitionCallback } from '../utils/Types';

const TAG = '[RideStateMachine]';
const DOMAIN = 0xFF00;

// 暂停超时时间 (30分钟)
const PAUSE_TIMEOUT_MS = 30 * 60 * 1000;
// 动作序列检测窗口大小
const SEQUENCE_WINDOW_SIZE = 5;
// 低速度阈值 (km/h)
const LOW_SPEED_THRESHOLD = 2.0;

/**
 * 状态转换条件类型
 */
type TransitionCondition = (
  actions: ActionType[],
  context: StateContext
) => boolean;

/**
 * 状态上下文
 */
interface StateContext {
  speed: number;
  noPedaling: boolean;
  pauseDuration: number;
}

/**
 * 状态转换规则
 */
interface StateTransition {
  from: RideState;
  to: RideState;
  condition: TransitionCondition;
  event: RideEvent;
}

/**
 * 骑行状态机类
 */
export class RideStateMachine {
  private currentState: RideState = RideState.IDLE;
  private actionHistory: ActionType[] = [];
  private pauseStartTime: number = 0;
  private rideStartTime: number = 0;

  private callbacks: StateTransitionCallback[] = [];
  private context: StateContext = {
    speed: 0,
    noPedaling: true,
    pauseDuration: 0
  };

  // 状态转换规则表
  private transitions: StateTransition[] = [
    {
      from: RideState.IDLE,
      to: RideState.RIDING,
      condition: (actions) => this.containsSequence(actions, [
        ActionType.MOUNT,
        ActionType.PEDALING
      ]),
      event: RideEvent.RIDE_START
    },
    {
      from: RideState.RIDING,
      to: RideState.PAUSED,
      condition: (actions, ctx) =>
        this.allStopped(actions) &&
        ctx.speed < LOW_SPEED_THRESHOLD &&
        ctx.noPedaling,
      event: RideEvent.RIDE_PAUSE
    },
    {
      from: RideState.PAUSED,
      to: RideState.RIDING,
      condition: (actions) => actions.includes(ActionType.PEDALING),
      event: RideEvent.RIDE_RESUME
    },
    {
      from: RideState.PAUSED,
      to: RideState.ENDING,
      condition: (_, ctx) => ctx.pauseDuration > PAUSE_TIMEOUT_MS,
      event: RideEvent.RIDE_END_REQUEST
    },
    {
      from: RideState.RIDING,
      to: RideState.ENDING,
      condition: (actions) => actions.includes(ActionType.DISMOUNT),
      event: RideEvent.RIDE_END_REQUEST
    }
  ];

  /**
   * 处理动作检测结果
   * @param action 检测到的动作
   * @param speed 当前速度 (km/h)
   */
  transition(action: ActionType, speed: number = 0): void {
    hilog.debug(DOMAIN, TAG, 'Processing action: %{public}s, speed: %{public}f',
      action, speed);

    // 更新动作历史
    this.actionHistory.push(action);
    if (this.actionHistory.length > SEQUENCE_WINDOW_SIZE) {
      this.actionHistory.shift();
    }

    // 更新上下文
    this.context.speed = speed;
    this.context.noPedaling = !this.actionHistory.includes(ActionType.PEDALING);

    // 更新暂停时长
    if (this.currentState === RideState.PAUSED) {
      this.context.pauseDuration = Date.now() - this.pauseStartTime;
    }

    // 检查状态转换
    for (const transition of this.transitions) {
      if (transition.from === this.currentState) {
        if (transition.condition(this.actionHistory, this.context)) {
          this.executeTransition(transition);
          break;
        }
      }
    }
  }

  /**
   * 执行状态转换
   */
  private executeTransition(transition: StateTransition): void {
    hilog.info(DOMAIN, TAG, 'State transition: %{public}s → %{public}s',
      transition.from, transition.to);

    const previousState = this.currentState;
    this.currentState = transition.to;

    // 记录时间
    if (transition.to === RideState.RIDING && transition.from === RideState.IDLE) {
      this.rideStartTime = Date.now();
      hilog.info(DOMAIN, TAG, 'Ride started at: %{public}d', this.rideStartTime);
    }

    if (transition.to === RideState.PAUSED) {
      this.pauseStartTime = Date.now();
      hilog.info(DOMAIN, TAG, 'Ride paused at: %{public}d', this.pauseStartTime);
    }

    if (transition.to === RideState.IDLE) {
      hilog.info(DOMAIN, TAG, 'Ride ended. Duration: %{public}d ms',
        Date.now() - this.rideStartTime);
    }

    // 重置上下文
    if (transition.to === RideState.RIDING) {
      this.context.pauseDuration = 0;
      this.pauseStartTime = 0;
    }

    // 发送事件
    this.emit(transition.event);
  }

  /**
   * 用户确认结束
   */
  confirmEnd(): void {
    if (this.currentState === RideState.ENDING) {
      hilog.info(DOMAIN, TAG, 'User confirmed ride end');
      this.currentState = RideState.IDLE;
      this.emit(RideEvent.RIDE_END_CONFIRMED);
      this.reset();
    }
  }

  /**
   * 用户取消结束
   */
  cancelEnd(): void {
    if (this.currentState === RideState.ENDING) {
      hilog.info(DOMAIN, TAG, 'User cancelled ride end');
      this.currentState = RideState.RIDING;
      this.emit(RideEvent.RIDE_CONTINUE);
    }
  }

  /**
   * 获取当前状态
   */
  getCurrentState(): RideState {
    return this.currentState;
  }

  /**
   * 获取骑行时长（毫秒）
   */
  getRideDuration(): number {
    if (this.rideStartTime === 0) {
      return 0;
    }
    return Date.now() - this.rideStartTime;
  }

  /**
   * 获取暂停时长（毫秒）
   */
  getPauseDuration(): number {
    if (this.pauseStartTime === 0) {
      return 0;
    }
    return Date.now() - this.pauseStartTime;
  }

  /**
   * 注册状态变化回调
   */
  onStateChange(callback: StateTransitionCallback): void {
    this.callbacks.push(callback);
  }

  /**
   * 移除状态变化回调
   */
  offStateChange(callback: StateTransitionCallback): void {
    const index = this.callbacks.indexOf(callback);
    if (index > -1) {
      this.callbacks.splice(index, 1);
    }
  }

  /**
   * 重置状态机
   */
  reset(): void {
    this.currentState = RideState.IDLE;
    this.actionHistory = [];
    this.pauseStartTime = 0;
    this.rideStartTime = 0;
    this.context = {
      speed: 0,
      noPedaling: true,
      pauseDuration: 0
    };
    hilog.info(DOMAIN, TAG, 'State machine reset');
  }

  /**
   * 发送事件
   */
  private emit(event: RideEvent): void {
    hilog.info(DOMAIN, TAG, 'Emitting event: %{public}s', event);
    for (const callback of this.callbacks) {
      try {
        callback(event);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Error in callback: %{public}s', JSON.stringify(error));
      }
    }
  }

  // ==================== 辅助方法 ====================

  /**
   * 检查动作序列是否包含指定模式
   */
  private containsSequence(actions: ActionType[], sequence: ActionType[]): boolean {
    if (actions.length < sequence.length) {
      return false;
    }

    // 检查最近N个动作是否包含序列中的所有动作
    const recentActions = actions.slice(-sequence.length * 2);
    for (const requiredAction of sequence) {
      if (!recentActions.includes(requiredAction)) {
        return false;
      }
    }

    return true;
  }

  /**
   * 检查所有动作是否都是停止
   */
  private allStopped(actions: ActionType[]): boolean {
    return actions.every(a => a === ActionType.STOPPED || a === ActionType.COASTING);
  }
}

// 导出单例
export default new RideStateMachine();

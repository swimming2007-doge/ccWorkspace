/**
 * 测试入口文件
 *
 * 运行所有测试模块
 */
import ActionDetectorTest from './ActionDetector.test';
import RideStateMachineTest from './RideStateMachine.test';

export default function testsuite() {
  ActionDetectorTest();
  RideStateMachineTest();
}

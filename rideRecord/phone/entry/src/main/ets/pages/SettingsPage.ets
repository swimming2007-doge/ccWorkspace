/**
 * 设置页面
 *
 * 功能说明：
 * - 用户个人信息设置
 * - 骑行偏好设置
 * - 同步设置
 */
import router from '@ohos.router';
import hilog from '@ohos.hilog';

const TAG = '[SettingsPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct SettingsPage {
  @State nickname: string = '骑行者';
  @State autoStart: boolean = true;
  @State autoPause: boolean = true;
  @State voicePrompt: boolean = true;
  @State autoSync: boolean = true;

  build() {
    Column() {
      // 标题栏
      Row() {
        Button('返回')
          .backgroundColor(Color.Transparent)
          .onClick(() => router.back())

        Blank()

        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)

        Blank()

        Text('    ') // 占位
      }
      .width('100%')
      .padding(16)

      // 设置列表
      List() {
        // 个人信息
        ListItemGroup({ header: '个人信息' }) {
          ListItem() {
            Row() {
              Text('昵称')
              Blank()
              Text(this.nickname)
                .fontColor('#99182431')
            }
            .width('100%')
            .padding(16)
          }
        }

        // 骑行设置
        ListItemGroup({ header: '骑行设置' }) {
          ListItem() {
            Row() {
              Text('自动开始')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.autoStart })
                .onChange((isOn) => this.autoStart = isOn)
            }
            .width('100%')
            .padding(16)
          }

          ListItem() {
            Row() {
              Text('自动暂停')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.autoPause })
                .onChange((isOn) => this.autoPause = isOn)
            }
            .width('100%')
            .padding(16)
          }

          ListItem() {
            Row() {
              Text('语音提示')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.voicePrompt })
                .onChange((isOn) => this.voicePrompt = isOn)
            }
            .width('100%')
            .padding(16)
          }
        }

        // 同步设置
        ListItemGroup({ header: '同步设置' }) {
          ListItem() {
            Row() {
              Text('自动同步')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.autoSync })
                .onChange((isOn) => this.autoSync = isOn)
            }
            .width('100%')
            .padding(16)
          }
        }

        // 关于
        ListItemGroup({ header: '关于' }) {
          ListItem() {
            Row() {
              Text('版本')
              Blank()
              Text('1.0.0')
                .fontColor('#99182431')
            }
            .width('100%')
            .padding(16)
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

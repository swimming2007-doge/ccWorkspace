/**
 * 登录页面 - F015
 *
 * 功能说明：
 * - 华为账号登录
 * - 游客模式登录
 * - 登录状态展示
 * - 用户信息展示
 *
 * 依赖组件：
 * - AuthService: 认证服务
 */

import router from '@ohos.router';
import hilog from '@ohos.hilog';
import AuthService, { LoginStatus, UserInfo, LoginResult } from '../services/AuthService';

const TAG = '[LoginPage]';
const DOMAIN = 0xFF00;

@Entry
@Component
struct LoginPage {
  // 登录状态
  @State loginStatus: LoginStatus = LoginStatus.LOGGED_OUT;
  @State currentUser: UserInfo | null = null;
  @State isLoading: boolean = false;
  @State errorMessage: string = '';

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'LoginPage appearing');

    // 注册状态回调
    AuthService.onStatusChange((status, user) => {
      this.loginStatus = status;
      this.currentUser = user;
    });

    // 检查登录状态
    this.checkLoginStatus();
  }

  /**
   * 检查登录状态
   */
  private checkLoginStatus(): void {
    this.loginStatus = AuthService.getLoginStatus();
    this.currentUser = AuthService.getCurrentUser();

    // 如果已登录，跳转到主页
    if (this.loginStatus === LoginStatus.LOGGED_IN) {
      this.navigateToMain();
    }
  }

  /**
   * 华为账号登录
   */
  private async loginWithHuawei(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';

    try {
      const result: LoginResult = await AuthService.loginWithHuawei();

      if (result.success) {
        this.navigateToMain();
      } else {
        this.errorMessage = result.error || '登录失败，请重试';
      }
    } catch (error) {
      this.errorMessage = '登录出错，请稍后重试';
      hilog.error(DOMAIN, TAG, 'Login error: %{public}s', JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 游客模式登录
   */
  private async loginAsGuest(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';

    try {
      const result: LoginResult = await AuthService.loginAsGuest();

      if (result.success) {
        this.navigateToMain();
      } else {
        this.errorMessage = result.error || '登录失败，请重试';
      }
    } catch (error) {
      this.errorMessage = '登录出错，请稍后重试';
      hilog.error(DOMAIN, TAG, 'Guest login error: %{public}s', JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 跳转到主页
   */
  private navigateToMain(): void {
    router.replaceUrl({
      url: 'pages/MainPage'
    });
  }

  build() {
    Column() {
      // Logo区域
      Column() {
        Text('🚴')
          .fontSize(80)

        Text('RideRecord')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
          .margin({ top: 16 })

        Text('智能骑行记录')
          .fontSize(14)
          .fontColor('#99182431')
          .margin({ top: 8 })
      }
      .margin({ top: 80 })

      // 登录按钮区域
      Column() {
        // 华为账号登录
        Button() {
          Row() {
            Text('🔷')
              .fontSize(20)

            Text('华为账号登录')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .margin({ left: 12 })
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor('#CF2A27')
        .borderRadius(24)
        .enabled(!this.isLoading)
        .onClick(() => this.loginWithHuawei())

        // 分隔线
        Row() {
          Divider()
            .width(80)
            .color('#E8E8E8')

          Text('或')
            .fontSize(12)
            .fontColor('#99182431')
            .margin({ left: 16, right: 16 })

          Divider()
            .width(80)
            .color('#E8E8E8')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 24, bottom: 24 })

        // 游客模式
        Button() {
          Text('游客模式体验')
            .fontSize(16)
            .fontColor('#182431')
        }
        .width('100%')
        .height(48)
        .backgroundColor('#F5F5F5')
        .borderRadius(24)
        .enabled(!this.isLoading)
        .onClick(() => this.loginAsGuest())

        // 错误信息
        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(12)
            .fontColor('#F5222D')
            .margin({ top: 16 })
        }

        // 加载状态
        if (this.isLoading) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color('#1890FF')
            .margin({ top: 16 })
        }
      }
      .width('100%')
      .padding({ left: 32, right: 32 })
      .margin({ top: 60 })

      // 协议说明
      Column() {
        Text('登录即表示同意')
          .fontSize(12)
          .fontColor('#99182431')

        Row() {
          Text('《用户协议》')
            .fontSize(12)
            .fontColor('#1890FF')
            .onClick(() => {
              // TODO: 打开用户协议
            })

          Text('和')
            .fontSize(12)
            .fontColor('#99182431')

          Text('《隐私政策》')
            .fontSize(12)
            .fontColor('#1890FF')
            .onClick(() => {
              // TODO: 打开隐私政策
            })
        }
        .margin({ top: 4 })
      }
      .margin({ top: 'auto', bottom: 40 })

      // 版本号
      Text('v0.1.0')
        .fontSize(10)
        .fontColor('#BFBFBF')
        .margin({ bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

/**
 * 个人中心页面
 */
@Component
export struct ProfilePage {
  @State currentUser: UserInfo | null = null;
  @State loginStatus: LoginStatus = LoginStatus.LOGGED_OUT;

  aboutToAppear() {
    // 注册状态回调
    AuthService.onStatusChange((status, user) => {
      this.loginStatus = status;
      this.currentUser = user;
    });

    this.currentUser = AuthService.getCurrentUser();
    this.loginStatus = AuthService.getLoginStatus();
  }

  build() {
    Column() {
      // 用户信息卡片
      if (this.loginStatus === LoginStatus.LOGGED_IN && this.currentUser) {
        this.buildLoggedInView()
      } else {
        this.buildLoggedOutView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }

  @Builder
  buildLoggedInView() {
    Column() {
      // 用户头像和昵称
      Row() {
        if (this.currentUser?.avatar) {
          Image(this.currentUser.avatar)
            .width(60)
            .height(60)
            .borderRadius(30)
        } else {
          Column() {
            Text('👤')
              .fontSize(32)
          }
          .width(60)
          .height(60)
          .borderRadius(30)
          .backgroundColor('#E8E8E8')
          .justifyContent(FlexAlign.Center)
        }

        Column() {
          Text(this.currentUser?.nickname || '骑行者')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)

          if (this.currentUser?.email) {
            Text(this.currentUser.email)
              .fontSize(12)
              .fontColor('#99182431')
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 })
        .layoutWeight(1)

        // 编辑按钮
        Button('编辑')
          .fontSize(14)
          .fontColor('#1890FF')
          .backgroundColor('#E6F7FF')
          .borderRadius(16)
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)

      // 功能列表
      Column() {
        this.buildMenuItem('骑行统计', '📊', () => {
          // TODO: 跳转到统计页面
        })

        Divider()

        this.buildMenuItem('我的设备', '📱', () => {
          // TODO: 跳转到设备页面
        })

        Divider()

        this.buildMenuItem('云端同步', '☁️', () => {
          router.pushUrl({ url: 'pages/SyncPage' });
        })

        Divider()

        this.buildMenuItem('设置', '⚙️', () => {
          // TODO: 跳转到设置页面
        })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ top: 12 })

      // 退出登录
      Button('退出登录')
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontColor('#F5222D')
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .margin({ top: 24 })
        .onClick(() => {
          AuthService.logout();
        })
    }
    .padding(16)
  }

  @Builder
  buildLoggedOutView() {
    Column() {
      Text('请先登录')
        .fontSize(16)
        .fontColor('#99182431')

      Button('去登录')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor('#1890FF')
        .borderRadius(24)
        .padding({ left: 32, right: 32, top: 12, bottom: 12 })
        .margin({ top: 16 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildMenuItem(title: string, icon: string, onClick: () => void) {
    Row() {
      Text(icon)
        .fontSize(20)

      Text(title)
        .fontSize(16)
        .fontColor('#182431')
        .margin({ left: 12 })
        .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor('#BFBFBF')
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .onClick(onClick)
  }
}

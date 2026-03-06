/**
 * 分享界面组件
 *
 * 功能说明：
 * - 分享模板选择
 * - 分享配置面板
 * - 分享预览
 * - 分享操作按钮
 *
 * SRS引用: FR-006
 */
import {
  ShareType,
  ShareTemplate,
  ShareConfig,
  DEFAULT_SHARE_CONFIG,
  TEMPLATE_CONFIGS,
  RideShareData,
  ShareResult
} from '../services/WeChatShareService';

/**
 * 模板选择器组件
 */
@Component
export struct TemplateSelector {
  @Prop templates: {
    key: ShareTemplate;
    name: string;
    preview: string;
  }[] = [];
  @Link selectedTemplate: ShareTemplate;

  build() {
    Column() {
      Text('选择模板')
        .fontSize(14)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ bottom: 12 })

      Row() {
        ForEach(this.templates, (template: typeof this.templates[0]) => {
          Column() {
            // 模板预览图
            Image(template.preview)
              .width(70)
              .height(100)
              .borderRadius(8)
              .border({
                width: this.selectedTemplate === template.key ? 2 : 0,
                color: '#3B82F6'
              })
              .backgroundColor('#E5E7EB')

            Text(template.name)
              .fontSize(12)
              .margin({ top: 6 })
              .fontColor(this.selectedTemplate === template.key ? '#3B82F6' : '#6B7280')
          }
          .margin({ right: 12 })
          .onClick(() => {
            this.selectedTemplate = template.key;
          })
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}

/**
 * 分享配置面板组件
 */
@Component
export struct ShareConfigPanel {
  @Link config: ShareConfig;

  build() {
    Column() {
      Text('分享设置')
        .fontSize(14)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ bottom: 12 })

      // 显示位置
      this.SettingRow('显示位置信息', this.config.showLocation, (value) => {
        this.config.showLocation = value;
      })

      // 显示速度
      this.SettingRow('显示速度数据', this.config.showSpeed, (value) => {
        this.config.showSpeed = value;
      })

      // 显示心率
      this.SettingRow('显示心率数据', this.config.showHeartRate, (value) => {
        this.config.showHeartRate = value;
      })

      // 显示爬升
      this.SettingRow('显示爬升数据', this.config.showElevation, (value) => {
        this.config.showElevation = value;
      })

      // 显示热量
      this.SettingRow('显示热量消耗', this.config.showCalories, (value) => {
        this.config.showCalories = value;
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  SettingRow(title: string, value: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor('#374151')

      Blank()

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor('#3B82F6')
        .onChange(onChange)
    }
    .width('100%')
    .height(44)
  }
}

/**
 * 照片选择器组件
 */
@Component
export struct PhotoSelector {
  @Prop photos: string[] = [];
  @Link selectedIndex: number | undefined;

  build() {
    if (this.photos.length === 0) {
      return;
    }

    Column() {
      Text('选择照片')
        .fontSize(14)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ bottom: 12 })

      List({ scrollable: ScrollDirection.Horizontal }) {
        ForEach(this.photos, (photo: string, index: number) => {
          ListItem() {
            Stack() {
              Image(photo)
                .width(80)
                .height(80)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)

              if (this.selectedIndex === index) {
                // 选中标记
                Circle()
                  .width(24)
                  .height(24)
                  .fill('#3B82F6')
                  .position({ x: 56, y: 4 })

                Image('check_icon')
                  .width(16)
                  .height(16)
                  .fillColor('#FFFFFF')
                  .position({ x: 60, y: 8 })
              }
            }
            .width(80)
            .height(80)
            .margin({ right: 8 })
            .onClick(() => {
              this.selectedIndex = this.selectedIndex === index ? undefined : index;
            })
          }
        })
      }
      .width('100%')
      .height(80)
      .scrollable(ScrollDirection.Horizontal)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}

/**
 * 自定义描述输入组件
 */
@Component
export struct DescriptionInput {
  @Link customTitle: string;
  @Link customDescription: string;

  build() {
    Column() {
      Text('自定义内容')
        .fontSize(14)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ bottom: 12 })

      // 标题输入
      Column() {
        Text('标题（可选）')
          .fontSize(12)
          .fontColor('#6B7280')
          .margin({ bottom: 4 })

        TextInput({ placeholder: '我刚刚完成了一次骑行', text: this.customTitle })
          .height(40)
          .backgroundColor('#F3F4F6')
          .borderRadius(8)
          .onChange((value) => {
            this.customTitle = value;
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 描述输入
      Column() {
        Text('描述（可选）')
          .fontSize(12)
          .fontColor('#6B7280')
          .margin({ bottom: 4 })

        TextArea({ placeholder: '分享你的骑行感受...', text: this.customDescription })
          .height(80)
          .backgroundColor('#F3F4F6')
          .borderRadius(8)
          .onChange((value) => {
            this.customDescription = value;
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}

/**
 * 分享按钮组件
 */
@Component
export struct ShareButtons {
  @Prop isSharing: boolean = false;

  onShareFriend?: () => void;
  onShareMoments?: () => void;

  build() {
    Row() {
      // 分享到好友
      Button() {
        Column() {
          Image('wechat_friend_icon')
            .width(32)
            .height(32)

          Text('微信好友')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .margin({ top: 4 })
        }
      }
      .width('45%')
      .height(80)
      .backgroundColor('#07C160')
      .borderRadius(12)
      .enabled(!this.isSharing)
      .onClick(() => {
        if (this.onShareFriend) {
          this.onShareFriend();
        }
      })

      Blank()

      // 分享到朋友圈
      Button() {
        Column() {
          Image('wechat_moments_icon')
            .width(32)
            .height(32)

          Text('朋友圈')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .margin({ top: 4 })
        }
      }
      .width('45%')
      .height(80)
      .backgroundColor('#07C160')
      .borderRadius(12)
      .enabled(!this.isSharing)
      .onClick(() => {
        if (this.onShareMoments) {
          this.onShareMoments();
        }
      })
    }
    .width('100%')
    .padding(16)
  }
}

/**
 * 分享预览组件
 */
@Component
export struct SharePreview {
  @Prop shareData: RideShareData | null = null;
  @Prop config: ShareConfig = DEFAULT_SHARE_CONFIG;
  @Prop previewImage: string = '';

  build() {
    Column() {
      Text('分享预览')
        .fontSize(14)
        .fontWeight(FontWeight.MEDIUM)
        .margin({ bottom: 12 })

      if (this.previewImage) {
        Image(this.previewImage)
          .width('100%')
          .height(400)
          .borderRadius(12)
          .objectFit(ImageFit.Cover)
      } else {
        // 占位预览
        Column() {
          Text('预览加载中...')
            .fontSize(14)
            .fontColor('#6B7280')
        }
        .width('100%')
        .height(400)
        .backgroundColor('#F3F4F6')
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .padding(16)
  }
}

/**
 * 分享结果提示组件
 */
@Component
export struct ShareResultToast {
  @Prop result: ShareResult | null = null;
  @State visible: boolean = false;

  build() {
    if (!this.visible || !this.result) {
      return;
    }

    Row() {
      Image(this.result.success ? 'success_icon' : 'error_icon')
        .width(20)
        .height(20)
        .margin({ right: 8 })

      Text(this.result.success ? '分享成功' : this.result.error || '分享失败')
        .fontSize(14)
        .fontColor('#FFFFFF')
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.result.success ? '#10B981' : '#EF4444')
    .borderRadius(8)
    .position({ x: '50%', y: 100 })
    .translate({ x: '-50%' })
  }

  show(result: ShareResult) {
    this.result = result;
    this.visible = true;

    // 3秒后自动隐藏
    setTimeout(() => {
      this.visible = false;
    }, 3000);
  }

  hide() {
    this.visible = false;
  }
}

/**
 * 分享数据摘要卡片组件
 */
@Component
export struct ShareDataSummary {
  @Prop shareData: RideShareData | null = null;

  build() {
    if (!this.shareData) {
      return;
    }

    Column() {
      Row() {
        Text('骑行数据')
          .fontSize(14)
          .fontWeight(FontWeight.MEDIUM)

        Blank()

        Text(this.formatDate(this.shareData.startTime))
          .fontSize(12)
          .fontColor('#6B7280')
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        // 距离
        Column() {
          Text(this.formatDistance(this.shareData.distance))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3B82F6')

          Text('距离(km)')
            .fontSize(12)
            .fontColor('#6B7280')
            .margin({ top: 2 })
        }
        .layoutWeight(1)

        // 时长
        Column() {
          Text(this.formatDuration(this.shareData.duration))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3B82F6')

          Text('时长')
            .fontSize(12)
            .fontColor('#6B7280')
            .margin({ top: 2 })
        }
        .layoutWeight(1)

        // 均速
        Column() {
          Text((this.shareData.avgSpeed * 3.6).toFixed(1))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3B82F6')

          Text('均速(km/h)')
            .fontSize(12)
            .fontColor('#6B7280')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  private formatDistance(meters: number): string {
    return (meters / 1000).toFixed(2);
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return `${hours}h${mins}m`;
    }
    return `${mins}m`;
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }
}

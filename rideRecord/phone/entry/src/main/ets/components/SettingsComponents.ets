/**
 * 设置界面组件
 *
 * 功能说明：
 * - 设置分组卡片
 * - 开关设置项
 * - 选择设置项
 * - 数值设置项
 */

import {
  NavMode,
  UnitSystem,
  DetectionSensitivity,
  RidingSettings,
  DetectionSettings,
  SyncSettings,
  PrivacySettings
} from '../services/SettingsService';

/**
 * 设置分组标题
 */
@Component
export struct SettingsGroupHeader {
  @Prop title: string = '';
  @Prop icon: string = '';

  build() {
    Row() {
      if (this.icon) {
        Text(this.icon)
          .fontSize(18)
      }

      Text(this.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#182431')
        .margin({ left: this.icon ? 8 : 0 })
    }
    .width('100%')
    .padding({ top: 16, bottom: 8, left: 16, right: 16 })
  }
}

/**
 * 开关设置项
 */
@Component
export struct ToggleSettingItem {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop value: boolean = false;
  @Prop icon: string = '';
  onToggle?: (value: boolean) => void;

  build() {
    Row() {
      if (this.icon) {
        Text(this.icon)
          .fontSize(20)
          .width(32)
      }

      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor('#182431')

        if (this.description) {
          Text(this.description)
            .fontSize(12)
            .fontColor('#99182431')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: this.icon ? 12 : 0 })

      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .selectedColor('#1890FF')
        .onChange((isOn: boolean) => {
          this.onToggle?.(isOn);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }
}

/**
 * 选择设置项
 */
@Component
export struct SelectSettingItem<T> {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop value: T | null = null;
  @Prop options: Array<{ label: string; value: T }> = [];
  @Prop icon: string = '';
  onSelect?: (value: T) => void;
  @State showModal: boolean = false;

  private get selectedLabel(): string {
    const option = this.options.find(o => o.value === this.value);
    return option?.label || '';
  }

  build() {
    Row() {
      if (this.icon) {
        Text(this.icon)
          .fontSize(20)
          .width(32)
      }

      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor('#182431')

        if (this.description) {
          Text(this.description)
            .fontSize(12)
            .fontColor('#99182431')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: this.icon ? 12 : 0 })

      Row() {
        Text(this.selectedLabel)
          .fontSize(14)
          .fontColor('#1890FF')

        Text('›')
          .fontSize(16)
          .fontColor('#BFBFBF')
          .margin({ left: 4 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      this.showModal = true;
    })
    .bindSheet($$this.showModal, this.buildOptionsSheet(), {
      height: 300,
      backgroundColor: '#FFFFFF',
      dragBar: true
    })
  }

  @Builder
  buildOptionsSheet() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16, bottom: 16 })

      ForEach(this.options, (option: { label: string; value: T }) => {
        Row() {
          Text(option.label)
            .fontSize(16)
            .fontColor('#182431')

          Blank()

          if (option.value === this.value) {
            Text('✓')
              .fontSize(16)
              .fontColor('#1890FF')
          }
        }
        .width('100%')
        .padding(16)
        .onClick(() => {
          this.onSelect?.(option.value);
          this.showModal = false;
        })
      })

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }
}

/**
 * 数值设置项
 */
@Component
export struct NumberSettingItem {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop value: number = 0;
  @Prop min: number = 0;
  @Prop max: number = 100;
  @Prop step: number = 1;
  @Prop unit: string = '';
  @Prop icon: string = '';
  onChange?: (value: number) => void;

  build() {
    Row() {
      if (this.icon) {
        Text(this.icon)
          .fontSize(20)
          .width(32)
      }

      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor('#182431')

        if (this.description) {
          Text(this.description)
            .fontSize(12)
            .fontColor('#99182431')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: this.icon ? 12 : 0 })

      Row() {
        Button('-')
          .fontSize(18)
          .fontColor('#182431')
          .backgroundColor('#F5F5F5')
          .width(32)
          .height(32)
          .borderRadius(16)
          .enabled(this.value > this.min)
          .onClick(() => {
            const newValue = Math.max(this.min, this.value - this.step);
            this.onChange?.(newValue);
          })

        Text(`${this.value}${this.unit}`)
          .fontSize(16)
          .fontColor('#182431')
          .width(60)
          .textAlign(TextAlign.Center)

        Button('+')
          .fontSize(18)
          .fontColor('#182431')
          .backgroundColor('#F5F5F5')
          .width(32)
          .height(32)
          .borderRadius(16)
          .enabled(this.value < this.max)
          .onClick(() => {
            const newValue = Math.min(this.max, this.value + this.step);
            this.onChange?.(newValue);
          })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }
}

/**
 * 滑块设置项
 */
@Component
export struct SliderSettingItem {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop value: number = 0;
  @Prop min: number = 0;
  @Prop max: number = 100;
  @Prop step: number = 1;
  @Prop unit: string = '';
  @Prop icon: string = '';
  onChange?: (value: number) => void;

  build() {
    Column() {
      Row() {
        if (this.icon) {
          Text(this.icon)
            .fontSize(20)
        }

        Text(this.title)
          .fontSize(16)
          .fontColor('#182431')
          .margin({ left: this.icon ? 8 : 0 })

        Blank()

        Text(`${this.value}${this.unit}`)
          .fontSize(14)
          .fontColor('#1890FF')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')

      Slider({
        value: this.value,
        min: this.min,
        max: this.max,
        step: this.step,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .blockColor('#1890FF')
        .trackColor('#E8E8E8')
        .selectedColor('#1890FF')
        .margin({ top: 12 })
        .onChange((value: number) => {
          this.onChange?.(Math.round(value));
        })

      if (this.description) {
        Text(this.description)
          .fontSize(12)
          .fontColor('#99182431')
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * 设置卡片容器
 */
@Component
export struct SettingsCard {
  @Prop title: string = '';
  @BuilderParam content: () => void;

  build() {
    Column() {
      if (this.title) {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#99182431')
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }

      Column() {
        this.content()
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .clip(true)
    }
    .width('100%')
  }
}

/**
 * 设置分隔线
 */
@Component
export struct SettingsDivider {
  build() {
    Divider()
      .width('100%')
      .margin({ left: 48 })
      .color('#F0F0F0')
  }
}

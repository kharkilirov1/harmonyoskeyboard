import { Key } from '../model/KeyboardLayout';

/**
 * Компонент кнопки клавиатуры
 */
@Component
export struct KeyButton {
  @Prop key: Key;
  @Prop isShift: boolean = false;
  onKeyPress: (key: Key) => void = () => {};

  build() {
    Button(this.getKeyLabel())
      .width(this.getKeyWidth())
      .height(45)
      .fontSize(18)
      .fontColor(this.getKeyFontColor())
      .backgroundColor(this.getKeyBackgroundColor())
      .borderRadius(5)
      .onClick(() => {
        this.onKeyPress(this.key);
      })
  }

  /**
   * Получить отображаемый текст клавиши
   */
  private getKeyLabel(): string {
    if (this.isShift && this.key.shift) {
      return this.key.shift;
    }
    return this.key.label;
  }

  /**
   * Получить ширину клавиши
   */
  private getKeyWidth(): string {
    const baseWidth = 32;
    const width = (this.key.width || 1) * baseWidth;
    return `${width}vp`;
  }

  /**
   * Получить цвет фона клавиши
   */
  private getKeyBackgroundColor(): string {
    switch (this.key.type) {
      case 'shift':
      case 'backspace':
      case 'enter':
        return this.isShift ? '#5B8FF9' : '#E8E8E8';
      case 'switch':
        return '#D8D8D8';
      case 'space':
        return '#FFFFFF';
      default:
        return '#FFFFFF';
    }
  }

  /**
   * Получить цвет текста клавиши
   */
  private getKeyFontColor(): string {
    switch (this.key.type) {
      case 'shift':
      case 'backspace':
      case 'enter':
        return this.isShift ? '#FFFFFF' : '#000000';
      default:
        return '#000000';
    }
  }
}

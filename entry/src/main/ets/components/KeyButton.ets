import { Key } from '../model/KeyboardLayout';
import { ShiftState } from '../model/KeyboardController';

/**
 * Компонент кнопки клавиатуры
 */
@Component
export struct KeyButton {
  @Prop key: Key;
  @Prop shiftState: ShiftState = ShiftState.Off;
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
    if ((this.shiftState === ShiftState.OneShot || this.shiftState === ShiftState.CapsLock) && this.key.shift) {
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
        // OneShot: синий, CapsLock: тёмно-синий
        if (this.shiftState === ShiftState.CapsLock) {
          return '#1E40AF'; // Тёмно-синий для CapsLock
        } else if (this.shiftState === ShiftState.OneShot) {
          return '#5B8FF9'; // Синий для OneShot
        }
        return '#E8E8E8'; // Серый для Off
      case 'backspace':
      case 'enter':
        return '#E8E8E8';
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
        // Белый текст для OneShot и CapsLock
        return (this.shiftState === ShiftState.OneShot || this.shiftState === ShiftState.CapsLock)
          ? '#FFFFFF'
          : '#000000';
      case 'backspace':
      case 'enter':
        return '#000000';
      default:
        return '#000000';
    }
  }
}

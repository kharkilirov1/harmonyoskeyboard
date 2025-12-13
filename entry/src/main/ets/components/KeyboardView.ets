import { KeyboardController, ShiftState } from '../model/KeyboardController';
import { Key } from '../model/KeyboardLayout';
import { KeyButton } from './KeyButton';
import { SuggestionBar } from './SuggestionBar';

/**
 * Главный компонент клавиатуры
 */
@Component
export struct KeyboardView {
  @State controller: KeyboardController = new KeyboardController();
  @State suggestions: string[] = [];
  @State shiftState: ShiftState = ShiftState.Off;

  build() {
    Column() {
      // Панель предложений
      SuggestionBar({
        suggestions: this.suggestions,
        onSuggestionClick: (suggestion: string) => {
          this.handleSuggestionClick(suggestion);
        }
      })

      Divider()
        .height(1)
        .color('#CCCCCC')

      // Клавиатура
      Column() {
        ForEach(this.controller.getCurrentLayout().rows, (row: Key[], rowIndex: number) => {
          Row() {
            ForEach(row, (key: Key, keyIndex: number) => {
              KeyButton({
                key: key,
                shiftState: this.shiftState,
                onKeyPress: (pressedKey: Key) => {
                  this.handleKeyPress(pressedKey);
                }
              })
                .margin({ left: 2, right: 2 })
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 5, bottom: 5 })
        })
      }
      .width('100%')
      .padding({ left: 5, right: 5, top: 10, bottom: 10 })
      .backgroundColor('#D0D0D0')
    }
    .width('100%')
    .height('100%')
  }

  /**
   * Обработка нажатия клавиши
   */
  private async handleKeyPress(key: Key): Promise<void> {
    await this.controller.handleKeyPress(key);

    // Обновляем состояние shift
    this.shiftState = this.controller.getShiftState();

    // Обновляем предложения
    this.updateSuggestions();
  }

  /**
   * Обработка клика по предложению
   */
  private async handleSuggestionClick(suggestion: string): Promise<void> {
    await this.controller.insertSuggestion(suggestion);
    this.updateSuggestions();
  }

  /**
   * Обновить предложения
   */
  private updateSuggestions(): void {
    this.suggestions = this.controller.getSuggestions();
  }

  /**
   * Установить контроллер
   */
  setController(controller: KeyboardController): void {
    this.controller = controller;
  }
}

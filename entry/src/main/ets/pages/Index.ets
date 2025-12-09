import { KeyboardView } from '../components/KeyboardView';

/**
 * Главная страница клавиатуры
 */
@Entry
@Component
struct Index {
  @State message: string = 'Русская клавиатура';

  build() {
    Column() {
      KeyboardView()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#D0D0D0')
  }
}

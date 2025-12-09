import InputMethodExtensionAbility from '@ohos.InputMethodExtensionAbility';
import inputMethodEngine from '@ohos.inputMethodEngine';
import window from '@ohos.window';
import display from '@ohos.display';
import { KeyboardController } from './model/KeyboardController';

/**
 * Главный класс расширения клавиатуры
 */
export default class InputMethodService extends InputMethodExtensionAbility {
  private keyboardController: KeyboardController = new KeyboardController();
  private panel: inputMethodEngine.Panel | null = null;
  private inputMethodEngine: inputMethodEngine.InputMethodEngine | null = null;

  onCreate(want: Record<string, Object>): void {
    console.info('InputMethodService onCreate');
    this.initInputMethodEngine();
  }

  onDestroy(): void {
    console.info('InputMethodService onDestroy');
    if (this.panel) {
      this.panel.hide();
      this.panel = null;
    }
  }

  /**
   * Инициализация движка метода ввода
   */
  private initInputMethodEngine(): void {
    this.inputMethodEngine = inputMethodEngine.getInputMethodEngine();

    // Подписка на события фокуса
    this.inputMethodEngine.on('inputStart', (kbController, textInputClient) => {
      console.info('InputMethodService inputStart');
      this.keyboardController.setInputClient(textInputClient);
      this.showKeyboard();
    });

    this.inputMethodEngine.on('inputStop', () => {
      console.info('InputMethodService inputStop');
      this.hideKeyboard();
      this.keyboardController.setInputClient(null);
    });
  }

  /**
   * Показать клавиатуру
   */
  private async showKeyboard(): Promise<void> {
    try {
      if (!this.panel) {
        await this.createPanel();
      }

      if (this.panel) {
        await this.panel.show();
      }
    } catch (error) {
      console.error('Error showing keyboard:', error);
    }
  }

  /**
   * Скрыть клавиатуру
   */
  private async hideKeyboard(): Promise<void> {
    try {
      if (this.panel) {
        await this.panel.hide();
      }
    } catch (error) {
      console.error('Error hiding keyboard:', error);
    }
  }

  /**
   * Создать панель клавиатуры
   */
  private async createPanel(): Promise<void> {
    try {
      const dis = display.getDefaultDisplaySync();
      const panelInfo: inputMethodEngine.PanelInfo = {
        type: inputMethodEngine.PanelType.SOFT_KEYBOARD,
        flag: inputMethodEngine.PanelFlag.FLG_FIXED
      };

      this.panel = await this.inputMethodEngine!.createPanel(this.context, panelInfo);

      if (this.panel) {
        // Устанавливаем размер панели
        await this.panel.resize(dis.width, Math.floor(dis.height * 0.4));

        // Загружаем UI
        await this.panel.setUiContent('pages/Index');
      }
    } catch (error) {
      console.error('Error creating panel:', error);
    }
  }

  /**
   * Получить контроллер клавиатуры (для использования в UI компонентах)
   */
  getKeyboardController(): KeyboardController {
    return this.keyboardController;
  }
}

import inputMethodEngine from '@ohos.inputMethodEngine';
import { SuggestionEngine } from './SuggestionEngine';
import { Layout, RussianLayout, EnglishLayout, NumberLayout, Key } from './KeyboardLayout';

/**
 * Контроллер клавиатуры
 */
export class KeyboardController {
  private textInputClient: inputMethodEngine.InputClient | null = null;
  private suggestionEngine: SuggestionEngine;
  private currentLayout: Layout;
  private isShiftActive: boolean = false;
  private currentText: string = '';
  private currentLanguage: 'russian' | 'english' = 'russian';

  constructor() {
    this.suggestionEngine = new SuggestionEngine();
    this.currentLayout = RussianLayout;
  }

  /**
   * Установить клиента ввода текста
   */
  setInputClient(client: inputMethodEngine.InputClient | null): void {
    this.textInputClient = client;
  }

  /**
   * Получить текущую раскладку
   */
  getCurrentLayout(): Layout {
    return this.currentLayout;
  }

  /**
   * Переключить язык
   */
  switchLanguage(): void {
    if (this.currentLanguage === 'russian') {
      this.currentLanguage = 'english';
      this.currentLayout = EnglishLayout;
    } else {
      this.currentLanguage = 'russian';
      this.currentLayout = RussianLayout;
    }
    this.isShiftActive = false;
  }

  /**
   * Переключить на цифровую раскладку
   */
  switchToNumbers(): void {
    this.currentLayout = NumberLayout;
  }

  /**
   * Переключить на буквенную раскладку
   */
  switchToLetters(): void {
    if (this.currentLanguage === 'russian') {
      this.currentLayout = RussianLayout;
    } else {
      this.currentLayout = EnglishLayout;
    }
  }

  /**
   * Обработка нажатия клавиши
   */
  async handleKeyPress(key: Key): Promise<void> {
    if (!this.textInputClient) {
      return;
    }

    try {
      switch (key.type) {
        case 'shift':
          this.isShiftActive = !this.isShiftActive;
          break;

        case 'backspace':
          await this.handleBackspace();
          break;

        case 'enter':
          await this.insertText('\n');
          this.suggestionEngine.clearCurrentWord();
          break;

        case 'space':
          await this.insertText(' ');
          this.suggestionEngine.clearCurrentWord();
          break;

        case 'switch':
          if (key.label === '123' || key.label === '#+=') {
            this.switchToNumbers();
          } else if (key.label === 'АБВ' || key.label === 'ABC') {
            this.switchToLetters();
          } else if (key.label === 'EN' || key.label === 'RU') {
            this.switchLanguage();
          }
          break;

        default:
          await this.handleLetterPress(key);
          break;
      }
    } catch (error) {
      console.error('Error handling key press:', error);
    }
  }

  /**
   * Обработка нажатия буквенной клавиши
   */
  private async handleLetterPress(key: Key): Promise<void> {
    let char = key.value;

    if (this.isShiftActive && key.shift) {
      char = key.shift;
      this.isShiftActive = false; // Отключаем shift после ввода одной буквы
    }

    await this.insertText(char);

    // Обновляем предложения, если это буква
    if (key.type === 'letter' || !key.type) {
      this.currentText += char;
      const words = this.currentText.split(/[\s\n,.!?;:]/);
      const currentWord = words[words.length - 1];
      this.suggestionEngine.updateCurrentWord(currentWord);
    }
  }

  /**
   * Обработка backspace
   */
  private async handleBackspace(): Promise<void> {
    if (!this.textInputClient) {
      return;
    }

    try {
      await this.textInputClient.deleteBackward(1);

      if (this.currentText.length > 0) {
        this.currentText = this.currentText.slice(0, -1);
        const words = this.currentText.split(/[\s\n,.!?;:]/);
        const currentWord = words[words.length - 1];
        this.suggestionEngine.updateCurrentWord(currentWord);
      }
    } catch (error) {
      console.error('Error in backspace:', error);
    }
  }

  /**
   * Вставить текст
   */
  private async insertText(text: string): Promise<void> {
    if (!this.textInputClient) {
      return;
    }

    try {
      await this.textInputClient.insertText(text);
    } catch (error) {
      console.error('Error inserting text:', error);
    }
  }

  /**
   * Вставить предложение (suggestion)
   */
  async insertSuggestion(suggestion: string): Promise<void> {
    if (!this.textInputClient) {
      return;
    }

    try {
      // Удаляем текущее неполное слово
      const words = this.currentText.split(/[\s\n,.!?;:]/);
      const currentWord = words[words.length - 1];

      if (currentWord.length > 0) {
        await this.textInputClient.deleteBackward(currentWord.length);
      }

      // Вставляем выбранное предложение
      await this.textInputClient.insertText(suggestion);

      // Обновляем состояние
      this.currentText = this.currentText.slice(0, -currentWord.length) + suggestion;
      this.suggestionEngine.clearCurrentWord();
      this.suggestionEngine.addWord(suggestion); // Обучаем словарь
    } catch (error) {
      console.error('Error inserting suggestion:', error);
    }
  }

  /**
   * Получить текущие предложения
   */
  getSuggestions(): string[] {
    return this.suggestionEngine.getSuggestions(3);
  }

  /**
   * Проверить, активен ли Shift
   */
  isShift(): boolean {
    return this.isShiftActive;
  }

  /**
   * Получить текущий язык
   */
  getCurrentLanguage(): string {
    return this.currentLanguage;
  }
}

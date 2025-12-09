/**
 * Движок для предложений слов
 */
export class SuggestionEngine {
  private dictionary: Map<string, number>;
  private currentWord: string = '';

  constructor() {
    this.dictionary = new Map();
    this.loadDictionary();
  }

  /**
   * Загрузка словаря (пока простой список часто используемых русских слов)
   */
  private loadDictionary(): void {
    const commonWords = [
      'привет', 'пока', 'спасибо', 'хорошо', 'плохо', 'да', 'нет',
      'здравствуйте', 'до свидания', 'добрый', 'день', 'вечер', 'утро',
      'как', 'дела', 'что', 'где', 'когда', 'почему', 'зачем',
      'который', 'можно', 'нужно', 'надо', 'буду', 'будет', 'были',
      'время', 'люди', 'человек', 'год', 'город', 'страна', 'работа',
      'дом', 'семья', 'друг', 'жизнь', 'любовь', 'мир', 'слово',
      'рука', 'нога', 'голова', 'глаз', 'ухо', 'нос', 'рот',
      'большой', 'маленький', 'новый', 'старый', 'хороший', 'плохой',
      'первый', 'второй', 'третий', 'последний', 'другой', 'один',
      'два', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь',
      'девять', 'десять', 'сто', 'тысяча', 'миллион',
      'сегодня', 'вчера', 'завтра', 'сейчас', 'потом', 'скоро',
      'всегда', 'никогда', 'иногда', 'часто', 'редко',
      'очень', 'много', 'мало', 'немного', 'несколько',
      'также', 'тоже', 'еще', 'уже', 'только', 'даже',
      'если', 'чтобы', 'потому', 'поэтому', 'однако', 'хотя',
      'или', 'либо', 'ни', 'не', 'без', 'для', 'из', 'к', 'на',
      'над', 'о', 'об', 'от', 'по', 'под', 'при', 'про', 'с', 'у',
      'через', 'между', 'перед', 'за', 'в', 'во'
    ];

    // Добавляем слова в словарь с частотами (пока все с одинаковым весом)
    commonWords.forEach((word, index) => {
      this.dictionary.set(word.toLowerCase(), commonWords.length - index);
    });
  }

  /**
   * Обновить текущее слово
   */
  updateCurrentWord(word: string): void {
    this.currentWord = word.toLowerCase();
  }

  /**
   * Получить предложения на основе текущего ввода
   */
  getSuggestions(limit: number = 3): string[] {
    if (!this.currentWord || this.currentWord.length === 0) {
      return [];
    }

    const suggestions: { word: string; score: number }[] = [];

    // Ищем слова, начинающиеся с текущего префикса
    this.dictionary.forEach((frequency, word) => {
      if (word.startsWith(this.currentWord) && word !== this.currentWord) {
        suggestions.push({
          word: word,
          score: frequency
        });
      }
    });

    // Сортируем по частоте и возвращаем топ-N
    return suggestions
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map(s => this.capitalize(s.word));
  }

  /**
   * Добавить слово в словарь (для обучения)
   */
  addWord(word: string): void {
    const lowerWord = word.toLowerCase();
    const currentFrequency = this.dictionary.get(lowerWord) || 0;
    this.dictionary.set(lowerWord, currentFrequency + 1);
  }

  /**
   * Очистить текущее слово
   */
  clearCurrentWord(): void {
    this.currentWord = '';
  }

  /**
   * Капитализация первой буквы
   */
  private capitalize(word: string): string {
    if (!word || word.length === 0) {
      return word;
    }
    return word.charAt(0).toUpperCase() + word.slice(1);
  }

  /**
   * Проверка, является ли символ разделителем слов
   */
  static isWordSeparator(char: string): boolean {
    return char === ' ' || char === '\n' || char === '.' || char === ',' ||
           char === '!' || char === '?' || char === ';' || char === ':';
  }
}

/**
 * Представляет одну клавишу на клавиатуре
 */
export interface Key {
  label: string;
  value: string;
  shift?: string;
  width?: number;
  type?: 'letter' | 'number' | 'symbol' | 'space' | 'backspace' | 'enter' | 'shift' | 'switch';
}

/**
 * Раскладка клавиатуры
 */
export interface Layout {
  name: string;
  rows: Key[][];
}

/**
 * Русская QWERTY раскладка
 */
export const RussianLayout: Layout = {
  name: 'russian',
  rows: [
    [
      { label: 'й', value: 'й', shift: 'Й' },
      { label: 'ц', value: 'ц', shift: 'Ц' },
      { label: 'у', value: 'у', shift: 'У' },
      { label: 'к', value: 'к', shift: 'К' },
      { label: 'е', value: 'е', shift: 'Е' },
      { label: 'н', value: 'н', shift: 'Н' },
      { label: 'г', value: 'г', shift: 'Г' },
      { label: 'ш', value: 'ш', shift: 'Ш' },
      { label: 'щ', value: 'щ', shift: 'Щ' },
      { label: 'з', value: 'з', shift: 'З' },
      { label: 'х', value: 'х', shift: 'Х' },
      { label: 'ъ', value: 'ъ', shift: 'Ъ' }
    ],
    [
      { label: 'ф', value: 'ф', shift: 'Ф' },
      { label: 'ы', value: 'ы', shift: 'Ы' },
      { label: 'в', value: 'в', shift: 'В' },
      { label: 'а', value: 'а', shift: 'А' },
      { label: 'п', value: 'п', shift: 'П' },
      { label: 'р', value: 'р', shift: 'Р' },
      { label: 'о', value: 'о', shift: 'О' },
      { label: 'л', value: 'л', shift: 'Л' },
      { label: 'д', value: 'д', shift: 'Д' },
      { label: 'ж', value: 'ж', shift: 'Ж' },
      { label: 'э', value: 'э', shift: 'Э' }
    ],
    [
      { label: '⇧', value: '', type: 'shift', width: 1.5 },
      { label: 'я', value: 'я', shift: 'Я' },
      { label: 'ч', value: 'ч', shift: 'Ч' },
      { label: 'с', value: 'с', shift: 'С' },
      { label: 'м', value: 'м', shift: 'М' },
      { label: 'и', value: 'и', shift: 'И' },
      { label: 'т', value: 'т', shift: 'Т' },
      { label: 'ь', value: 'ь', shift: 'Ь' },
      { label: 'б', value: 'б', shift: 'Б' },
      { label: 'ю', value: 'ю', shift: 'Ю' },
      { label: '⌫', value: '', type: 'backspace', width: 1.5 }
    ],
    [
      { label: '123', value: '', type: 'switch', width: 1.5 },
      { label: 'EN', value: '', type: 'switch', width: 1.5 },
      { label: ' ', value: ' ', type: 'space', width: 5 },
      { label: '.', value: '.' },
      { label: '↵', value: '\n', type: 'enter', width: 2 }
    ]
  ]
};

/**
 * Английская QWERTY раскладка
 */
export const EnglishLayout: Layout = {
  name: 'english',
  rows: [
    [
      { label: 'q', value: 'q', shift: 'Q' },
      { label: 'w', value: 'w', shift: 'W' },
      { label: 'e', value: 'e', shift: 'E' },
      { label: 'r', value: 'r', shift: 'R' },
      { label: 't', value: 't', shift: 'T' },
      { label: 'y', value: 'y', shift: 'Y' },
      { label: 'u', value: 'u', shift: 'U' },
      { label: 'i', value: 'i', shift: 'I' },
      { label: 'o', value: 'o', shift: 'O' },
      { label: 'p', value: 'p', shift: 'P' }
    ],
    [
      { label: 'a', value: 'a', shift: 'A' },
      { label: 's', value: 's', shift: 'S' },
      { label: 'd', value: 'd', shift: 'D' },
      { label: 'f', value: 'f', shift: 'F' },
      { label: 'g', value: 'g', shift: 'G' },
      { label: 'h', value: 'h', shift: 'H' },
      { label: 'j', value: 'j', shift: 'J' },
      { label: 'k', value: 'k', shift: 'K' },
      { label: 'l', value: 'l', shift: 'L' }
    ],
    [
      { label: '⇧', value: '', type: 'shift', width: 1.5 },
      { label: 'z', value: 'z', shift: 'Z' },
      { label: 'x', value: 'x', shift: 'X' },
      { label: 'c', value: 'c', shift: 'C' },
      { label: 'v', value: 'v', shift: 'V' },
      { label: 'b', value: 'b', shift: 'B' },
      { label: 'n', value: 'n', shift: 'N' },
      { label: 'm', value: 'm', shift: 'M' },
      { label: '⌫', value: '', type: 'backspace', width: 1.5 }
    ],
    [
      { label: '123', value: '', type: 'switch', width: 1.5 },
      { label: 'RU', value: '', type: 'switch', width: 1.5 },
      { label: ' ', value: ' ', type: 'space', width: 5 },
      { label: '.', value: '.' },
      { label: '↵', value: '\n', type: 'enter', width: 2 }
    ]
  ]
};

/**
 * Цифровая раскладка
 */
export const NumberLayout: Layout = {
  name: 'number',
  rows: [
    [
      { label: '1', value: '1' },
      { label: '2', value: '2' },
      { label: '3', value: '3' },
      { label: '4', value: '4' },
      { label: '5', value: '5' },
      { label: '6', value: '6' },
      { label: '7', value: '7' },
      { label: '8', value: '8' },
      { label: '9', value: '9' },
      { label: '0', value: '0' }
    ],
    [
      { label: '-', value: '-' },
      { label: '/', value: '/' },
      { label: ':', value: ':' },
      { label: ';', value: ';' },
      { label: '(', value: '(' },
      { label: ')', value: ')' },
      { label: '₽', value: '₽' },
      { label: '&', value: '&' },
      { label: '@', value: '@' }
    ],
    [
      { label: '#+=', value: '', type: 'switch', width: 1.5 },
      { label: '.', value: '.' },
      { label: ',', value: ',' },
      { label: '?', value: '?' },
      { label: '!', value: '!' },
      { label: '\'', value: '\'' },
      { label: '"', value: '"' },
      { label: '⌫', value: '', type: 'backspace', width: 1.5 }
    ],
    [
      { label: 'АБВ', value: '', type: 'switch', width: 1.5 },
      { label: 'RU', value: '', type: 'switch', width: 1.5 },
      { label: ' ', value: ' ', type: 'space', width: 5 },
      { label: '↵', value: '\n', type: 'enter', width: 2 }
    ]
  ]
};

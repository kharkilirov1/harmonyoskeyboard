/**
 * Компонент панели предложений слов
 */
@Component
export struct SuggestionBar {
  @Prop suggestions: string[] = [];
  onSuggestionClick: (suggestion: string) => void = () => {};

  build() {
    Row() {
      if (this.suggestions.length > 0) {
        ForEach(this.suggestions, (suggestion: string, index: number) => {
          Button(suggestion)
            .height(35)
            .fontSize(14)
            .fontColor('#000000')
            .backgroundColor('#F5F5F5')
            .borderRadius(5)
            .padding({ left: 12, right: 12 })
            .margin({ right: 8 })
            .onClick(() => {
              this.onSuggestionClick(suggestion);
            })
        })
      } else {
        Text('Начните вводить текст...')
          .fontSize(12)
          .fontColor('#999999')
          .padding({ left: 12 })
      }
    }
    .width('100%')
    .height(40)
    .padding({ left: 8, right: 8, top: 5, bottom: 5 })
    .backgroundColor('#EFEFEF')
    .justifyContent(FlexAlign.Start)
  }
}

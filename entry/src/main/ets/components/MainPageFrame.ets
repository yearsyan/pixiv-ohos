import { AppNavigator } from '../navigation/AppNavigator';
import { Theme } from '../utils/Theme';
import { BrowseContent } from './BrowseContent';

@Component
export struct MainPageFrame {
  @Prop tab: number = 0;
  @Prop activation: number = 0;
  navigator: AppNavigator = new AppNavigator();
  @State viewportWidth: number = 400;

  private changeTab(tab: number): void { this.navigator.showMain(tab); }

  @Builder
  private navItem(index: number, label: string, icon: Resource) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 5 }) {
        Stack() {
          if (this.tab === index) { Row().width(44).height(29).backgroundColor(Theme.paleBlue).borderRadius(12) }
          Image(icon).width(22).height(22).fillColor(this.tab === index ? Theme.blue : '#8B99AC')
        }.height(30)
        Text(label).fontSize(10).fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.tab === index ? Theme.blue : Theme.secondary)
      }.width('100%')
    }.backgroundColor(Color.Transparent).borderRadius(14).height(66).layoutWeight(1)
      .onClick(() => this.changeTab(index)).accessibilityText(label).id('nav_' + index.toString())
  }

  @Builder
  private bottomBar() {
    Row() {
      this.navItem(0, '发现', $r('app.media.home'))
      this.navItem(1, '搜索', $r('app.media.search'))
      this.navItem(2, '关注', $r('app.media.spark'))
      this.navItem(3, '收藏', $r('app.media.heart'))
      this.navItem(4, '我的', $r('app.media.person'))
    }.width('100%').padding({ left: 10, right: 10, top: 4, bottom: 2 }).backgroundColor(Color.White)
      .border({ width: { top: 1 }, color: Theme.line })
  }

  @Builder
  private railItem(index: number, label: string, icon: Resource) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Image(icon).width(22).height(22).fillColor(this.tab === index ? Theme.blue : Theme.secondary)
        Text(label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.tab === index ? Theme.blue : Theme.secondary)
      }.width('100%').padding({ left: 20 })
    }.height(52).width('100%').borderRadius(14).backgroundColor(this.tab === index ? Theme.paleBlue : Color.Transparent)
      .onClick(() => this.changeTab(index)).id('nav_' + index.toString())
  }

  @Builder
  private sideBar() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Image($r('app.media.app_icon')).width(34).height(34).borderRadius(11)
        Text('pixiv').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Theme.blue)
      }.width('100%').padding({ left: 14, top: 22, bottom: 35 })
      this.railItem(0, '发现灵感', $r('app.media.home'))
      this.railItem(1, '搜索作品', $r('app.media.search'))
      this.railItem(2, '关注动态', $r('app.media.spark'))
      this.railItem(3, '我的收藏', $r('app.media.heart'))
      this.railItem(4, '个人空间', $r('app.media.person'))
      Blank()
      Text('MADE FOR\nHarmonyOS').fontSize(10).lineHeight(18).fontColor(Theme.muted)
        .width('100%').padding({ left: 20, bottom: 28 })
    }.width(192).height('100%').padding({ left: 14, right: 14 }).backgroundColor(Color.White)
      .border({ width: { right: 1 }, color: Theme.line })
  }

  build() {
    Row() {
      if (this.viewportWidth >= 900) { this.sideBar() }
      Column() {
        BrowseContent({ tab: this.tab, activation: this.activation,
          navigator: this.navigator, viewportWidth: this.viewportWidth }).layoutWeight(1)
        if (this.viewportWidth < 900) { this.bottomBar() }
      }.layoutWeight(1).height('100%')
    }.width('100%').height('100%').backgroundColor(Color.White)
      .onAreaChange((_, area: Area) => this.viewportWidth = Number(area.width))
  }
}

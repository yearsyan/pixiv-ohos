import { AppNavigator } from '../navigation/AppNavigator';
import { Theme } from '../utils/Theme';

@Component
export struct AboutPage {
  navigator: AppNavigator = new AppNavigator();

  @Builder
  private iconButton(icon: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Circle }) { Image(icon).width(21).height(21).fillColor(Theme.ink) }
      .width(42).height(42).backgroundColor(Theme.background).onClick(action).accessibilityText(label)
  }

  @Builder
  private about() {
    Column({ space: 24 }) {
      Row() { this.iconButton($r('app.media.arrow_left'), '返回', () => this.navigator.back()); Blank() }.width('100%')
      Image($r('app.media.app_icon')).width(80).height(80).borderRadius(24).margin({ top: 30 })
      Text('Pixiv for HarmonyOS').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
      Text('为创作与喜欢而生').fontSize(14).fontColor(Theme.secondary)
      Text('独立开发的鸿蒙原生客户端，与 pixiv 株式会社无隶属关系。作品与作者信息来自 Pixiv，版权属于原作者。')
        .fontSize(13).lineHeight(23).fontColor(Theme.secondary).textAlign(TextAlign.Center).constraintSize({ maxWidth: 360 })
      Text('游客可浏览公开榜单、搜索和作品详情；登录后使用专属推荐、关注与公开云端收藏。本地收藏仅保存在此设备。')
        .fontSize(13).lineHeight(23).fontColor(Theme.secondary).textAlign(TextAlign.Center).constraintSize({ maxWidth: 360 })
      Text('当前版本展示一般向插画与漫画。').fontSize(12).fontColor(Theme.muted)
      Blank()
      Text('VERSION 1.0.0').fontSize(11).fontColor(Theme.muted).margin({ bottom: 28 })
    }.padding(24).width('100%').height('100%').backgroundColor(Color.White)
  }

  build() {
    NavDestination() { this.about() }
      .hideTitleBar(true).id('destination_about')
      .onBackPressed(() => { this.navigator.back(); return true; })
  }
}

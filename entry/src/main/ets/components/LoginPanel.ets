import { webview } from '@kit.ArkWeb';
import { authService } from '../services/AuthService';
import { errorMessage } from '../services/HttpClient';
import { Theme } from '../utils/Theme';

@Component
export struct LoginPanel {
  onClose: () => void = () => {};
  onSuccess: () => void = () => {};
  @State url: string = '';
  @State busy: boolean = false;
  @State error: string = '';
  @State advanced: boolean = false;
  @State token: string = '';
  @State webStatus: string = '正在打开 Pixiv 登录页面…';
  private controller: webview.WebviewController = new webview.WebviewController();
  private completing: boolean = false;
  private alive: boolean = true;

  aboutToAppear(): void { this.alive = true; }
  aboutToDisappear(): void { this.alive = false; authService.cancelLogin(); this.token = ''; }

  private async startLogin(): Promise<void> {
    this.busy = true;
    this.error = '';
    this.webStatus = '正在打开 Pixiv 登录页面…';
    try { const url = await authService.beginLogin(); if (this.alive) { this.url = url; } }
    catch (error) { if (this.alive) { this.error = errorMessage(error); } }
    this.busy = false;
  }

  private async complete(url: string): Promise<void> {
    if (this.completing) { return; }
    this.completing = true;
    this.busy = true;
    this.url = '';
    try {
      await authService.finishLogin(url);
      if (this.alive) { this.onSuccess(); }
    } catch (error) { this.error = errorMessage(error); }
    this.busy = false;
    this.completing = false;
  }

  private async importToken(): Promise<void> {
    this.busy = true;
    this.error = '';
    const token = this.token;
    this.token = '';
    try { await authService.loginWithRefreshToken(token); if (this.alive) { this.onSuccess(); } }
    catch (error) { this.error = errorMessage(error); }
    this.busy = false;
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.close')).width(22).height(22)
        }.width(44).height(44).backgroundColor(Theme.background).onClick(() => this.onClose()).accessibilityText('关闭登录')
        Text(this.url ? '登录 Pixiv' : '连接你的创作世界').fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor(Theme.ink).layoutWeight(1).textAlign(TextAlign.Center)
        Blank().width(44)
      }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
      if (this.url) {
        Web({ src: this.url, controller: this.controller }).layoutWeight(1).width('100%')
          .javaScriptAccess(true).domStorageAccess(true)
          .onPageEnd(() => this.webStatus = '在 Pixiv 完成登录后会自动返回')
          .onErrorReceive((event) => {
            if (event.request.isMainFrame()) {
              this.error = '登录页面暂时无法连接，请检查网络后重试。';
              this.url = '';
            }
          })
          .onLoadIntercept((event) => {
            const url = event.data.getRequestUrl();
            if (authService.isCallback(url)) { this.complete(url); return true; }
            return !url.startsWith('https://') && !url.startsWith('about:');
          })
        Text(this.webStatus).fontSize(11).fontColor(Theme.secondary).padding(12)
      } else {
        Scroll() {
          Column({ space: 20 }) {
            Image($r('app.media.app_icon')).width(82).height(82).borderRadius(24).margin({ top: 40, bottom: 6 })
            Text('喜欢的世界，\n就在这里。').fontSize(34).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
              .textAlign(TextAlign.Center).lineHeight(47)
            Text('登录后发现专属推荐，关注喜欢的画师，\n让收藏在 Pixiv 与鸿蒙之间同步。')
              .fontSize(14).lineHeight(23).fontColor(Theme.secondary).textAlign(TextAlign.Center)
            if (this.error) {
              Text(this.error).fontSize(13).fontColor('#C04C59').lineHeight(21)
                .padding(16).backgroundColor('#FFF0F2').borderRadius(12).width('100%')
            }
            Button(this.busy ? '正在连接…' : '登录 Pixiv').height(52).width('100%').fontSize(16)
              .fontWeight(FontWeight.Medium).backgroundColor(Theme.blue).enabled(!this.busy)
              .onClick(() => this.startLogin())
            Row({ space: 6 }) {
              Image($r('app.media.lock')).width(13).height(13).fillColor(Theme.secondary)
              Text('凭据保存在鸿蒙安全存储中').fontSize(11).fontColor(Theme.secondary)
            }
            Button('使用已有 Refresh Token').fontSize(12).fontColor(Theme.secondary)
              .backgroundColor(Color.Transparent).onClick(() => this.advanced = !this.advanced)
            if (this.advanced) {
              Column({ space: 12 }) {
                Text('仅填写你自己账号的 Refresh Token').fontSize(12).fontColor(Theme.secondary)
                TextInput({ text: this.token, placeholder: 'Refresh Token' }).type(InputType.Password)
                  .onChange((value: string) => this.token = value).height(48).fontSize(13)
                  .enableAutoFill(false).maxLength(2048)
                Button('连接账号').width('100%').height(44).backgroundColor(Theme.paleBlue)
                  .fontColor(Theme.blue).enabled(!this.busy && this.token.length > 0).onClick(() => this.importToken())
              }.padding(16).borderRadius(16).backgroundColor(Theme.background)
            }
            Button('继续浏览').fontSize(14).fontColor(Theme.blue).backgroundColor(Color.Transparent).onClick(() => this.onClose())
          }.width('100%').constraintSize({ maxWidth: 420 }).padding({ left: 28, right: 28, bottom: 32 })
        }.layoutWeight(1).width('100%')
      }
    }.height('100%').width('100%').backgroundColor(Color.White)
  }
}

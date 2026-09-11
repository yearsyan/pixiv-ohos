import { common } from '@kit.AbilityKit';
import { ImagePage } from '../models/PixivModels';
import { AppNavigator, ViewerRouteParams } from '../navigation/AppNavigator';
import { OriginalImage } from '../components/OriginalImage';
import { pixivApi } from '../services/PixivApi';
import { albumService } from '../services/AlbumService';
import { viewerWindow } from '../services/ViewerWindow';
import { requireOriginal } from '../utils/ViewerGeometry';

@Component
export struct ViewerPage {
  navigator: AppNavigator = new AppNavigator();
  params: ViewerRouteParams = { artworkId: 0, pages: [], index: 0, expectedPages: 1 };
  @State pages: ImagePage[] = [];
  @State current: number = 0;
  @State zoom: number = 1;
  private alive: boolean = true;
  private closing: boolean = false;
  private saving: boolean = false;
  private windowLease: number = 0;

  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { this.alive = false; this.immersive(false); }

  private context(): common.UIAbilityContext { return this.getUIContext().getHostContext() as common.UIAbilityContext; }
  private immersive(enabled: boolean): void {
    if (enabled && !this.windowLease) { this.windowLease = viewerWindow.acquire(this.context()); }
    else if (!enabled && this.windowLease) { viewerWindow.release(this.context(), this.windowLease); this.windowLease = 0; }
  }

  private async load(): Promise<void> {
    try {
      let pages = this.params.pages;
      if (pages.length < this.params.expectedPages || pages.some((page: ImagePage) => !page.original)) {
        pages = await pixivApi.pages(this.params.artworkId);
      }
      if (!this.alive) { return; }
      if (pages.length === 0) { throw new Error('No original pages'); }
      pages.forEach((page: ImagePage) => requireOriginal(page));
      this.current = Math.max(0, Math.min(this.params.index, pages.length - 1));
      this.pages = pages;
    } catch (_) { if (this.alive) { this.failed(); } }
  }

  private close(): void {
    if (this.closing) { return; }
    this.closing = true;
    this.navigator.back();
  }

  private failed(): void {
    if (this.closing || !this.alive) { return; }
    this.close();
    this.getUIContext().getPromptAction().showToast({ message: '原图加载失败，请返回作品页重试。' });
  }

  private async menu(): Promise<void> {
    if (this.saving || !this.pages[this.current]) { return; }
    const page = this.pages[this.current];
    const index = this.current;
    try {
      const result = await this.getUIContext().getPromptAction().showActionMenu({ buttons: [{ text: '保存原图到相册', color: '#172B42' }] });
      if (result.index !== 0 || !this.alive) { return; }
      this.saving = true;
      if (await albumService.saveOriginal(this.context(), page, this.params.artworkId, index)) {
        this.getUIContext().getPromptAction().showToast({ message: '原图已保存到相册' });
      }
    } catch (_) {
      if (this.saving && this.alive) { this.getUIContext().getPromptAction().showToast({ message: '保存原图失败，请重试。' }); }
    } finally { this.saving = false; }
  }

  build() {
    NavDestination() {
      Swiper() {
        ForEach(this.pages, (page: ImagePage, index: number) => {
          OriginalImage({ src: page.original, active: index === this.current, zoom: $zoom,
            onClose: () => this.close(), onMenu: () => this.menu(), onFailure: () => this.failed() })
        }, (page: ImagePage) => page.original)
      }.index(this.current).loop(false).indicator(false).disableSwipe(this.zoom > 1).cachedCount(1)
        .onChange((index: number) => { this.zoom = 1; this.current = index; })
        .width('100%').height('100%').backgroundColor('#000000').id('viewer_pager')
    }.hideTitleBar(true).hideToolBar(true).backgroundColor('#000000').id('destination_viewer')
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .onWillShow(() => this.immersive(true)).onWillHide(() => this.immersive(false))
      .onBackPressed(() => { this.close(); return true; })
  }
}

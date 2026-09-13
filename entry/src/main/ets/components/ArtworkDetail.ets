import { common } from '@kit.AbilityKit';
import { Artwork, ImagePage, emptyArtwork } from '../models/PixivModels';
import { pixivApi } from '../services/PixivApi';
import { albumService } from '../services/AlbumService';
import { ViewerRouteParams } from '../navigation/AppNavigator';
import { libraryStore } from '../services/LibraryStore';
import { errorMessage } from '../services/HttpClient';
import { compactCount } from '../utils/PixivMapper';
import { Theme } from '../utils/Theme';
import { PixivImage } from './PixivImage';
import { DetailImage } from './DetailImage';
import { RelatedWorks } from './RelatedWorks';

@Component
export struct ArtworkDetail {
  @Prop initial: Artwork = emptyArtwork();
  @Prop localCollection: boolean = true;
  @Prop visible: boolean = true;
  onBack: () => void = () => {};
  onArtist: (work: Artwork) => void = () => {};
  onTag: (tag: string) => void = () => {};
  onComments: (work: Artwork) => void = () => {};
  onRelated: (work: Artwork) => void = () => {};
  onChanged: (work: Artwork) => void = () => {};
  onViewer: (params: ViewerRouteParams) => void = () => {};
  @State work: Artwork = emptyArtwork();
  @State pages: ImagePage[] = [];
  @State current: number = 0;
  @State busy: boolean = false;
  @State saved: boolean = false;
  @State error: string = '';
  @State loading: boolean = true;
  @State savingOriginal: boolean = false;
  @State viewportWidth: number = 400;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    this.work = this.initial;
    this.saved = this.localCollection ? libraryStore.isSaved(this.work.id) : this.work.bookmarked;
    this.pages = [{ url: this.work.imageUrl, original: this.work.originalUrl, width: this.work.width, height: this.work.height }];
    this.load();
  }
  aboutToDisappear(): void { this.alive = false; }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const work = await pixivApi.detail(this.initial);
      if (!this.alive) { return; }
      this.work = work;
      this.saved = this.localCollection ? libraryStore.isSaved(work.id) : work.bookmarked;
      this.pages = [{ url: work.imageUrl, original: work.originalUrl, width: work.width, height: work.height }];
      if (work.pageCount > 1) {
        const pages = await pixivApi.pages(work.id);
        if (!this.alive) { return; }
        this.pages = pages;
      }
      await libraryStore.recordView(work);
    } catch (error) {
      if (this.alive) { this.error = errorMessage(error); }
    }
    if (this.alive) { this.loading = false; }
  }

  private async save(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try {
      if (!this.localCollection) {
        await pixivApi.bookmark(this.work.id, this.saved);
        this.saved = !this.saved;
        this.work.bookmarked = this.saved;
      } else { this.saved = await libraryStore.toggleSaved(this.work); }
      this.getUIContext().getPromptAction().showToast({ message: this.saved ?
        (this.localCollection ? '已加入本地收藏' : '已收藏到 Pixiv') : '已取消收藏' });
      this.onChanged(this.work);
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: errorMessage(error) }); }
    this.busy = false;
  }

  private async openOriginal(): Promise<void> {
    try {
      await (this.getUIContext().getHostContext() as common.UIAbilityContext)
        .openLink('https://www.pixiv.net/artworks/' + this.work.id.toString());
    } catch (_) { this.getUIContext().getPromptAction().showToast({ message: '无法打开浏览器' }); }
  }

  private async saveOriginal(): Promise<void> {
    if (this.savingOriginal) { return; }
    this.savingOriginal = true;
    const index = this.current;
    try {
      let page = this.pages[index];
      if (!page?.original) {
        const pages = await pixivApi.pages(this.work.id);
        page = pages[index];
      }
      if (!this.alive || !page) { return; }
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (await albumService.saveOriginal(context, page, this.work.id, index)) {
        this.getUIContext().getPromptAction().showToast({ message: '原图已保存到相册' });
      }
    } catch (_) { this.getUIContext().getPromptAction().showToast({ message: '保存原图失败，请重试。' }); }
    finally { this.savingOriginal = false; }
  }

  @Builder
  private header() {
    Row() {
      Button({ type: ButtonType.Circle }) { Image($r('app.media.arrow_left')).width(23).height(23) }
        .width(44).height(44).backgroundColor(Theme.background).onClick(() => this.onBack()).accessibilityText('返回')
      Text('作品').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.ink).layoutWeight(1).textAlign(TextAlign.Center)
      Button({ type: ButtonType.Circle }) { Image($r('app.media.download')).width(20).height(20) }
        .width(44).height(44).backgroundColor(Theme.background).enabled(!this.savingOriginal)
        .onClick(() => this.saveOriginal()).accessibilityText('保存原图到相册').id('detail_save_original').margin({ right: 8 })
      Button({ type: ButtonType.Circle }) { Image($r('app.media.external')).width(20).height(20) }
        .width(44).height(44).backgroundColor(Theme.background).onClick(() => this.openOriginal()).accessibilityText('在 Pixiv 中打开')
    }.width('100%').padding({ left: 20, right: 20, top: 10, bottom: 10 })
  }

  build() {
    Stack() {
      Column() {
        this.header()
        Scroll() {
          Column({ space: 20 }) {
            Stack({ alignContent: Alignment.BottomEnd }) {
              Swiper() {
                ForEach(this.pages, (page: ImagePage, index: number) => {
                  DetailImage({ preview: page.url, original: page.original, active: this.visible && index === this.current,
                    onOpen: () => this.onViewer({ artworkId: this.work.id, pages: this.pages.slice(),
                      index: this.current, expectedPages: this.work.pageCount }) }).id('detail_preview')
                }, (page: ImagePage) => page.url)
              }.height(Math.min(650, this.viewportWidth * 1.12)).width('100%').loop(false).indicator(false).cachedCount(1)
                .onChange((index: number) => this.current = index)
              Text((this.current + 1).toString() + ' / ' + this.pages.length.toString())
                .fontSize(12).fontColor(Color.White).padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#99213951').borderRadius(20).margin(14)
            }.borderRadius(18).clip(true)
            if (this.error) {
              Row({ space: 8 }) {
                Text(this.error).fontSize(12).fontColor('#C04C59').layoutWeight(1).lineHeight(19)
                Button('重试').fontSize(12).backgroundColor('#FFF0F2').fontColor('#C04C59').onClick(() => this.load())
              }.padding(12).backgroundColor('#FFF5F6').borderRadius(12)
            }
            Row({ space: 14 }) {
              Column({ space: 8 }) {
                Text(this.work.title).fontSize(23).fontWeight(FontWeight.Bold).fontColor(Theme.ink).width('100%')
                Row({ space: 16 }) {
                  Row({ space: 5 }) {
                    Image($r('app.media.heart')).width(14).height(14).fillColor(Theme.secondary)
                    Text(compactCount(this.work.bookmarkCount)).fontSize(12).fontColor(Theme.secondary)
                  }
                  Row({ space: 5 }) {
                    Image($r('app.media.eye')).width(15).height(15).fillColor(Theme.secondary)
                    Text(compactCount(this.work.viewCount)).fontSize(12).fontColor(Theme.secondary)
                  }
                  if (this.loading) { LoadingProgress().width(16).height(16).color(Theme.blue) }
                }
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Column({ space: 5 }) {
                Button({ type: ButtonType.Circle }) {
                  Image(this.saved ? $r('app.media.heart_fill') : $r('app.media.heart')).width(24).height(24)
                    .fillColor(this.saved ? '#FF6484' : Color.White)
                }.width(52).height(52).backgroundColor(this.saved ? '#FFF0F4' : Theme.blue)
                  .enabled(!this.busy).onClick(() => this.save()).accessibilityText(this.saved ? '取消收藏作品' : '收藏作品')
                  .id('detail_save')
                Text(this.localCollection ? '本地收藏' : 'Pixiv 收藏').fontSize(10).fontColor(Theme.secondary)
              }
            }.width('100%')
            Row({ space: 12 }) {
              PixivImage({ src: this.work.avatar, radius: 24 }).width(44).height(44)
              Column({ space: 4 }) {
                Text(this.work.userName).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
                Text('查看画师的更多作品').fontSize(11).fontColor(Theme.secondary)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Image($r('app.media.chevron_right')).width(18).height(18).fillColor(Theme.secondary)
            }.width('100%').padding(16).backgroundColor(Theme.background).borderRadius(16)
              .onClick(() => this.onArtist(this.work)).accessibilityText('查看画师 ' + this.work.userName)
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.work.tags, (tag: string) => {
                Text('# ' + tag).fontSize(12).fontColor(Theme.blue).padding({ left: 11, right: 11, top: 8, bottom: 8 })
                  .backgroundColor(Theme.paleBlue).borderRadius(9).margin({ right: 8, bottom: 8 }).onClick(() => this.onTag(tag))
              }, (tag: string) => tag)
            }.width('100%')
            if (this.work.caption) {
              Text(this.work.caption).fontSize(14).fontColor(Theme.secondary).lineHeight(24).width('100%').copyOption(CopyOptions.LocalDevice)
            }
            Button('查看评论和回复').width('100%').height(46).fontSize(14).fontColor(Theme.blue).backgroundColor(Theme.paleBlue)
              .onClick(() => this.onComments(this.work)).id('detail_comments')
            Text(this.work.createDate.substring(0, 10) + '  ·  ID ' + this.work.id.toString())
              .fontSize(11).fontColor(Theme.muted).width('100%').margin({ bottom: 24 })
            RelatedWorks({ sourceId: this.work.id, onArtwork: this.onRelated })
          }.width('100%').constraintSize({ maxWidth: 880 }).padding({ left: 20, right: 20, top: 8, bottom: 24 })
        }.width('100%').layoutWeight(1).id('detail_scroll')
      }.width('100%').height('100%').backgroundColor(Color.White)
    }.width('100%').height('100%').onAreaChange((_, area: Area) => this.viewportWidth = Number(area.width))
  }
}

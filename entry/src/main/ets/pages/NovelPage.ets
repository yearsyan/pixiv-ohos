import { common } from '@kit.AbilityKit';
import { Novel, ReaderPage, ReaderBlock, emptyNovel } from '../models/ReadingModels';
import { AppNavigator } from '../navigation/AppNavigator';
import { pixivApi } from '../services/PixivApi';
import { authService } from '../services/AuthService';
import { errorMessage } from '../services/HttpClient';
import { readerPages } from '../utils/ReadingMapper';
import { Theme } from '../utils/Theme';
import { PixivImage } from '../components/PixivImage';
import { RelatedWorks } from '../components/RelatedWorks';
import { NovelContents } from '../components/NovelContents';

@Component
export struct NovelPage {
  navigator: AppNavigator = new AppNavigator();
  source: Novel = emptyNovel();
  @State novel: Novel = emptyNovel();
  @State pages: ReaderPage[] = [];
  @State page: number = 0;
  @State loading: boolean = true;
  @State error: string = '';
  @State fontSize: number = 18;
  @State night: boolean = false;
  @State previousId: number = 0;
  @State nextId: number = 0;
  @State captionExpanded: boolean = false;
  @State panel: string = 'read';
  private generation: number = 0;
  private scroller: Scroller = new Scroller();
  private sessionUserId: number = 0;

  aboutToAppear(): void {
    this.sessionUserId = authService.session.userId;
    this.novel = this.source;
    this.fontSize = this.navigator.readerFontSize;
    this.night = this.navigator.readerNight;
    this.load(this.source.id);
  }
  aboutToDisappear(): void { ++this.generation; }

  private resume(): void {
    if (this.sessionUserId !== authService.session.userId) {
      this.sessionUserId = authService.session.userId;
      this.load(this.novel.id);
    }
  }

  private async load(id: number): Promise<void> {
    const generation = ++this.generation;
    this.loading = true; this.error = ''; this.pages = []; this.page = 0; this.previousId = 0; this.nextId = 0;
    this.captionExpanded = false;
    this.panel = 'read';
    if (this.novel.id !== id) {
      const novel = emptyNovel(); novel.id = id; novel.seriesId = this.novel.seriesId; novel.seriesTitle = this.novel.seriesTitle;
      this.novel = novel;
    }
    try {
      const content = await pixivApi.novelContent(id);
      if (generation !== this.generation) { return; }
      this.novel = content.novel; this.pages = readerPages(content.text, content.images);
      this.previousId = content.previousId; this.nextId = content.nextId;
      this.page = Math.min(this.navigator.readingPages.get(id) || 0, Math.max(0, this.pages.length - 1));
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (error) { if (generation === this.generation) { this.error = errorMessage(error); } }
    if (generation === this.generation) { this.loading = false; }
  }

  private turn(page: number): void {
    if (page < 0 || page >= this.pages.length) { return; }
    this.page = page;
    this.navigator.readingPages.set(this.novel.id, page);
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private chapter(id: number): void {
    if (id === this.novel.id) { this.panel = 'read'; }
    else { this.load(id); }
  }

  private font(delta: number): void {
    this.fontSize = Math.min(28, Math.max(14, this.fontSize + delta));
    this.navigator.readerFontSize = this.fontSize;
  }

  private async original(): Promise<void> {
    try {
      await (this.getUIContext().getHostContext() as common.UIAbilityContext)
        .openLink('https://www.pixiv.net/novel/show.php?id=' + this.novel.id.toString());
    } catch (_) { this.getUIContext().getPromptAction().showToast({ message: '无法打开浏览器' }); }
  }

  private ink(): string { return this.night ? '#E2E6EC' : '#29374B'; }
  private paper(): string { return this.night ? '#19212D' : '#FAF7F0'; }
  private secondary(): string { return this.night ? '#A2AFC1' : Theme.secondary; }

  @Builder
  private readerToolbar() {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Circle }) { Image($r('app.media.arrow_left')).width(22).height(22).fillColor(this.ink()) }
        .width(40).height(40).backgroundColor(Color.Transparent).onClick(() => this.navigator.back()).accessibilityText('返回')
      Text('小说').fontSize(17).fontColor(this.ink()).layoutWeight(1)
      Button('A−').fontSize(14).fontColor(this.ink()).backgroundColor(Color.Transparent).onClick(() => this.font(-2))
        .enabled(this.fontSize > 14).accessibilityText('缩小字号')
      Button('A+').fontSize(14).fontColor(this.ink()).backgroundColor(Color.Transparent).onClick(() => this.font(2))
        .enabled(this.fontSize < 28).accessibilityText('放大字号')
      Button(this.night ? '日间' : '夜间').fontSize(12).fontColor(this.ink()).backgroundColor(Color.Transparent)
        .onClick(() => { this.night = !this.night; this.navigator.readerNight = this.night; })
    }.width('100%').padding({ left: 12, right: 12, top: 8, bottom: 8 })
  }

  @Builder
  private readerTabs() {
    Row({ space: 8 }) {
      Button('正文').onClick(() => this.panel = 'read').id('novel_tab_read')
        .fontColor(this.panel === 'read' ? Theme.blue : this.secondary()).backgroundColor(Color.Transparent).layoutWeight(1)
      Button('目录').onClick(() => this.panel = 'contents').id('novel_tab_contents')
        .fontColor(this.panel === 'contents' ? Theme.blue : this.secondary()).backgroundColor(Color.Transparent).layoutWeight(1)
      Button('推荐').onClick(() => this.panel = 'related').id('novel_tab_related')
        .fontColor(this.panel === 'related' ? Theme.blue : this.secondary()).backgroundColor(Color.Transparent).layoutWeight(1)
    }.width('100%').padding({ left: 16, right: 16, bottom: 4 })
  }

  @Builder
  private metadata() {
    Column({ space: 12 }) {
      Text(this.novel.title).fontSize(this.page === 0 ? 25 : 15).fontWeight(FontWeight.Bold).fontColor(this.ink()).width('100%')
        .maxLines(this.page === 0 ? 10000 : 1).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.page === 0) {
        Text(this.novel.userName + ' · ' + this.novel.textCount.toString() + ' 字').fontSize(13).fontColor(this.secondary())
        if (this.novel.seriesTitle) {
          Text(this.novel.seriesTitle + ' ›').fontSize(13).fontColor(Theme.blue).onClick(() => this.panel = 'contents')
        }
      }
      if (this.page === 0 && this.novel.caption) {
        Text(this.novel.caption).fontSize(13).lineHeight(22).fontColor(this.secondary()).width('100%').copyOption(CopyOptions.LocalDevice)
          .maxLines(this.captionExpanded ? 10000 : 3).textOverflow({ overflow: TextOverflow.Ellipsis })
        Button(this.captionExpanded ? '收起简介' : '展开简介').fontSize(11).fontColor(Theme.blue).backgroundColor(Color.Transparent)
          .onClick(() => this.captionExpanded = !this.captionExpanded)
      }
      Row({ space: 10 }) {
        Button('查看评论').fontSize(12).fontColor(Theme.blue).backgroundColor(this.night ? '#25374D' : Theme.paleBlue)
          .onClick(() => this.navigator.openComments({ id: this.novel.id, kind: 'novel', title: this.novel.title })).id('novel_comments')
        Button('原站').fontSize(12).fontColor(this.secondary()).backgroundColor(Color.Transparent).onClick(() => this.original())
      }
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 30 })
  }

  @Builder
  private body() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        this.metadata()
        if (this.pages.length > 0) {
          ForEach(this.pages[this.page].blocks, (block: ReaderBlock) => {
            if (block.kind === 'image') {
              if (block.imageUrl) {
                PixivImage({ src: block.imageUrl, fit: ImageFit.Contain, radius: 8 }).width('100%').height(360)
              }
              Button(block.text).fontSize(13).fontColor(Theme.blue).backgroundColor(this.night ? '#25374D' : Theme.paleBlue)
                .onClick(() => this.original())
            } else {
              Text(block.text).fontSize(block.kind === 'chapter' ? this.fontSize + 3 : this.fontSize)
                .fontWeight(block.kind === 'chapter' ? FontWeight.Bold : FontWeight.Normal)
                .lineHeight(this.fontSize * 1.85).fontColor(this.ink()).width('100%').copyOption(CopyOptions.LocalDevice)
                .margin({ top: block.kind === 'chapter' ? 14 : 0 })
            }
          }, (block: ReaderBlock, index: number) => this.page.toString() + '_' + index.toString())
        } else { Text('这篇小说暂无正文。').fontSize(15).fontColor(this.secondary()) }
        Row({ space: 12 }) {
          if (this.previousId) { Button('上一篇').onClick(() => this.load(this.previousId)).fontColor(Theme.blue).backgroundColor(Color.Transparent) }
          Blank()
          if (this.nextId) { Button('下一篇').onClick(() => this.load(this.nextId)).fontColor(Theme.blue).backgroundColor(Color.Transparent) }
        }.width('100%').margin({ top: 25 })
        if (this.page === this.pages.length - 1) {
          RelatedWorks({ sourceId: this.novel.id, kind: 'novel', night: this.night,
            onNovel: (novel: Novel) => this.navigator.openNovel(novel) })
        }
      }.width('100%').constraintSize({ maxWidth: 760 }).padding({ left: 24, right: 24, top: 18, bottom: 40 })
        .alignItems(HorizontalAlign.Start)
    }.width('100%').layoutWeight(1).id('novel_reader')
  }

  build() {
    NavDestination() {
      Column() {
        this.readerToolbar()
        this.readerTabs()
        if (this.panel === 'contents') {
          NovelContents({ seriesId: this.novel.seriesId, seriesTitle: this.novel.seriesTitle, novelId: this.novel.id,
            pages: this.pages, currentPage: this.page, night: this.night,
            onChapter: (id: number) => this.chapter(id), onPage: (page: number) => { this.panel = 'read'; this.turn(page); } })
            .layoutWeight(1)
        } else if (this.panel === 'related') {
          Scroll() {
            RelatedWorks({ sourceId: this.novel.id, kind: 'novel', night: this.night,
              onNovel: (novel: Novel) => this.navigator.openNovel(novel) }).padding({ left: 24, right: 24 })
          }.width('100%').layoutWeight(1)
        } else {
          if (this.loading) {
            Column({ space: 14 }) {
              LoadingProgress().width(32).height(32).color(Theme.blue)
              Text('正在打开小说…').fontSize(13).fontColor(this.secondary())
            }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          } else if (this.error) {
            Column({ space: 16 }) {
              Text(this.error).fontSize(14).fontColor(this.secondary()).textAlign(TextAlign.Center)
              Button('重试').onClick(() => this.load(this.novel.id)).backgroundColor(Theme.blue)
              if (!authService.loggedIn) { Button('登录 Pixiv').onClick(() => this.navigator.openLogin()).backgroundColor(Theme.blue) }
              Button('在原站查看').onClick(() => this.original()).fontColor(Theme.blue).backgroundColor(Color.Transparent)
            }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).padding(24)
          } else {
            this.body()
            if (this.pages.length > 1) {
              Row({ space: 8 }) {
                Button('上一页').onClick(() => this.turn(this.page - 1)).enabled(this.page > 0)
                  .fontSize(12).fontColor(Theme.blue).backgroundColor(Color.Transparent)
                Text((this.page + 1).toString() + ' / ' + this.pages.length.toString()).fontSize(12).fontColor(this.secondary())
                  .layoutWeight(1).textAlign(TextAlign.Center)
                Button('下一页').onClick(() => this.turn(this.page + 1)).enabled(this.page + 1 < this.pages.length)
                  .fontSize(12).fontColor(Theme.blue).backgroundColor(Color.Transparent)
              }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 }).id('novel_pagination')
            }
          }
        }
      }.width('100%').height('100%').backgroundColor(this.paper())
    }.hideTitleBar(true).id('destination_novel').onShown(() => this.resume())
      .onBackPressed(() => { this.navigator.back(); return true; })
  }
}

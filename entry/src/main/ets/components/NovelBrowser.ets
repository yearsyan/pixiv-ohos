import { Novel } from '../models/ReadingModels';
import { AppNavigator } from '../navigation/AppNavigator';
import { pixivApi } from '../services/PixivApi';
import { errorMessage } from '../services/HttpClient';
import { uniqueNovels } from '../utils/ReadingMapper';
import { compactCount } from '../utils/PixivMapper';
import { Theme } from '../utils/Theme';
import { PixivImage } from './PixivImage';

@Component
export struct NovelBrowser {
  @Prop mode: string = 'discover';
  @Prop word: string = '';
  @Prop sort: string = 'date_desc';
  @Prop @Watch('reload') reloadToken: number = 0;
  navigator: AppNavigator = new AppNavigator();
  @State items: Novel[] = [];
  @State next: string = '';
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State error: string = '';
  @State moreError: string = '';
  private generation: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.reload(); }
  aboutToDisappear(): void { ++this.generation; }

  private async reload(): Promise<void> {
    const generation = ++this.generation;
    this.loading = true; this.loadingMore = false; this.error = ''; this.moreError = ''; this.next = ''; this.items = [];
    try {
      const page = await pixivApi.novels(this.mode, this.word, this.sort);
      if (generation !== this.generation) { return; }
      this.items = page.items; this.next = page.next;
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (error) { if (generation === this.generation) { this.error = errorMessage(error); } }
    if (generation === this.generation) { this.loading = false; }
  }

  private async more(): Promise<void> {
    if (!this.next || this.loading || this.loadingMore || this.moreError) { return; }
    const generation = this.generation;
    const cursor = this.next;
    this.loadingMore = true;
    try {
      const page = await pixivApi.novels(this.mode, this.word, this.sort, cursor);
      if (generation !== this.generation) { return; }
      this.items = uniqueNovels(this.items.concat(page.items));
      this.next = page.next === cursor ? '' : page.next;
    } catch (error) { if (generation === this.generation) { this.moreError = errorMessage(error); } }
    if (generation === this.generation) { this.loadingMore = false; }
  }

  @Builder
  private card(novel: Novel) {
    Row({ space: 14 }) {
      if (novel.cover) { PixivImage({ src: novel.cover, radius: 10 }).width(80).height(112) }
      else {
        Stack() {
          Row().width(80).height(112).backgroundColor(Theme.paleBlue).borderRadius(10)
          Image($r('app.media.book')).width(30).height(30).fillColor(Theme.blue)
        }
      }
      Column({ space: 7 }) {
        Text((novel.rank ? '#' + novel.rank.toString() + '  ' : '') + novel.title)
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.ink).maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(novel.userName).fontSize(12).fontColor(Theme.secondary).maxLines(1)
        if (novel.seriesTitle) {
          Text(novel.seriesTitle).fontSize(11).fontColor(Theme.blue).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(compactCount(novel.textCount) + ' 字 · ' + compactCount(novel.bookmarkCount) + ' 收藏')
          .fontSize(11).fontColor(Theme.muted)
        if (novel.caption) {
          Text(novel.caption).fontSize(12).fontColor(Theme.secondary).maxLines(2).lineHeight(19)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding({ top: 16, bottom: 16 })
      .onClick(() => this.navigator.openNovel(novel)).id('novel_' + novel.id.toString())
  }

  @Builder
  private footer() {
    Column({ space: 10 }) {
      if (this.loadingMore) { LoadingProgress().width(24).height(24).color(Theme.blue) }
      else if (this.moreError) {
        Text(this.moreError).fontSize(12).fontColor(Theme.secondary)
        Button('重试加载').onClick(() => { this.moreError = ''; this.more(); })
          .fontSize(12).fontColor(Theme.blue).backgroundColor(Theme.paleBlue)
      } else if (this.next) {
        Button('更多小说').onClick(() => this.more()).fontSize(12).fontColor(Theme.blue).backgroundColor(Theme.paleBlue)
      } else { Text(this.items.length ? '已经看完全部小说' : '还没有找到小说，试试其他关键词。').fontSize(12).fontColor(Theme.muted) }
    }.width('100%').padding({ top: 18, bottom: 30 })
  }

  build() {
    Column() {
      if (this.loading) {
        Column({ space: 12 }) {
          LoadingProgress().width(32).height(32).color(Theme.blue)
          Text('正在加载小说…').fontSize(13).fontColor(Theme.secondary)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error) {
        Column({ space: 16 }) {
          Text(this.error).fontSize(14).fontColor(Theme.secondary).textAlign(TextAlign.Center)
          Button('重新加载').onClick(() => this.reload()).backgroundColor(Theme.blue)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).padding(24)
      } else {
        List({ scroller: this.scroller }) {
          ForEach(this.items, (novel: Novel) => { ListItem() { this.card(novel) } }, (novel: Novel) => novel.id.toString())
          ListItem() { this.footer() }
        }.width('100%').height('100%').padding({ left: 20, right: 20 })
          .divider({ strokeWidth: 1, color: Theme.line }).onReachEnd(() => this.more())
          .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
          .edgeEffect(EdgeEffect.None).id('novel_list')
      }
    }.width('100%').height('100%')
  }
}

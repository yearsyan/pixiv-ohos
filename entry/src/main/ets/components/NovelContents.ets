import { ReaderPage, NovelChapter } from '../models/ReadingModels';
import { pixivApi } from '../services/PixivApi';
import { errorMessage } from '../services/HttpClient';
import { uniqueChapters } from '../utils/ReadingMapper';
import { Theme } from '../utils/Theme';

@Component
export struct NovelContents {
  @Prop @Watch('reload') seriesId: number = 0;
  @Prop seriesTitle: string = '';
  @Prop novelId: number = 0;
  @Prop pages: ReaderPage[] = [];
  @Prop currentPage: number = 0;
  @Prop night: boolean = false;
  onChapter: (id: number) => void = () => {};
  onPage: (page: number) => void = () => {};
  @State chapters: NovelChapter[] = [];
  @State shown: number = 60;
  @State next: string = '';
  @State loading: boolean = false;
  @State error: string = '';
  private generation: number = 0;

  aboutToAppear(): void { this.reload(); }
  aboutToDisappear(): void { ++this.generation; }

  private reload(): void {
    ++this.generation; this.chapters = []; this.next = ''; this.shown = 60; this.loading = false; this.error = '';
    if (this.seriesId > 0) { this.load(); }
  }

  private async load(): Promise<void> {
    if (this.loading) { return; }
    const generation = ++this.generation;
    const cursor = this.next;
    this.loading = true; this.error = '';
    try {
      const page = await pixivApi.novelChapters(this.seriesId, cursor);
      if (generation !== this.generation) { return; }
      this.chapters = uniqueChapters(this.chapters.concat(page.items)); this.next = page.next === cursor ? '' : page.next;
    } catch (error) { if (generation === this.generation) { this.error = errorMessage(error); } }
    if (generation === this.generation) { this.loading = false; }
  }

  private ink(): string { return this.night ? '#E2E6EC' : Theme.ink; }
  private secondary(): string { return this.night ? '#A2AFC1' : Theme.secondary; }
  private paper(): string { return this.night ? '#25374D' : Theme.paleBlue; }
  private pageTitle(page: ReaderPage, index: number): string {
    return page.blocks.find(block => block.kind === 'chapter')?.text || '第 ' + (index + 1).toString() + ' 页';
  }

  build() {
    List({ space: 6 }) {
      ListItem() { Text('本篇目录').fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.ink()).padding({ top: 16, bottom: 8 }) }
      ForEach(this.pages, (page: ReaderPage, index: number) => {
        ListItem() {
          Row({ space: 10 }) {
            Text(this.pageTitle(page, index)).fontSize(14).fontColor(this.ink()).maxLines(2).layoutWeight(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(index === this.currentPage ? '正在阅读' : (index + 1).toString() + ' / ' + this.pages.length)
              .fontSize(11).fontColor(Theme.blue)
          }.width('100%').padding(15).backgroundColor(index === this.currentPage ? this.paper() : Color.Transparent)
            .borderRadius(10).onClick(() => this.onPage(index)).id('contents_page_' + index)
        }
      }, (_: ReaderPage, index: number) => index.toString())
      ListItem() {
        Column({ space: 8 }) {
          Text('系列其他章节').fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.ink()).width('100%')
          Text(this.seriesId ? this.seriesTitle : '这篇小说未加入系列').fontSize(13).fontColor(this.secondary()).width('100%')
        }.padding({ top: 24, bottom: 12 }).alignItems(HorizontalAlign.Start)
      }
      ForEach(this.chapters.slice(0, this.shown), (chapter: NovelChapter) => {
        ListItem() {
          Row({ space: 10 }) {
            Text(chapter.title).fontSize(14).fontColor(chapter.available ? this.ink() : this.secondary())
              .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            if (chapter.id === this.novelId) { Text('正在阅读').fontSize(11).fontColor(Theme.blue) }
            else if (!chapter.available) { Text('暂不可读').fontSize(11).fontColor(this.secondary()) }
          }.width('100%').padding(15).backgroundColor(chapter.id === this.novelId ? this.paper() : Color.Transparent)
            .borderRadius(10).enabled(chapter.available || chapter.id === this.novelId)
            .onClick(() => this.onChapter(chapter.id)).id('series_chapter_' + chapter.id)
        }
      }, (chapter: NovelChapter) => chapter.id.toString())
      ListItem() {
        Column({ space: 12 }) {
          if (this.loading) { LoadingProgress().width(28).height(28).color(Theme.blue) }
          else if (this.error) {
            Text(this.error).fontSize(13).fontColor(this.secondary())
            Button('重试目录').onClick(() => this.load()).fontColor(Theme.blue).backgroundColor(Color.Transparent)
          } else if (this.shown < this.chapters.length || this.next) {
            Button('更多章节').fontColor(Theme.blue).backgroundColor(Color.Transparent).onClick(() => {
              this.shown += 60;
              if (this.shown > this.chapters.length && this.next) { this.load(); }
            }).id('series_more')
          } else if (this.seriesId) {
            Text(this.chapters.length ? '共 ' + this.chapters.length.toString() + ' 篇' : '暂无可展示的章节')
              .fontSize(12).fontColor(this.secondary())
          }
        }.width('100%').padding({ top: 12, bottom: 36 })
      }
    }.width('100%').height('100%').padding({ left: 24, right: 24 }).id('novel_contents')
  }
}

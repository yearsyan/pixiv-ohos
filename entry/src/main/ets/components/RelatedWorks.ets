import { Artwork } from '../models/PixivModels';
import { Novel } from '../models/ReadingModels';
import { pixivApi } from '../services/PixivApi';
import { errorMessage } from '../services/HttpClient';
import { uniqueArtworks, compactCount } from '../utils/PixivMapper';
import { uniqueNovels } from '../utils/ReadingMapper';
import { Theme } from '../utils/Theme';
import { PixivImage } from './PixivImage';

@Component
export struct RelatedWorks {
  @Prop @Watch('reload') sourceId: number = 0;
  kind: string = 'illust';
  @Prop night: boolean = false;
  onArtwork: (work: Artwork) => void = () => {};
  onNovel: (novel: Novel) => void = () => {};
  @State artworks: Artwork[] = [];
  @State novels: Novel[] = [];
  @State next: string = '';
  @State busy: boolean = false;
  @State error: string = '';
  private generation: number = 0;

  aboutToAppear(): void { this.reload(); }
  aboutToDisappear(): void { ++this.generation; }
  private reload(): void { this.fetch(true); }

  private async fetch(reset: boolean): Promise<void> {
    if (!reset && (this.busy || !this.next)) { return; }
    const generation = reset ? ++this.generation : this.generation;
    if (reset) { this.artworks = []; this.novels = []; this.next = ''; }
    const cursor = this.next;
    this.busy = true; this.error = '';
    try {
      if (this.kind === 'novel') {
        const page = await pixivApi.relatedNovels(this.sourceId, cursor);
        if (generation !== this.generation) { return; }
        this.novels = uniqueNovels(this.novels.concat(page.items)); this.next = page.next === cursor ? '' : page.next;
      } else {
        const page = await pixivApi.relatedArtworks(this.sourceId, cursor);
        if (generation !== this.generation) { return; }
        this.artworks = uniqueArtworks(this.artworks.concat(page.items)); this.next = page.next === cursor ? '' : page.next;
      }
    } catch (error) { if (generation === this.generation) { this.error = errorMessage(error); } }
    if (generation === this.generation) { this.busy = false; }
  }

  private ink(): string { return this.night ? '#E2E6EC' : Theme.ink; }
  private secondary(): string { return this.night ? '#A2AFC1' : Theme.secondary; }

  build() {
    Column({ space: 16 }) {
      Text('你可能还喜欢').fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.ink()).width('100%')
      if (this.kind === 'novel') {
        ForEach(this.novels, (novel: Novel) => {
          Row({ space: 14 }) {
            if (novel.cover) { PixivImage({ src: novel.cover, radius: 8 }).width(64).height(86) }
            Column({ space: 8 }) {
              Text(novel.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.ink()).maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
              Text(novel.userName).fontSize(12).fontColor(this.secondary()).maxLines(1)
              Text(compactCount(novel.textCount) + ' 字').fontSize(11).fontColor(this.secondary())
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%').padding({ top: 8, bottom: 8 }).onClick(() => this.onNovel(novel)).id('related_novel_' + novel.id)
        }, (novel: Novel) => novel.id.toString())
      } else {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.artworks, (work: Artwork) => {
            Column({ space: 7 }) {
              PixivImage({ src: work.imageUrl, radius: 12 }).width('100%').height(170)
              Text(work.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.ink()).maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
              Text(work.userName).fontSize(11).fontColor(this.secondary()).maxLines(1).width('100%')
            }.width('48%').margin({ bottom: 18 }).alignItems(HorizontalAlign.Start)
              .onClick(() => this.onArtwork(work)).id('related_illust_' + work.id)
          }, (work: Artwork) => work.id.toString())
        }.width('100%')
      }
      if (this.busy) { LoadingProgress().width(28).height(28).color(Theme.blue) }
      else if (this.error) {
        Text(this.error).fontSize(13).fontColor(this.secondary())
        Button('重试推荐').fontSize(12).fontColor(Theme.blue).backgroundColor(Color.Transparent)
          .onClick(() => this.fetch(!this.next))
      } else if (this.next) {
        Button('更多推荐').fontSize(13).fontColor(Theme.blue).backgroundColor(Color.Transparent)
          .onClick(() => this.fetch(false)).id('related_more')
      } else {
        Text(this.artworks.length || this.novels.length ? '已经看完全部推荐' : '暂时没有相关推荐')
          .fontSize(12).fontColor(this.secondary())
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 18, bottom: 18 }).id('related_works')
  }
}

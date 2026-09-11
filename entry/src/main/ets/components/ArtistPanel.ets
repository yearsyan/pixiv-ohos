import { Artist, Artwork, emptyArtwork } from '../models/PixivModels';
import { pixivApi } from '../services/PixivApi';
import { authService } from '../services/AuthService';
import { libraryStore } from '../services/LibraryStore';
import { errorMessage } from '../services/HttpClient';
import { uniqueArtworks } from '../utils/PixivMapper';
import { Theme } from '../utils/Theme';
import { PixivImage } from './PixivImage';
import { ArtworkCard } from './ArtworkCard';

@Component
export struct ArtistPanel {
  @Prop source: Artwork = emptyArtwork();
  onBack: () => void = () => {};
  onWork: (work: Artwork) => void = () => {};
  onLogin: () => void = () => {};
  onChanged: (work: Artwork) => void = () => {};
  @State artist: Artist = { id: 0, name: '', avatar: '', comment: '', followed: false, totalIllusts: 0 };
  @State works: Artwork[] = [];
  @State loading: boolean = true;
  @State following: boolean = false;
  @State error: string = '';
  @State next: string = '';
  @State viewportWidth: number = 400;
  @State moreBusy: boolean = false;
  @State savedIds: number[] = [];
  @State headerOffset: number = 0;
  @State profileHeight: number = 112;
  @State scrollViewportHeight: number = 600;
  private pageScroller: Scroller = new Scroller();
  private workScroller: Scroller = new Scroller();
  private saving: Set<number> = new Set<number>();
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    this.savedIds = libraryStore.saved.map((work: Artwork) => work.id);
    this.artist = { id: this.source.userId, name: this.source.userName, avatar: this.source.avatar,
      comment: '', followed: false, totalIllusts: 0 };
    this.load();
  }
  aboutToDisappear(): void { this.alive = false; }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const artist = await pixivApi.artist(this.source.userId);
      const page = await pixivApi.artistWorks(this.source.userId);
      if (!this.alive) { return; }
      this.artist = artist;
      this.works = page.items;
      this.next = page.next;
      if (page.total) { this.artist.totalIllusts = page.total; }
    } catch (error) { if (this.alive) { this.error = errorMessage(error); } }
    if (this.alive) { this.loading = false; }
  }

  private async more(): Promise<void> {
    if (!this.next || this.moreBusy || this.loading) { return; }
    this.moreBusy = true;
    try {
      const page = await pixivApi.artistWorks(this.artist.id, this.next);
      if (this.alive) { this.works = uniqueArtworks(this.works.concat(page.items)); this.next = page.next; }
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: errorMessage(error) }); }
    this.moreBusy = false;
  }

  private async follow(): Promise<void> {
    if (!authService.loggedIn) { this.onLogin(); return; }
    this.following = true;
    try {
      await pixivApi.follow(this.artist.id, this.artist.followed);
      this.artist = { id: this.artist.id, name: this.artist.name, avatar: this.artist.avatar,
        comment: this.artist.comment, followed: !this.artist.followed, totalIllusts: this.artist.totalIllusts };
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: errorMessage(error) }); }
    this.following = false;
  }

  private async save(work: Artwork): Promise<void> {
    if (this.saving.has(work.id)) { return; }
    this.saving.add(work.id);
    try {
      if (authService.loggedIn) {
        await pixivApi.bookmark(work.id, work.bookmarked);
        work.bookmarked = !work.bookmarked;
        this.works = this.works.slice();
      } else {
        await libraryStore.toggleSaved(work);
        this.savedIds = libraryStore.saved.map((item: Artwork) => item.id);
      }
      this.onChanged(work);
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: errorMessage(error) }); }
    this.saving.delete(work.id);
  }

  private columns(): number { return this.viewportWidth >= 1000 ? 5 : this.viewportWidth >= 760 ? 4 : this.viewportWidth >= 560 ? 3 : 2; }
  private collapseProgress(): number { return Math.min(1, this.headerOffset / Math.max(1, this.profileHeight)); }
  private avatarSize(): number { return 64 - 32 * this.collapseProgress(); }

  @Builder
  private footer() {
    if (this.next) {
      Button(this.moreBusy ? '正在加载…' : '更多作品').height(44).fontSize(13).fontColor(Theme.blue)
        .backgroundColor(Theme.paleBlue).margin(16).enabled(!this.moreBusy).onClick(() => this.more())
    }
  }

  @Builder
  private navigationBar() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle }) { Image($r('app.media.arrow_left')).width(22).height(22) }
        .width(44).height(44).backgroundColor(Theme.background).onClick(() => this.onBack()).accessibilityText('返回').id('artist_back')
      Text('画师主页').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.ink).layoutWeight(1).textAlign(TextAlign.Center)
        .opacity(Math.max(0, 1 - 3 * this.collapseProgress()))
      Button(this.artist.followed ? '已关注' : '＋ 关注').width(84).height(36).fontSize(13)
        .backgroundColor(this.artist.followed ? Theme.paleBlue : Theme.blue)
        .fontColor(this.artist.followed ? Theme.blue : Color.White).enabled(!this.following).onClick(() => this.follow()).id('artist_follow')
    }.width('100%').height(64).padding({ left: 20, right: 20 }).backgroundColor(Color.White).id('artist_navigation')
  }

  @Builder
  private identity() {
    // A single identity moves into the navigation bar, avoiding a second avatar
    // or name fading in over the first. Its overlay does not intercept scrolling.
    Row({ space: 16 - 8 * this.collapseProgress() }) {
      PixivImage({ src: this.artist.avatar, radius: this.avatarSize() / 2 })
        .width(this.avatarSize()).height(this.avatarSize()).id('artist_avatar')
      Column({ space: 6 * (1 - this.collapseProgress()) }) {
        Text(this.artist.name).fontSize(24 - 8 * this.collapseProgress()).lineHeight(32 - 12 * this.collapseProgress())
          .fontWeight(FontWeight.Bold).fontColor(Theme.ink).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%').id('artist_name')
        Text(this.artist.totalIllusts > 0 ? this.artist.totalIllusts.toString() + ' 件作品' : 'Pixiv 创作者')
          .fontSize(12).lineHeight(18).height(18 * (1 - this.collapseProgress())).clip(true)
          .opacity(1 - this.collapseProgress()).fontColor(Theme.secondary).id('artist_count')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.height(this.avatarSize())
      .width(Math.max(1, this.viewportWidth - 48 - 52 * this.collapseProgress() - 96 * Math.min(1, 2 * this.collapseProgress())))
      .position({ x: 24 + 52 * this.collapseProgress(), y: 88 - 72 * this.collapseProgress() })
      .hitTestBehavior(HitTestMode.Transparent).id('artist_identity')
  }

  @Builder
  private profile() {
    Column({ space: 14 }) {
      // Reserve the expanded identity's space so animated size changes cannot
      // change the scroll range or feed back into the collapse progress.
      Blank().height(64).width('100%')
      if (this.artist.comment) {
        Text(this.artist.comment).fontSize(12).lineHeight(20).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(Theme.secondary).width('100%').opacity(Math.max(0, 1 - 6 * this.collapseProgress())).id('artist_bio')
          .visibility(this.collapseProgress() >= 1 / 6 ? Visibility.Hidden : Visibility.Visible)
      }
    }.width('100%').padding(24).backgroundColor('#F5FAFF').id('artist_profile')
      .onAreaChange((_, area: Area) => this.profileHeight = Number(area.height))
  }

  @Builder
  private worksToolbar() {
    Row() {
      Text('全部作品').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
      Blank()
      Text('从新到旧').fontSize(12).fontColor(Theme.secondary)
    }.width('100%').padding(20).backgroundColor(Color.White).id('artist_toolbar')
  }

  @Builder
  private worksBody() {
    // Fill the viewport after both the profile and works heading scroll away.
    Column() {
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(Theme.blue).margin(40)
      } else if (this.error) {
        Text(this.error).fontSize(14).fontColor(Theme.secondary).padding(24)
        Button('重试').backgroundColor(Theme.blue).onClick(() => this.load())
      } else if (this.works.length === 0) {
        Text('这位画师暂时没有可展示的作品').fontSize(14).fontColor(Theme.secondary).padding(32)
      } else {
        WaterFlow({ footer: this.footer, scroller: this.workScroller }) {
          ForEach(this.works, (work: Artwork) => {
            FlowItem() {
              ArtworkCard({ artwork: work, cardWidth: (this.viewportWidth - 40 - 12 * (this.columns() - 1)) / this.columns(),
                saved: authService.loggedIn ? work.bookmarked : this.savedIds.includes(work.id),
                onOpen: (item: Artwork) => this.onWork(item), onSave: (item: Artwork) => this.save(item) })
            }
          }, (work: Artwork) => work.id.toString())
        }.columnsTemplate('1fr '.repeat(this.columns()).trim()).columnsGap(12).rowsGap(14)
          .padding({ left: 20, right: 20 }).layoutWeight(1).width('100%').onReachEnd(() => this.more()).id('artist_grid')
          .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
          .edgeEffect(EdgeEffect.None).scrollBar(BarState.Off)
      }
    }.width('100%').height(Math.max(1, this.scrollViewportHeight)).id('artist_body')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        this.navigationBar()
        Scroll(this.pageScroller) {
          Column({ space: 0 }) {
            this.profile()
            this.worksToolbar()
            this.worksBody()
          }.width('100%')
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None).id('artist_scroll')
          .onAreaChange((_, area: Area) => this.scrollViewportHeight = Number(area.height))
          .onDidScroll((_, yOffset: number) => this.headerOffset = Math.max(0, this.headerOffset + yOffset))
      }.width('100%').height('100%')
      this.identity()
    }.width('100%').height('100%').backgroundColor(Color.White)
      .onAreaChange((_, area: Area) => this.viewportWidth = Number(area.width))
  }
}

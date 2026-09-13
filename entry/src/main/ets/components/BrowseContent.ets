import { Artwork, ArtworkPage } from '../models/PixivModels';
import { authService } from '../services/AuthService';
import { pixivApi } from '../services/PixivApi';
import { libraryStore } from '../services/LibraryStore';
import { errorMessage } from '../services/HttpClient';
import { uniqueArtworks } from '../utils/PixivMapper';
import { Theme } from '../utils/Theme';
import { AppNavigator } from '../navigation/AppNavigator';
import { ArtworkCard } from '../components/ArtworkCard';
import { PixivImage } from '../components/PixivImage';
import { NovelBrowser } from './NovelBrowser';

@Component
export struct BrowseContent {
  @Prop tab: number = 0;
  @Prop @Watch('resume') activation: number = 0;
  navigator: AppNavigator = new AppNavigator();
  @State loggedIn: boolean = false;
  @State initialized: boolean = false;
  @Prop viewportWidth: number = 400;
  @State contentWidth: number = 400;
  @State scrollViewportHeight: number = 600;
  @State toolbarHeight: number = 0;
  @State headerOffset: number = 0;
  @State contentType: string = 'illust';
  @State homeMode: string = 'discover';
  @State rankingMode: string = 'day';
  @State query: string = '';
  @State searchTerm: string = '';
  @State searchType: string = 'all';
  @State searchSort: string = 'date_desc';
  @State libraryMode: string = 'local';
  @State items: Artwork[] = [];
  @State next: string = '';
  @State total: number = 0;
  @State dataDate: string = '';
  @State error: string = '';
  @State moreError: string = '';
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State refreshing: boolean = false;
  @State trends: string[] = [];
  @State recentSearches: string[] = [];
  @State savedIds: number[] = [];
  @State userName: string = '';
  @State avatar: string = '';
  @State historyCount: number = 0;
  @State novelReload: number = 0;
  private generation: number = 0;
  private saving: Set<number> = new Set<number>();
  private scroller: Scroller = new Scroller();
  private pageScroller: Scroller = new Scroller();

  private sessionUserId: number = 0;
  private lastRequestId: number = 0;

  aboutToAppear(): void {
    this.updateSession();
    this.sessionUserId = authService.session.userId;
    this.initialized = true;
    this.refreshLibrary();
    if (!this.applyRouteRequest() && this.hasFeed()) { this.reload(); }
    if (this.tab === 1) { this.loadTrends(); }
  }

  aboutToDisappear(): void { ++this.generation; }

  // A destination becoming visible is not a fresh page load. Keep its feed and
  // scroll positions, while reconciling account/library edits made elsewhere.
  private resume(): void {
    if (!this.initialized) { return; }
    const accountChanged = this.sessionUserId !== authService.session.userId;
    this.updateSession();
    this.sessionUserId = authService.session.userId;
    this.refreshLibrary();
    if (accountChanged) {
      ++this.generation;
      this.items = [];
      this.next = '';
      this.error = '';
      this.loading = false;
      if (!this.loggedIn && this.libraryMode === 'cloud') { this.libraryMode = 'local'; }
    }
    if (this.applyRouteRequest()) { return; }
    if (accountChanged && this.hasFeed()) { this.reload(); }
    else if (this.tab === 3 && this.libraryMode !== 'cloud') {
      this.items = (this.libraryMode === 'history' ? libraryStore.history : libraryStore.saved).slice();
      this.total = this.items.length;
    } else if (!this.localCollection()) {
      this.items = this.items.map((work: Artwork) => this.navigator.changedWorks.get(work.id) || work);
      if (this.tab === 3 && this.libraryMode === 'cloud') {
        this.items = this.items.filter((work: Artwork) => work.bookmarked);
      }
    }
  }

  private hasFeed(): boolean {
    return this.tab !== 4 && !(this.tab === 1 && !this.searchTerm) && !(this.tab === 2 && !this.loggedIn);
  }

  private novelFeed(): boolean {
    return (this.tab === 0 && this.contentType === 'novel') || (this.tab === 1 && this.searchType === 'novel');
  }

  private applyRouteRequest(): boolean {
    const request = this.navigator.mainRequest(this.tab);
    if (!request || request.id === this.lastRequestId) { return false; }
    this.lastRequestId = request.id;
    if (this.tab === 1 && request.query) { this.search(request.query); return true; }
    if (this.tab === 3 && request.libraryMode && request.libraryMode !== this.libraryMode) {
      this.libraryMode = request.libraryMode;
      this.reload();
      return true;
    }
    return false;
  }

  private updateSession(): void {
    this.loggedIn = authService.loggedIn;
    this.userName = authService.session.name;
    this.avatar = authService.session.avatar;
  }

  private refreshLibrary(): void {
    this.savedIds = libraryStore.saved.map((work: Artwork) => work.id);
    this.recentSearches = libraryStore.searches.slice();
    this.historyCount = libraryStore.history.length;
  }

  private toast(message: string): void { this.getUIContext().getPromptAction().showToast({ message: message }); }
  private async loadTrends(): Promise<void> {
    try { this.trends = await pixivApi.trends(); } catch (_) { this.trends = []; }
  }

  private openWork(work: Artwork): void { this.navigator.openArtwork(work, this.localCollection()); }
  private changeTab(tab: number): void {
    this.navigator.showMain(tab, '', tab === 3 ? this.libraryMode : '');
  }

  private async page(cursor: string): Promise<ArtworkPage> {
    if (this.tab === 0) {
      return this.homeMode === 'ranking' ? pixivApi.ranking(this.rankingMode, this.contentType, cursor) :
        pixivApi.recommended(this.contentType, cursor);
    }
    if (this.tab === 1) { return pixivApi.search(this.searchTerm, this.searchType, this.searchSort, cursor); }
    if (this.tab === 2) { return pixivApi.following(cursor); }
    if (this.tab === 3 && this.libraryMode === 'cloud') { return pixivApi.bookmarks(cursor); }
    const works = this.libraryMode === 'history' ? libraryStore.history : libraryStore.saved;
    return { items: works.slice(), next: '', date: '', total: works.length };
  }

  private async reload(): Promise<void> {
    if (!this.initialized) { return; }
    const generation = ++this.generation;
    this.loading = true;
    this.loadingMore = false;
    this.error = '';
    this.moreError = '';
    this.next = '';
    this.items = [];
    if (this.novelFeed()) {
      this.novelReload++;
      this.loading = false;
      this.refreshing = false;
      return;
    }
    try {
      const response = await this.page('');
      if (generation !== this.generation) { return; }
      this.items = response.items;
      this.next = response.next;
      this.total = response.total;
      this.dataDate = response.date;
    } catch (error) { if (generation === this.generation) { this.error = errorMessage(error); } }
    if (generation === this.generation) { this.loading = false; this.refreshing = false; }
  }

  private async more(): Promise<void> {
    if (!this.next || this.loading || this.loadingMore || this.moreError) { return; }
    const generation = this.generation;
    this.loadingMore = true;
    try {
      const response = await this.page(this.next);
      if (generation !== this.generation) { return; }
      this.items = uniqueArtworks(this.items.concat(response.items));
      this.next = response.next;
    } catch (error) { if (generation === this.generation) { this.moreError = errorMessage(error); } }
    if (generation === this.generation) { this.loadingMore = false; }
  }

  private search(word: string): void {
    const value = word.trim();
    if (!value) { return; }
    this.query = value;
    this.searchTerm = value;
    libraryStore.recordSearch(value).then(() => this.refreshLibrary()).catch(() => this.toast('搜索记录保存失败'));
    this.getUIContext().getFocusController().clearFocus();
    this.reload();
  }

  private localCollection(): boolean { return !this.loggedIn || (this.tab === 3 && this.libraryMode !== 'cloud'); }
  private isSaved(work: Artwork): boolean { return this.localCollection() ? this.savedIds.includes(work.id) : work.bookmarked; }

  private async save(work: Artwork): Promise<void> {
    if (this.saving.has(work.id)) { return; }
    this.saving.add(work.id);
    const local = this.localCollection();
    try {
      if (local) {
        const saved = await libraryStore.toggleSaved(work);
        this.refreshLibrary();
        this.toast(saved ? '已加入本地收藏' : '已取消本地收藏');
        if (this.tab === 3 && this.libraryMode === 'local') { this.items = libraryStore.saved.slice(); }
      } else {
        await pixivApi.bookmark(work.id, work.bookmarked);
        work.bookmarked = !work.bookmarked;
        this.navigator.rememberArtwork(work);
        this.items = this.items.slice();
        this.toast(work.bookmarked ? '已收藏到 Pixiv' : '已取消 Pixiv 收藏');
        if (this.tab === 3 && this.libraryMode === 'cloud' && !work.bookmarked) {
          this.items = this.items.filter((item: Artwork) => item.id !== work.id);
        }
      }
    } catch (error) { this.toast(errorMessage(error)); }
    this.saving.delete(work.id);
  }

  private columns(): number { return this.contentWidth >= 1100 ? 5 : this.contentWidth >= 820 ? 4 : this.contentWidth >= 580 ? 3 : 2; }
  private collapseProgress(): number { return Math.min(1, this.headerOffset / 140); }
  private headingScale(): number { return 1 - 0.16 * this.collapseProgress(); }
  private canRefresh(): boolean {
    return this.initialized && !this.loading && this.hasFeed();
  }
  private horizontalPadding(): number { return this.contentWidth >= 580 ? 28 : 20; }
  private cardWidth(): number { return (this.contentWidth - this.horizontalPadding() * 2 - 14 * (this.columns() - 1)) / this.columns(); }
  private title(): string {
    return this.tab === 0 ? '发现' : this.tab === 1 ? '搜索' : this.tab === 2 ? '关注动态' : this.tab === 3 ? '收藏夹' : '我的';
  }
  private subtitle(): string {
    if (this.tab === 0) { return this.loggedIn ? '和喜欢的创作，不期而遇。' : '每天，遇见一点心动。'; }
    if (this.tab === 1) { return '从一个关键词，找到整个世界。'; }
    if (this.tab === 2) { return '喜欢的画师，新的灵感。'; }
    return '把心动，留在这里。';
  }

  @Builder
  private iconButton(icon: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Circle }) { Image(icon).width(21).height(21).fillColor(Theme.ink) }
      .width(42).height(42).backgroundColor(Theme.background).onClick(action).accessibilityText(label)
  }

  @Builder
  private topBar() {
    Row({ space: 10 }) {
      if (this.viewportWidth < 900) {
        Image($r('app.media.app_icon')).width(29).height(29).borderRadius(10)
        Text('pixiv').fontSize(25).fontWeight(FontWeight.Bold).fontColor(Theme.blue)
      } else { Text('创作，让世界更有趣。').fontSize(12).fontColor(Theme.secondary) }
      Blank()
      Text(this.loggedIn ? '已连接 Pixiv' : '自由发现 · 游客模式').fontSize(10).fontColor(Theme.secondary)
      this.iconButton($r('app.media.person'), '个人空间', () => this.changeTab(4))
    }.width('100%').height(68).padding({ left: this.horizontalPadding(), right: this.horizontalPadding() })
      .id('page_topbar')
  }

  @Builder
  private heading() {
    Row() {
      Column({ space: 7 }) {
        Text(this.title()).fontSize(30).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
          .scale({ x: this.headingScale(), y: this.headingScale(), centerX: '0%', centerY: '50%' }).id('page_title')
        Text(this.subtitle()).fontSize(12).fontColor(Theme.secondary)
          .opacity(1 - 0.4 * this.collapseProgress())
      }.alignItems(HorizontalAlign.Start)
      Blank()
      if (this.tab === 0) { this.iconButton($r('app.media.search'), '搜索作品', () => this.changeTab(1)) }
      else if (this.tab === 3 && this.libraryMode === 'history' && this.items.length > 0) {
        Button('清空').fontSize(12).fontColor(Theme.secondary).backgroundColor(Theme.background).onClick(() => this.clearHistory())
      }
    }.width('100%').padding({ left: this.horizontalPadding(), right: this.horizontalPadding(), top: 8, bottom: 23 })
      .id('page_heading')
  }

  @Builder
  private chip(label: string, selected: boolean, action: () => void) {
    Button(label).height(34).fontSize(12).fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(selected ? Theme.blue : Theme.secondary).backgroundColor(selected ? Theme.paleBlue : Theme.background)
      .padding({ left: 17, right: 17 }).onClick(action)
  }

  @Builder
  private homeControls() {
    Row({ space: 22 }) {
      Column({ space: 9 }) {
        Text('插画').fontSize(16).fontWeight(this.contentType === 'illust' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.contentType === 'illust' ? Theme.ink : Theme.secondary)
        Row().width(18).height(3).borderRadius(2).backgroundColor(this.contentType === 'illust' ? Theme.blue : Color.Transparent)
      }.onClick(() => { this.contentType = 'illust'; this.reload(); }).id('type_illust')
      Column({ space: 9 }) {
        Text('漫画').fontSize(16).fontWeight(this.contentType === 'manga' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.contentType === 'manga' ? Theme.ink : Theme.secondary)
        Row().width(18).height(3).borderRadius(2).backgroundColor(this.contentType === 'manga' ? Theme.blue : Color.Transparent)
      }.onClick(() => { this.contentType = 'manga'; this.rankingMode = 'day'; this.reload(); }).id('type_manga')
      Column({ space: 9 }) {
        Text('小说').fontSize(16).fontWeight(this.contentType === 'novel' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.contentType === 'novel' ? Theme.ink : Theme.secondary)
        Row().width(18).height(3).borderRadius(2).backgroundColor(this.contentType === 'novel' ? Theme.blue : Color.Transparent)
      }.onClick(() => { this.contentType = 'novel'; this.rankingMode = 'day'; this.reload(); }).id('type_novel')
      Blank()
      Row({ space: 3 }) {
        this.chip('精选', this.homeMode === 'discover', () => { this.homeMode = 'discover'; this.reload(); })
        this.chip('排行榜', this.homeMode === 'ranking', () => { this.homeMode = 'ranking'; this.reload(); })
      }
    }.width('100%').padding({ left: this.horizontalPadding(), right: this.horizontalPadding(), bottom: 16 })
    if (this.homeMode === 'ranking' && this.contentType !== 'manga') {
      Row({ space: 8 }) {
        this.chip('日榜', this.rankingMode === 'day', () => { this.rankingMode = 'day'; this.reload(); })
        this.chip('周榜', this.rankingMode === 'week', () => { this.rankingMode = 'week'; this.reload(); })
        if (this.contentType !== 'novel') {
          this.chip('月榜', this.rankingMode === 'month', () => { this.rankingMode = 'month'; this.reload(); })
        }
        this.chip('新人', this.rankingMode === 'week_rookie', () => { this.rankingMode = 'week_rookie'; this.reload(); })
      }.width('100%').padding({ left: this.horizontalPadding(), right: this.horizontalPadding(), bottom: 15 })
    }
  }

  @Builder
  private homeCaption() {
    Row({ space: 6 }) {
      Image(this.homeMode === 'ranking' ? $r('app.media.ranking') : $r('app.media.spark')).width(15).height(15).fillColor(Theme.blue)
      Text(this.homeMode === 'ranking' ? '人气作品' : this.loggedIn ? '为你推荐' : '今日灵感')
        .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
      Blank()
      Text(this.loggedIn ? '来自你的 Pixiv' : '来自 Pixiv 公开排行榜').fontSize(10).fontColor(Theme.muted)
    }.width('100%').padding({ left: this.horizontalPadding(), right: this.horizontalPadding(), bottom: 14 }).id('home_caption')
  }

  @Builder
  private searchControls() {
    Row({ space: 8 }) {
      Search({ value: this.query, placeholder: '搜索作品、角色或标签' }).searchButton('搜索')
        .height(46).borderRadius(14).backgroundColor(Theme.background).layoutWeight(1)
        .onChange((value: string) => this.query = value).onSubmit((value: string) => this.search(value)).id('search_input')
    }.width('100%').padding({ left: this.horizontalPadding(), right: this.horizontalPadding(), bottom: 18 })
    if (this.searchTerm) {
      Row({ space: 8 }) {
        this.chip('绘画', this.searchType === 'all', () => { this.searchType = 'all'; this.reload(); })
        this.chip('插画', this.searchType === 'illust', () => { this.searchType = 'illust'; this.reload(); })
        this.chip('漫画', this.searchType === 'manga', () => { this.searchType = 'manga'; this.reload(); })
        this.chip('小说', this.searchType === 'novel', () => { this.searchType = 'novel'; this.reload(); })
        Blank()
        Button(this.searchSort === 'date_desc' ? '最新 ↓' : '最早 ↑').height(34).fontSize(11)
          .fontColor(Theme.secondary).backgroundColor(Color.Transparent)
          .onClick(() => { this.searchSort = this.searchSort === 'date_desc' ? 'date_asc' : 'date_desc'; this.reload(); })
      }.width('100%').padding({ left: this.horizontalPadding(), right: this.horizontalPadding(), bottom: 15 }).id('search_filters')
    }
  }

  @Builder
  private libraryControls() {
    Row({ space: 8 }) {
      this.chip('本地收藏', this.libraryMode === 'local', () => { this.libraryMode = 'local'; this.reload(); })
      this.chip('Pixiv 收藏', this.libraryMode === 'cloud', () => {
        if (!this.loggedIn) { this.navigator.openLogin(); } else { this.libraryMode = 'cloud'; this.reload(); }
      })
      this.chip('浏览记录', this.libraryMode === 'history', () => { this.libraryMode = 'history'; this.reload(); })
    }.width('100%').padding({ left: this.horizontalPadding(), right: this.horizontalPadding(), bottom: 20 })
  }

  @Builder
  private searchLanding() {
    Scroll() {
      Column({ space: 25 }) {
        if (this.recentSearches.length > 0) {
          Column({ space: 14 }) {
            Row() {
              Text('最近搜索').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
              Blank()
              Button('清空').fontSize(11).fontColor(Theme.muted).backgroundColor(Color.Transparent)
                .onClick(() => libraryStore.clearSearches().then(() => this.refreshLibrary()).catch(() => this.toast('清空失败')))
            }.width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.recentSearches, (word: string) => {
                Text(word).fontSize(12).fontColor(Theme.secondary).padding({ left: 13, right: 13, top: 9, bottom: 9 })
                  .backgroundColor(Theme.background).borderRadius(10).margin({ right: 8, bottom: 8 }).onClick(() => this.search(word))
              }, (word: string) => word)
            }
          }.width('100%').alignItems(HorizontalAlign.Start)
        }
        Column({ space: 16 }) {
          Row({ space: 7 }) {
            Image($r('app.media.spark')).width(18).height(18).fillColor(Theme.blue)
            Text('发现标签').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
          }.width('100%')
          if (this.trends.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.trends, (tag: string, index: number) => {
                Row({ space: 7 }) {
                  Text((index + 1).toString().padStart(2, '0')).fontSize(11).fontColor(Theme.blue)
                  Text(tag).fontSize(13).fontColor(Theme.ink).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.padding({ left: 14, right: 14, top: 13, bottom: 13 }).backgroundColor('#F1F7FC')
                  .borderRadius(12).margin({ right: 8, bottom: 10 }).onClick(() => this.search(tag))
              }, (tag: string) => tag)
            }.width('100%')
          } else {
            Text('输入感兴趣的关键词，开始探索。').fontSize(13).fontColor(Theme.secondary).padding({ top: 18, bottom: 18 })
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.padding({ left: this.horizontalPadding(), right: this.horizontalPadding(), top: 6, bottom: 30 }).width('100%')
    }.layoutWeight(1).width('100%')
      .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      .edgeEffect(EdgeEffect.None).id('search_landing')
  }

  @Builder
  private emptyState(icon: Resource, title: string, message: string, button: string, action: () => void) {
    Column({ space: 15 }) {
      Stack() {
        Row().width(88).height(88).borderRadius(44).backgroundColor(Theme.paleBlue)
        Image(icon).width(34).height(34).fillColor(Theme.blue)
      }.margin({ bottom: 7 })
      Text(title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
      Text(message).fontSize(13).lineHeight(22).fontColor(Theme.secondary).textAlign(TextAlign.Center)
        .constraintSize({ maxWidth: 290 })
      if (button) { Button(button).fontSize(13).height(43).backgroundColor(Theme.blue).margin({ top: 6 }).onClick(action) }
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).padding({ left: 24, right: 24, bottom: 55 })
  }

  @Builder
  private gridFooter() {
    Column({ space: 8 }) {
      if (this.loadingMore) {
        LoadingProgress().width(24).height(24).color(Theme.blue)
      } else if (this.moreError) {
        Text(this.moreError).fontSize(12).fontColor(Theme.secondary)
        Button('重试加载').fontSize(12).fontColor(Theme.blue).backgroundColor(Theme.paleBlue)
          .onClick(() => { this.moreError = ''; this.more(); })
      } else if (this.next) {
        Button('继续发现').fontSize(12).fontColor(Theme.blue).backgroundColor(Theme.paleBlue).onClick(() => this.more())
      } else { Text('已经看到这里的全部作品了').fontSize(11).fontColor(Theme.muted) }
    }.padding({ top: 18, bottom: 24 }).width('100%')
  }

  @Builder
  private artworkGrid() {
    if (this.loading) {
      Column({ space: 16 }) {
        LoadingProgress().width(34).height(34).color(Theme.blue)
        Text('正在寻找灵感…').fontSize(13).fontColor(Theme.secondary)
      }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).padding({ bottom: 60 })
    } else if (this.error) {
      this.emptyState($r('app.media.cloud'), '连接暂时中断', this.error, '重新加载', () => this.reload())
    } else if (this.items.length === 0) {
      this.emptyState(this.tab === 3 ? $r('app.media.heart') : $r('app.media.search'),
        this.tab === 3 ? (this.libraryMode === 'history' ? '灵感之旅，刚刚开始' : '留一些喜欢在这里') : '还没有找到作品',
        this.tab === 3 ? (this.libraryMode === 'history' ? '浏览过的作品会出现在这里。' : '点亮作品旁的爱心，下次就能轻松找到。') :
          '试试其他关键词，或稍后刷新看看。', this.next ? '继续加载' : '去发现',
        () => { if (this.next) { this.more(); } else { this.changeTab(0); } })
    } else {
      WaterFlow({ scroller: this.scroller, footer: this.gridFooter }) {
          ForEach(this.items, (work: Artwork) => {
            FlowItem() {
              ArtworkCard({ artwork: work, saved: this.isSaved(work), cardWidth: this.cardWidth(),
                showRank: this.tab === 0 && this.homeMode === 'ranking',
                onOpen: (item: Artwork) => this.openWork(item), onSave: (item: Artwork) => this.save(item) })
            }
          }, (work: Artwork) => work.id.toString())
      }.columnsTemplate('1fr '.repeat(this.columns()).trim()).columnsGap(14).rowsGap(15)
        .width('100%').height('100%').padding({ left: this.horizontalPadding(), right: this.horizontalPadding() })
        .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .onReachEnd(() => this.more()).edgeEffect(EdgeEffect.None).id('artwork_grid')
    }
  }

  private async clearHistory(): Promise<void> {
    const result = await this.getUIContext().getPromptAction().showDialog({ title: '清空浏览记录？',
      message: '已收藏的作品会保留。', buttons: [{ text: '取消', color: Theme.secondary }, { text: '清空', color: Theme.blue }] });
    if (result.index === 1) {
      try { await libraryStore.clearHistory(); this.refreshLibrary(); this.reload(); } catch (_) { this.toast('清空失败，请重试'); }
    }
  }

  private async logout(): Promise<void> {
    const result = await this.getUIContext().getPromptAction().showDialog({ title: '退出 Pixiv 账号？',
      message: '本地收藏和浏览记录会保留。', buttons: [{ text: '取消', color: Theme.secondary }, { text: '退出', color: Theme.blue }] });
    if (result.index === 1) {
      try {
        await authService.logout(); this.updateSession(); this.libraryMode = 'local';
        this.items = []; this.next = ''; ++this.generation; this.loadTrends();
      } catch (error) { this.toast(errorMessage(error)); }
    }
  }

  @Builder
  private menuRow(icon: Resource, title: string, detail: string, action: () => void) {
    Row({ space: 14 }) {
      Stack() {
        Row().width(40).height(40).borderRadius(12).backgroundColor(Theme.paleBlue)
        Image(icon).width(20).height(20).fillColor(Theme.blue)
      }
      Text(title).fontSize(14).fontColor(Theme.ink).layoutWeight(1)
      Text(detail).fontSize(11).fontColor(Theme.secondary)
      Image($r('app.media.chevron_right')).width(16).height(16).fillColor(Theme.muted)
    }.width('100%').padding({ left: 17, right: 17, top: 16, bottom: 16 })
      .backgroundColor(Color.White).borderRadius(14).onClick(action)
  }

  @Builder
  private profile() {
    Scroll() {
      Column({ space: 20 }) {
        Column({ space: 18 }) {
          Row({ space: 17 }) {
            if (this.loggedIn && this.avatar) { PixivImage({ src: this.avatar, radius: 30 }).width(60).height(60) }
            else {
              Stack() {
                Row().width(60).height(60).borderRadius(30).backgroundColor('#D9EFFF')
                Image($r('app.media.person')).width(28).height(28).fillColor(Theme.blue)
              }
            }
            Column({ space: 7 }) {
              Text(this.loggedIn ? this.userName : '你好，创作同好').fontSize(23).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
              Text(this.loggedIn ? '欢迎回到你的灵感空间' : '登录，让喜欢的创作常伴左右').fontSize(12).fontColor(Theme.secondary)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%')
          if (!this.loggedIn) {
            Button('登录 Pixiv').width('100%').height(46).fontSize(14).backgroundColor(Theme.blue).onClick(() => this.navigator.openLogin())
          }
          Row() {
            Column({ space: 5 }) {
              Text(this.savedIds.length.toString()).fontSize(25).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
              Text('本地收藏').fontSize(11).fontColor(Theme.secondary)
            }.layoutWeight(1).onClick(() => { this.libraryMode = 'local'; this.changeTab(3); })
            Divider().vertical(true).height(32).color('#D8E8F5')
            Column({ space: 5 }) {
              Text(this.historyCount.toString()).fontSize(25).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
              Text('浏览记录').fontSize(11).fontColor(Theme.secondary)
            }.layoutWeight(1).onClick(() => { this.libraryMode = 'history'; this.changeTab(3); })
          }.width('100%').padding({ top: 6 })
        }.width('100%').padding(24).borderRadius(22).backgroundColor('#F0F8FF')
        Column({ space: 2 }) {
          this.menuRow($r('app.media.heart'), '我的本地收藏', this.savedIds.length.toString() + ' 件', () => { this.libraryMode = 'local'; this.changeTab(3); })
          this.menuRow($r('app.media.cloud'), 'Pixiv 云端收藏', this.loggedIn ? '公开收藏' : '登录后同步', () => {
            if (this.loggedIn) { this.libraryMode = 'cloud'; this.changeTab(3); } else { this.navigator.openLogin(); }
          })
          this.menuRow($r('app.media.history'), '浏览记录', '保留最近 150 件', () => { this.libraryMode = 'history'; this.changeTab(3); })
          this.menuRow($r('app.media.book'), '关于应用', '1.0.0', () => this.navigator.openAbout())
        }.width('100%').padding(4).backgroundColor(Theme.background).borderRadius(18)
        if (this.loggedIn) {
          Button('退出账号').width('100%').height(45).fontSize(13).fontColor(Theme.secondary)
            .backgroundColor(Theme.background).onClick(() => this.logout())
        }
        Text('让每一份喜欢，都有归处。').fontSize(11).fontColor(Theme.muted).margin({ top: 8, bottom: 18 })
      }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: this.horizontalPadding(), right: this.horizontalPadding(), top: 14, bottom: 20 })
    }.width('100%').layoutWeight(1)
      .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      .edgeEffect(EdgeEffect.None)
  }

  @Builder
  private stickyControls() {
    Column() {
      if (this.tab === 0) { this.homeControls() }
      if (this.tab === 1) { this.searchControls() }
      if (this.tab === 3) { this.libraryControls() }
    }.width('100%').padding({ top: this.tab === 0 || this.tab === 1 || this.tab === 3 ? 8 : 0 })
      .backgroundColor(Color.White).id('sticky_controls')
      .onAreaChange((_, area: Area) => this.toolbarHeight = Number(area.height))
  }

  @Builder
  private scrollingPage() {
    Refresh({ refreshing: $$this.refreshing }) {
      Scroll(this.pageScroller) {
        Column() {
          Column() {
            this.topBar()
            if (this.tab !== 4) { this.heading() }
            if (this.tab === 0) { this.homeCaption() }
          }.width('100%').id('page_intro')
          this.stickyControls()
          // Bounding the inner viewport makes the outer scroll stop exactly when the controls reach the top.
          // Nested scrolling then continues through the artwork, with a single toolbar and no overlay copies.
          Column() {
            if (this.tab === 4) { this.profile() }
            else if (this.tab === 1 && !this.searchTerm) { this.searchLanding() }
            else if (this.tab === 2 && !this.loggedIn) {
              this.emptyState($r('app.media.spark'), '与喜欢的画师保持相遇', '登录 Pixiv，关注画师的新作品会出现在这里。', '登录 Pixiv', () => this.navigator.openLogin())
            } else if (this.novelFeed()) {
              NovelBrowser({ navigator: this.navigator, mode: this.homeMode === 'ranking' ? this.rankingMode : 'discover',
                word: this.tab === 1 ? this.searchTerm : '', sort: this.searchSort, reloadToken: this.novelReload })
            } else { this.artworkGrid() }
          }.width('100%').height(Math.max(1, this.scrollViewportHeight - this.toolbarHeight)).id('page_body')
        }.width('100%')
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
        .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .onAreaChange((_, area: Area) => this.scrollViewportHeight = Number(area.height))
        .onDidScroll((_, yOffset: number) => this.headerOffset = Math.max(0, this.headerOffset + yOffset))
        .onScrollStop(() => this.headerOffset = Math.max(0, this.pageScroller.currentOffset().yOffset))
        .id('page_scroll')
    }.width('100%').layoutWeight(1).pullToRefresh(this.canRefresh())
      .onRefreshing(() => { if (this.canRefresh()) { this.reload(); } else { this.refreshing = false; } })
  }

  build() {
    Column() { this.scrollingPage() }
      .width('100%').height('100%').backgroundColor(Color.White)
      .onAreaChange((_, area: Area) => this.contentWidth = Number(area.width))
  }
}

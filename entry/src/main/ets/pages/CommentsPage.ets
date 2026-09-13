import { CommentTarget, WorkComment } from '../models/ReadingModels';
import { AppNavigator } from '../navigation/AppNavigator';
import { pixivApi } from '../services/PixivApi';
import { authService } from '../services/AuthService';
import { errorMessage } from '../services/HttpClient';
import { uniqueComments } from '../utils/ReadingMapper';
import { Theme } from '../utils/Theme';
import { PixivImage } from '../components/PixivImage';

@Component
export struct CommentsPage {
  navigator: AppNavigator = new AppNavigator();
  target: CommentTarget = { id: 0, kind: 'illust', title: '' };
  @State items: WorkComment[] = [];
  @State next: string = '';
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State error: string = '';
  @State moreError: string = '';
  private generation: number = 0;
  private sessionUserId: number = 0;

  aboutToAppear(): void { this.sessionUserId = authService.session.userId; this.load(); }
  aboutToDisappear(): void { ++this.generation; }

  private resume(): void {
    if (this.sessionUserId !== authService.session.userId) {
      this.sessionUserId = authService.session.userId;
      this.load();
    }
  }

  private async load(): Promise<void> {
    const generation = ++this.generation;
    this.loading = true; this.loadingMore = false; this.error = ''; this.moreError = ''; this.next = ''; this.items = [];
    try {
      const page = await pixivApi.comments(this.target.id, this.target.kind, this.target.parent?.id || 0);
      if (generation !== this.generation) { return; }
      this.items = page.items; this.next = page.next;
    } catch (error) { if (generation === this.generation) { this.error = errorMessage(error); } }
    if (generation === this.generation) { this.loading = false; }
  }

  private async more(): Promise<void> {
    if (!this.next || this.loading || this.loadingMore || this.moreError) { return; }
    const generation = this.generation;
    const cursor = this.next;
    this.loadingMore = true;
    try {
      const page = await pixivApi.comments(this.target.id, this.target.kind, this.target.parent?.id || 0, cursor);
      if (generation !== this.generation) { return; }
      this.items = uniqueComments(this.items.concat(page.items)); this.next = page.next === cursor ? '' : page.next;
    } catch (error) { if (generation === this.generation) { this.moreError = errorMessage(error); } }
    if (generation === this.generation) { this.loadingMore = false; }
  }

  @Builder
  private comment(item: WorkComment, showReplies: boolean) {
    Row({ space: 12 }) {
      PixivImage({ src: item.avatar, radius: 20 }).width(38).height(38)
      Column({ space: 9 }) {
        Text(item.userName).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
        if (item.replyTo) { Text('回复 ' + item.replyTo).fontSize(11).fontColor(Theme.blue) }
        if (item.text) { Text(item.text).fontSize(15).fontColor(Theme.ink).lineHeight(25).width('100%').copyOption(CopyOptions.LocalDevice) }
        if (item.stampUrl) { PixivImage({ src: item.stampUrl, fit: ImageFit.Contain, radius: 8 }).width(90).height(90).accessibilityText('Pixiv 表情贴图') }
        if (!item.text && !item.stampUrl) { Text('评论内容不可用').fontSize(13).fontColor(Theme.muted) }
        Row() {
          Text(item.date.replace('T', ' ').substring(0, 16)).fontSize(11).fontColor(Theme.muted)
          Blank()
          if (showReplies && item.hasReplies) {
            Button('查看回复').fontSize(12).fontColor(Theme.blue).backgroundColor(Theme.paleBlue)
              .onClick(() => this.navigator.openComments({ id: this.target.id, kind: this.target.kind,
                title: this.target.title, parent: item })).id('replies_' + item.id.toString())
          }
        }.width('100%')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.alignItems(VerticalAlign.Top).width('100%').padding({ top: 18, bottom: 18 })
  }

  @Builder
  private footer() {
    Column({ space: 12 }) {
      if (this.loadingMore) { LoadingProgress().width(24).height(24).color(Theme.blue) }
      else if (this.moreError) {
        Text(this.moreError).fontSize(12).fontColor(Theme.secondary)
        Button('重试加载').fontSize(12).fontColor(Theme.blue).backgroundColor(Theme.paleBlue)
          .onClick(() => { this.moreError = ''; this.more(); })
      } else if (this.next) {
        Button('加载更多').fontSize(12).fontColor(Theme.blue).backgroundColor(Theme.paleBlue).onClick(() => this.more())
      } else { Text(this.items.length ? '已经看完全部评论' : this.target.parent ? '暂无回复' : '暂无评论')
        .fontSize(13).fontColor(Theme.muted) }
    }.width('100%').padding({ top: 20, bottom: 30 })
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 10 }) {
          Button({ type: ButtonType.Circle }) { Image($r('app.media.arrow_left')).width(22).height(22) }
            .width(42).height(42).backgroundColor(Theme.background).onClick(() => this.navigator.back()).accessibilityText('返回')
          Column({ space: 3 }) {
            Text(this.target.parent ? '评论回复' : '评论').fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            Text(this.target.title).fontSize(11).fontColor(Theme.secondary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('刷新').fontSize(12).fontColor(Theme.blue).backgroundColor(Theme.paleBlue).onClick(() => this.load()).enabled(!this.loading)
        }.width('100%').padding({ left: 20, right: 20, top: 10, bottom: 10 })
        if (this.loading) {
          Column() { LoadingProgress().width(32).height(32).color(Theme.blue) }
            .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.error) {
          Column({ space: 16 }) {
            Text(this.error).fontSize(14).fontColor(Theme.secondary).textAlign(TextAlign.Center)
            Button('重试').onClick(() => this.load()).backgroundColor(Theme.blue)
            if (!authService.loggedIn) {
              Button('登录 Pixiv').onClick(() => this.navigator.openLogin()).fontColor(Theme.blue).backgroundColor(Theme.paleBlue)
            }
          }.padding(24).width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List() {
            if (this.target.parent) {
              ListItem() { this.comment(this.target.parent, false) }.backgroundColor(Theme.background)
            }
            ForEach(this.items, (item: WorkComment) => { ListItem() { this.comment(item, !this.target.parent) } },
              (item: WorkComment) => item.id.toString())
            ListItem() { this.footer() }
          }.width('100%').layoutWeight(1).padding({ left: 20, right: 20 })
            .divider({ strokeWidth: 1, color: Theme.line }).onReachEnd(() => this.more()).id('comment_list')
        }
      }.width('100%').height('100%').backgroundColor(Color.White)
    }.hideTitleBar(true).id('destination_comments').onShown(() => this.resume())
      .onBackPressed(() => { this.navigator.back(); return true; })
  }
}

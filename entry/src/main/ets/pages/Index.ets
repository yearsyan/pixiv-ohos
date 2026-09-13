import { common } from '@kit.AbilityKit';
import { Artwork } from '../models/PixivModels';
import { authService } from '../services/AuthService';
import { libraryStore } from '../services/LibraryStore';
import { imageCache } from '../services/ImageCache';
import { errorMessage } from '../services/HttpClient';
import { AppNavigator, ArtworkRouteParams, ViewerRouteParams, Routes } from '../navigation/AppNavigator';
import { Theme } from '../utils/Theme';
import { DiscoverPage } from './DiscoverPage';
import { SearchPage } from './SearchPage';
import { FollowingPage } from './FollowingPage';
import { LibraryPage } from './LibraryPage';
import { ProfilePage } from './ProfilePage';
import { ArtworkPage } from './ArtworkPage';
import { ArtistPage } from './ArtistPage';
import { LoginPage } from './LoginPage';
import { AboutPage } from './AboutPage';
import { ViewerPage } from './ViewerPage';
import { Novel, CommentTarget } from '../models/ReadingModels';
import { NovelPage } from './NovelPage';
import { CommentsPage } from './CommentsPage';

@Entry
@Component
struct Index {
  private navigator: AppNavigator = new AppNavigator();
  @State initialized: boolean = false;

  aboutToAppear(): void { this.initialize(); }

  private toast(message: string): void { this.getUIContext().getPromptAction().showToast({ message: message }); }

  private async initialize(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.navigator.onExit = () => context.moveAbilityToBackground().catch(() => this.toast('暂时无法返回桌面'));
    imageCache.initialize(context.cacheDir);
    try { await libraryStore.initialize(context); } catch (_) { this.toast('本地资料读取失败，收藏功能可能暂时不可用'); }
    try { await authService.initialize(); } catch (error) { this.toast(errorMessage(error)); }
    this.initialized = true;
    this.navigator.showMain(0);
  }

  @Builder
  private destination(name: string, param: Object) {
    if (name === Routes.main[0]) { DiscoverPage({ navigator: this.navigator }) }
    else if (name === Routes.main[1]) { SearchPage({ navigator: this.navigator }) }
    else if (name === Routes.main[2]) { FollowingPage({ navigator: this.navigator }) }
    else if (name === Routes.main[3]) { LibraryPage({ navigator: this.navigator }) }
    else if (name === Routes.main[4]) { ProfilePage({ navigator: this.navigator }) }
    else if (name === Routes.artwork) { ArtworkPage({ navigator: this.navigator, params: param as ArtworkRouteParams }) }
    else if (name === Routes.viewer) { ViewerPage({ navigator: this.navigator, params: param as ViewerRouteParams }) }
    else if (name === Routes.artist) { ArtistPage({ navigator: this.navigator, source: param as Artwork }) }
    else if (name === Routes.login) { LoginPage({ navigator: this.navigator }) }
    else if (name === Routes.about) { AboutPage({ navigator: this.navigator }) }
    else if (name === Routes.novel) { NovelPage({ navigator: this.navigator, source: param as Novel }) }
    else if (name === Routes.comments) { CommentsPage({ navigator: this.navigator, target: param as CommentTarget }) }
  }

  build() {
    Stack() {
      Navigation(this.navigator.paths) {}
        .navDestination(this.destination).mode(NavigationMode.Stack).hideNavBar(true).hideTitleBar(true)
        .width('100%').height('100%').id('app_navigation')
      if (!this.initialized) { LoadingProgress().width(36).height(36).color(Theme.blue) }
    }.width('100%').height('100%').backgroundColor(Color.White)
  }
}

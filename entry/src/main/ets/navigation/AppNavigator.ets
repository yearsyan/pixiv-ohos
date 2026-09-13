import { Artwork, ImagePage } from '../models/PixivModels';
import { Novel, CommentTarget } from '../models/ReadingModels';

export class Routes {
  static readonly main: string[] = ['discover', 'search', 'following', 'library', 'profile'];
  static readonly artwork: string = 'artwork';
  static readonly viewer: string = 'viewer';
  static readonly artist: string = 'artist';
  static readonly login: string = 'login';
  static readonly about: string = 'about';
  static readonly novel: string = 'novel';
  static readonly comments: string = 'comments';
}

export interface MainPageRequest {
  id: number;
  query: string;
  libraryMode: string;
}

export interface ArtworkRouteParams {
  artwork: Artwork;
  localCollection: boolean;
}

export interface ViewerRouteParams {
  artworkId: number;
  pages: ImagePage[];
  index: number;
  expectedPages: number;
}

export class AppNavigator {
  readonly paths: NavPathStack = new NavPathStack();
  readonly changedWorks: Map<number, Artwork> = new Map<number, Artwork>();
  readonly readingPages: Map<number, number> = new Map<number, number>();
  readerFontSize: number = 18;
  readerNight: boolean = false;
  onExit: () => void = () => {};
  private requestId: number = 0;

  showMain(index: number, query: string = '', libraryMode: string = ''): void {
    const request: MainPageRequest = { id: ++this.requestId, query: query, libraryMode: libraryMode };
    // Move the existing destination rather than replacing it: its component,
    // loaded pages, filters, focus and both scroll controllers stay alive.
    this.paths.pushPath({ name: Routes.main[index], param: request },
      { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON, animated: false });
  }

  mainRequest(index: number): MainPageRequest | undefined {
    const requests = this.paths.getParamByName(Routes.main[index]) as MainPageRequest[];
    return requests.length > 0 ? requests[0] : undefined;
  }

  openArtwork(artwork: Artwork, localCollection: boolean): void {
    const params: ArtworkRouteParams = { artwork: artwork, localCollection: localCollection };
    this.paths.pushPath({ name: Routes.artwork, param: params });
  }

  openArtist(artwork: Artwork): void { this.paths.pushPath({ name: Routes.artist, param: artwork }); }
  openViewer(params: ViewerRouteParams): void { this.paths.pushPath({ name: Routes.viewer, param: params }, false); }
  openLogin(): void { this.paths.pushPath({ name: Routes.login }); }
  openAbout(): void { this.paths.pushPath({ name: Routes.about }); }
  openNovel(novel: Novel): void { this.paths.pushPath({ name: Routes.novel, param: novel }); }
  openComments(target: CommentTarget): void { this.paths.pushPath({ name: Routes.comments, param: target }); }

  back(): void {
    if (this.paths.size() > 1) { this.paths.pop(); } else { this.onExit(); }
  }

  rememberArtwork(artwork: Artwork): void { this.changedWorks.set(artwork.id, artwork); }

  authenticated(): void {
    this.changedWorks.clear();
    this.paths.clear(false);
    this.showMain(0);
  }
}

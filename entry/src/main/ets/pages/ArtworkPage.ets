import { Artwork, emptyArtwork } from '../models/PixivModels';
import { AppNavigator, ArtworkRouteParams, ViewerRouteParams } from '../navigation/AppNavigator';
import { ArtworkDetail } from '../components/ArtworkDetail';

@Component
export struct ArtworkPage {
  navigator: AppNavigator = new AppNavigator();
  params: ArtworkRouteParams = { artwork: emptyArtwork(), localCollection: true };
  @State visible: boolean = true;

  build() {
    NavDestination() {
      ArtworkDetail({ initial: this.params.artwork, localCollection: this.params.localCollection, visible: this.visible,
        onViewer: (params: ViewerRouteParams) => this.navigator.openViewer(params),
        onBack: () => this.navigator.back(), onArtist: (work: Artwork) => this.navigator.openArtist(work),
        onComments: (work: Artwork) => this.navigator.openComments({ id: work.id, kind: 'illust', title: work.title }),
        onTag: (tag: string) => this.navigator.showMain(1, tag),
        onChanged: (work: Artwork) => {
          if (!this.params.localCollection) { this.navigator.rememberArtwork(work); }
        } })
    }.hideTitleBar(true).id('destination_artwork')
      .onShown(() => this.visible = true).onHidden(() => this.visible = false)
      .onBackPressed(() => { this.navigator.back(); return true; })
  }
}

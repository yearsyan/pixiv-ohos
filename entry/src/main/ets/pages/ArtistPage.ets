import { Artwork, emptyArtwork } from '../models/PixivModels';
import { authService } from '../services/AuthService';
import { AppNavigator } from '../navigation/AppNavigator';
import { ArtistPanel } from '../components/ArtistPanel';

@Component
export struct ArtistPage {
  navigator: AppNavigator = new AppNavigator();
  source: Artwork = emptyArtwork();

  build() {
    NavDestination() {
      ArtistPanel({ source: this.source, onBack: () => this.navigator.back(),
        onWork: (work: Artwork) => this.navigator.openArtwork(work, !authService.loggedIn),
        onLogin: () => this.navigator.openLogin(),
        onChanged: (work: Artwork) => this.navigator.rememberArtwork(work) })
    }.hideTitleBar(true).id('destination_artist')
      .onBackPressed(() => { this.navigator.back(); return true; })
  }
}

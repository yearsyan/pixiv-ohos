import { AppNavigator } from '../navigation/AppNavigator';
import { MainPageFrame } from '../components/MainPageFrame';

@Component
export struct LibraryPage {
  navigator: AppNavigator = new AppNavigator();
  @State activation: number = 0;

  build() {
    NavDestination() {
      MainPageFrame({ tab: 3, activation: this.activation, navigator: this.navigator })
    }.hideTitleBar(true).id('destination_library')
      .onShown(() => this.activation++)
      .onBackPressed(() => { this.navigator.back(); return true; })
  }
}

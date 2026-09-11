import { AppNavigator } from '../navigation/AppNavigator';
import { MainPageFrame } from '../components/MainPageFrame';

@Component
export struct SearchPage {
  navigator: AppNavigator = new AppNavigator();
  @State activation: number = 0;

  build() {
    NavDestination() {
      MainPageFrame({ tab: 1, activation: this.activation, navigator: this.navigator })
    }.hideTitleBar(true).id('destination_search')
      .onShown(() => this.activation++)
      .onBackPressed(() => { this.navigator.back(); return true; })
  }
}

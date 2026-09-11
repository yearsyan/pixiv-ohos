import { AppNavigator } from '../navigation/AppNavigator';
import { MainPageFrame } from '../components/MainPageFrame';

@Component
export struct FollowingPage {
  navigator: AppNavigator = new AppNavigator();
  @State activation: number = 0;

  build() {
    NavDestination() {
      MainPageFrame({ tab: 2, activation: this.activation, navigator: this.navigator })
    }.hideTitleBar(true).id('destination_following')
      .onShown(() => this.activation++)
      .onBackPressed(() => { this.navigator.back(); return true; })
  }
}

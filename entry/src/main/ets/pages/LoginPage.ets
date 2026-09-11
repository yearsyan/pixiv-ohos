import { AppNavigator } from '../navigation/AppNavigator';
import { LoginPanel } from '../components/LoginPanel';

@Component
export struct LoginPage {
  navigator: AppNavigator = new AppNavigator();

  build() {
    NavDestination() {
      LoginPanel({ onClose: () => this.navigator.back(), onSuccess: () => this.navigator.authenticated() })
    }.hideTitleBar(true).id('destination_login')
      .onBackPressed(() => { this.navigator.back(); return true; })
  }
}

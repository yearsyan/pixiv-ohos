import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

class ViewerWindow {
  private queue: Promise<void> = Promise.resolve();
  private immersed: boolean = false;
  private previousBars: window.SystemBarProperties = {};
  private owners: Set<number> = new Set<number>();
  private nextOwner: number = 0;

  acquire(context: common.UIAbilityContext): number {
    const owner = ++this.nextOwner;
    this.owners.add(owner);
    this.update(context);
    return owner;
  }

  release(context: common.UIAbilityContext, owner: number): void {
    this.owners.delete(owner);
    this.update(context);
  }

  private update(context: common.UIAbilityContext): void {
    // Serialize entry/exit so a quick Back cannot leave an asynchronous hide
    // operation running after the normal page has already been restored.
    this.queue = this.queue.then(async () => {
      const enabled = this.owners.size > 0;
      if (this.immersed === enabled) { return; }
      const mainWindow = await window.getLastWindow(context);
      if (enabled) {
        this.previousBars = mainWindow.getWindowSystemBarProperties();
        this.immersed = true;
        await mainWindow.setWindowBackgroundColor('#000000');
        await mainWindow.setWindowSystemBarProperties({ statusBarColor: '#000000', navigationBarColor: '#000000',
          statusBarContentColor: '#FFFFFF', navigationBarContentColor: '#FFFFFF' });
        await mainWindow.setWindowSystemBarEnable([]);
      } else {
        this.immersed = false;
        await mainWindow.setWindowSystemBarEnable(['status', 'navigation']);
        await mainWindow.setWindowSystemBarProperties(this.previousBars);
        await mainWindow.setWindowBackgroundColor('#FFFFFF');
      }
      try { await mainWindow.setSpecificSystemBarEnabled('navigationIndicator', !enabled); }
      catch (_) { /* Some OpenHarmony devices do not have a gesture indicator. */ }
    }).catch(() => hilog.warn(0x0000, 'PixivViewer', 'Window display mode update failed'));
  }
}

export const viewerWindow = new ViewerWindow();

import { hilog } from '@kit.PerformanceAnalysisKit';
import { imageCache } from '../services/ImageCache';
import { Theme } from '../utils/Theme';
import { PixivImage } from './PixivImage';

@Component
export struct DetailImage {
  @Prop preview: string = '';
  @Prop @Watch('loadOriginal') original: string = '';
  @Prop @Watch('loadOriginal') active: boolean = false;
  onOpen: () => void = () => {};
  @State originalLocal: string = '';
  @State ready: boolean = false;
  @State failed: boolean = false;
  @State sourceWidth: number = 1;
  @State sourceHeight: number = 1;
  @State viewportWidthPx: number = 1;
  @State viewportHeightPx: number = 1;
  private generation: number = 0;

  aboutToAppear(): void { this.loadOriginal(); }
  aboutToDisappear(): void { ++this.generation; }

  private async loadOriginal(): Promise<void> {
    const generation = ++this.generation;
    this.originalLocal = '';
    this.ready = false;
    this.failed = false;
    if (!this.active || !this.original) { return; }
    try {
      const local = await imageCache.load(this.original, true);
      if (this.active && generation === this.generation) { this.originalLocal = local; }
    } catch (_) {
      if (this.active && generation === this.generation) { this.failed = true; }
    }
  }

  private interpolation(): ImageInterpolation {
    // Compare physical pixels, not vp. ArkUI recommends Medium when reducing
    // an original and High when enlarging one; default Low loses fine detail.
    return Math.min(this.viewportWidthPx / this.sourceWidth, this.viewportHeightPx / this.sourceHeight) > 1 ?
      ImageInterpolation.High : ImageInterpolation.Medium;
  }

  private decodeFailed(local: string): void {
    if (!this.active || local !== this.originalLocal) { return; }
    imageCache.invalidate(local);
    this.originalLocal = '';
    this.ready = false;
    this.failed = true;
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      // Keep the preview visible until the original has actually decoded.
      if (!this.ready) {
        PixivImage({ src: this.preview, fit: ImageFit.Contain,
          onDecoded: (width: number, height: number) => {
            if (this.active) {
              hilog.info(0x0000, 'PixivDetail', 'Preview decoded: %{public}dx%{public}d', width, height);
            }
          } }).width('100%').height('100%').onClick(() => this.onOpen(), 8)
      }
      if (this.active && this.originalLocal) {
        ForEach([this.originalLocal], (local: string) => {
          Image(local).width('100%').height('100%').objectFit(ImageFit.Contain)
            .autoResize(false).interpolation(this.interpolation()).draggable(false)
            .opacity(this.ready ? 1 : 0).id('detail_original_image')
            .onComplete((event) => {
              if (!event || !this.active || local !== this.originalLocal) { return; }
              this.sourceWidth = Math.max(1, event.width);
              this.sourceHeight = Math.max(1, event.height);
              if (event.loadingStatus === 1 && !this.ready) {
                this.ready = true;
                hilog.info(0x0000, 'PixivDetail', 'Original decoded: %{public}dx%{public}d viewport=%{public}dx%{public}d',
                  event.width, event.height, this.viewportWidthPx, this.viewportHeightPx);
              }
            })
            .onError(() => this.decodeFailed(local))
            .onClick(() => this.onOpen(), 8)
        }, (local: string) => local)
      }
      if (this.active && this.original && !this.ready) {
        if (this.failed) {
          Button('原图加载失败，重试').fontSize(12).fontColor(Theme.blue).height(32)
            .backgroundColor('#F2FFFFFF').margin(14).id('detail_original_retry')
            .onClick(() => this.loadOriginal())
        } else {
          Row({ space: 6 }) {
            LoadingProgress().width(14).height(14).color(Theme.blue)
            Text('正在加载原图').fontSize(11).fontColor(Theme.secondary)
          }.padding({ left: 10, right: 10, top: 7, bottom: 7 }).backgroundColor('#F2FFFFFF').borderRadius(16)
            .margin(14).hitTestBehavior(HitTestMode.Transparent).id('detail_original_loading')
        }
      }
    }.width('100%').height('100%').backgroundColor('#EDF2F7').clip(true)
      .onAreaChange((_, area: Area) => {
        this.viewportWidthPx = this.getUIContext().vp2px(Number(area.width));
        this.viewportHeightPx = this.getUIContext().vp2px(Number(area.height));
      })
  }
}

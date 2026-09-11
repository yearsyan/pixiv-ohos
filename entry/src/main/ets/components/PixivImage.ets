import { imageCache } from '../services/ImageCache';
import { Theme } from '../utils/Theme';

@Component
export struct PixivImage {
  @Prop @Watch('sourceChanged') src: string = '';
  @Prop fit: ImageFit = ImageFit.Cover;
  @Prop radius: number = 0;
  onDecoded: (width: number, height: number) => void = () => {};
  @State local: string = '';
  @State failed: boolean = false;
  private generation: number = 0;

  aboutToAppear(): void { this.sourceChanged(); }
  aboutToDisappear(): void { this.generation++; }

  private async sourceChanged(): Promise<void> {
    const request = ++this.generation;
    this.local = '';
    this.failed = false;
    if (!this.src) { this.failed = true; return; }
    try {
      const local = await imageCache.load(this.src);
      if (request === this.generation) { this.local = local; }
    } catch (_) {
      if (request === this.generation) { this.failed = true; }
    }
  }

  build() {
    Stack() {
      if (this.local) {
        Image(this.local).width('100%').height('100%').objectFit(this.fit)
          .onComplete((event) => {
            if (event && event.loadingStatus === 1) { this.onDecoded(event.width, event.height); }
          })
          .onError(() => { imageCache.invalidate(this.local); this.failed = true; this.local = ''; })
      } else if (this.failed) {
        Column({ space: 6 }) {
          Image($r('app.media.image_placeholder')).width(28).height(28).opacity(0.5)
          if (this.src) { Text('轻触重试').fontSize(10).fontColor(Theme.muted) }
        }.onClick(() => this.sourceChanged()).accessibilityText('图片加载失败，轻触重试')
      } else {
        LoadingProgress().width(22).height(22).color('#BBDDF6')
      }
    }.width('100%').height('100%').backgroundColor('#EDF2F7').borderRadius(this.radius).clip(true)
  }
}

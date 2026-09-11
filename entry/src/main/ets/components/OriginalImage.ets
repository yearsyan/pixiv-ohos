import { hilog } from '@kit.PerformanceAnalysisKit';
import { imageCache } from '../services/ImageCache';
import { ImageOffset, boundImageOffset, zoomAround } from '../utils/ViewerGeometry';
import { ViewerTapGuard, VIEWER_TAP_DISTANCE } from '../utils/ViewerTapGuard';

@Component
export struct OriginalImage {
  @Prop @Watch('load') src: string = '';
  @Prop @Watch('load') active: boolean = false;
  @Link zoom: number;
  onClose: () => void = () => {};
  onMenu: () => void = () => {};
  onFailure: () => void = () => {};
  @State local: string = '';
  @State viewportWidth: number = 400;
  @State viewportHeight: number = 600;
  @State sourceWidth: number = 1;
  @State sourceHeight: number = 1;
  @State panX: number = 0;
  @State panY: number = 0;
  private startZoom: number = 1;
  private pinchPan: ImageOffset = { x: 0, y: 0 };
  private dragPan: ImageOffset = { x: 0, y: 0 };
  private anchor: ImageOffset = { x: 0, y: 0 };
  private generation: number = 0;
  private reported: boolean = false;
  private tapGuard: ViewerTapGuard = new ViewerTapGuard();

  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { ++this.generation; }

  private async load(): Promise<void> {
    const generation = ++this.generation;
    this.local = '';
    this.panX = 0;
    this.panY = 0;
    this.reported = false;
    this.tapGuard.cancel();
    if (!this.active || !this.src) { return; }
    try {
      const local = await imageCache.load(this.src, true);
      if (generation === this.generation && this.active) { this.local = local; }
    } catch (_) { if (generation === this.generation && this.active) { this.onFailure(); } }
  }

  private move(offset: ImageOffset): void {
    const bounded = boundImageOffset({ width: this.sourceWidth, height: this.sourceHeight },
      { width: this.viewportWidth, height: this.viewportHeight }, this.zoom, offset);
    this.panX = bounded.x;
    this.panY = bounded.y;
  }

  private doubleTap(event: GestureEvent): void {
    this.tapGuard.invalidate();
    const next = this.zoom > 1 ? 1 : 2.5;
    const finger = event.fingerList[0];
    const anchor: ImageOffset = { x: finger ? finger.localX - this.viewportWidth / 2 : 0,
      y: finger ? finger.localY - this.viewportHeight / 2 : 0 };
    const offset = zoomAround(this.zoom, next, { x: this.panX, y: this.panY }, anchor);
    this.zoom = next;
    this.move(offset);
  }

  private trackTouch(event: TouchEvent): void {
    const now = Date.now();
    if (event.type === TouchType.Cancel) { this.tapGuard.cancel(); return; }
    for (const point of event.changedTouches) {
      if (event.type === TouchType.Down) {
        this.tapGuard.down(point.id, point.windowX, point.windowY, now);
      } else if (event.type === TouchType.Up) {
        this.tapGuard.up(point.id, point.windowX, point.windowY, now);
      } else {
        this.tapGuard.move(point.id, point.windowX, point.windowY);
      }
    }
    if (event.touches.length > 1) { this.tapGuard.invalidate(); }
    if (event.type === TouchType.Move) {
      for (const point of event.getHistoricalPoints()) {
        this.tapGuard.move(point.touchObject.id, point.touchObject.windowX, point.touchObject.windowY);
      }
    }
  }

  build() {
    Stack() {
      // Only the active page is decoded at full resolution. Swiping away removes
      // its Image node rather than retaining full-size bitmaps for the whole work.
      if (this.active && this.local) {
        Image(this.local).width('100%').height('100%').objectFit(ImageFit.Contain)
          .autoResize(false).interpolation(ImageInterpolation.High)
          .scale({ x: this.zoom, y: this.zoom }).translate({ x: this.panX, y: this.panY })
          .onComplete((event) => {
            if (event && this.active) {
              this.sourceWidth = event.width;
              this.sourceHeight = event.height;
              if (!this.reported) {
                this.reported = true;
                hilog.info(0x0000, 'PixivViewer', 'Original image loaded, width=%{public}d height=%{public}d', event.width, event.height);
              }
            }
          })
          .onError(() => { if (this.active) { imageCache.invalidate(this.local); this.onFailure(); } })
          .draggable(false).id('viewer_original_image')
      }
    }.width('100%').height('100%').backgroundColor('#000000').clip(true).id('viewer_canvas')
      .onTouch((event: TouchEvent) => this.trackTouch(event))
      .onAreaChange((_, area: Area) => {
        this.viewportWidth = Number(area.width); this.viewportHeight = Number(area.height);
        this.move({ x: this.panX, y: this.panY });
      })
      .gesture(GestureGroup(GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart((event: GestureEvent) => {
            this.tapGuard.invalidate();
            this.startZoom = this.zoom;
            this.pinchPan = { x: this.panX, y: this.panY };
            this.anchor = { x: event.pinchCenterX - this.viewportWidth / 2, y: event.pinchCenterY - this.viewportHeight / 2 };
          })
          .onActionUpdate((event: GestureEvent) => {
            this.zoom = Math.max(1, Math.min(8, this.startZoom * event.scale));
            this.move(zoomAround(this.startZoom, this.zoom, this.pinchPan, this.anchor));
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All })
          .onActionStart(() => {
            this.tapGuard.invalidate();
            this.dragPan = { x: this.panX, y: this.panY };
          })
          .onActionUpdate((event: GestureEvent) => {
            if (event.fingerList.length === 1) { this.move({ x: this.dragPan.x + event.offsetX, y: this.dragPan.y + event.offsetY }); }
          }),
        GestureGroup(GestureMode.Exclusive,
          LongPressGesture({ fingers: 1, isFingerCountLimited: true })
            .onAction(() => { this.tapGuard.invalidate(); this.onMenu(); }),
          TapGesture({ count: 2, fingers: 1, isFingerCountLimited: true, distanceThreshold: VIEWER_TAP_DISTANCE })
            .onAction((event: GestureEvent) => this.doubleTap(event)),
          TapGesture({ count: 1, fingers: 1, isFingerCountLimited: true, distanceThreshold: VIEWER_TAP_DISTANCE })
            .onAction(() => { if (this.tapGuard.consume()) { this.onClose(); } })
        )
      ))
      .onGestureJudgeBegin((info: GestureInfo, event: BaseGestureEvent) => {
        if (info.type === GestureControl.GestureType.PAN_GESTURE && (this.zoom <= 1 || event.fingerList.length !== 1)) { return GestureJudgeResult.REJECT; }
        return GestureJudgeResult.CONTINUE;
      })
      .accessibilityText('原图，单击返回，双击缩放，长按保存')
  }
}

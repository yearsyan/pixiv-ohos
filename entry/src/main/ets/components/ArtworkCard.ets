import { Artwork, emptyArtwork } from '../models/PixivModels';
import { PixivImage } from './PixivImage';
import { Theme } from '../utils/Theme';

@Component
export struct ArtworkCard {
  @Prop artwork: Artwork = emptyArtwork();
  @Prop saved: boolean = false;
  @Prop cardWidth: number = 170;
  @Prop showRank: boolean = false;
  onOpen: (work: Artwork) => void = () => {};
  onSave: (work: Artwork) => void = () => {};

  private imageHeight(): number {
    return Math.max(this.cardWidth * 0.72, Math.min(this.cardWidth * 1.6,
      this.cardWidth * this.artwork.height / Math.max(1, this.artwork.width)));
  }

  build() {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        PixivImage({ src: this.artwork.imageUrl, radius: 12 }).height(this.imageHeight())
          .onClick(() => this.onOpen(this.artwork))
          .accessibilityText(this.artwork.title + '，作者 ' + this.artwork.userName)
          .id('artwork_' + this.artwork.id.toString())
        if (this.showRank && this.artwork.rank > 0) {
          Text(this.artwork.rank.toString().padStart(2, '0')).fontSize(14).fontWeight(FontWeight.Bold)
            .fontColor(Color.White).padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.artwork.rank <= 3 ? Theme.blue : '#88213951')
            .borderRadius({ topLeft: 12, bottomRight: 10 })
        }
        if (this.artwork.pageCount > 1) {
          Row({ space: 4 }) {
            Image($r('app.media.layers')).width(12).height(12).fillColor(Color.White)
            Text(this.artwork.pageCount.toString()).fontSize(11).fontColor(Color.White)
          }.padding({ left: 7, right: 7, top: 4, bottom: 4 }).backgroundColor('#88213951')
            .borderRadius(7).position({ x: this.cardWidth - 45, y: 8 })
        }
      }.width('100%').height(this.imageHeight())
      Row({ space: 6 }) {
        Column({ space: 4 }) {
          Text(this.artwork.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          Text(this.artwork.userName).fontSize(11).fontColor(Theme.secondary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(() => this.onOpen(this.artwork))
        Button({ type: ButtonType.Circle }) {
          Image(this.saved ? $r('app.media.heart_fill') : $r('app.media.heart'))
            .width(20).height(20).fillColor(this.saved ? '#FF6484' : '#91A0B1')
        }.width(34).height(40).backgroundColor(Color.Transparent)
          .onClick(() => this.onSave(this.artwork))
          .id('save_' + this.artwork.id.toString())
          .accessibilityText(this.saved ? '取消收藏 ' + this.artwork.title : '收藏 ' + this.artwork.title)
      }.padding({ top: 10, bottom: 6 }).width('100%')
    }.width(this.cardWidth)
  }
}

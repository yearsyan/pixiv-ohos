import { ImagePage } from '../models/PixivModels';
import { isImageUrl } from './PixivMapper';

export interface ImageSize { width: number; height: number; }
export interface ImageOffset { x: number; y: number; }

export function requireOriginal(page: ImagePage): string {
  if (!isImageUrl(page.original)) { throw new Error('作品未提供可用的原图地址'); }
  return page.original;
}

export function originalExtension(url: string): string {
  const match = url.split('?')[0].match(/\.(jpg|jpeg|png|gif|webp|bmp|avif|heic)$/i);
  if (!match) { throw new Error('无法识别原图文件格式'); }
  return match[1].toLowerCase();
}

export function fitImage(source: ImageSize, viewport: ImageSize): ImageSize {
  const ratio = Math.min(viewport.width / Math.max(1, source.width), viewport.height / Math.max(1, source.height));
  return { width: source.width * ratio, height: source.height * ratio };
}

export function boundImageOffset(source: ImageSize, viewport: ImageSize, zoom: number, offset: ImageOffset): ImageOffset {
  const fit = fitImage(source, viewport);
  const x = Math.max(0, (fit.width * zoom - viewport.width) / 2);
  const y = Math.max(0, (fit.height * zoom - viewport.height) / 2);
  return { x: Math.max(-x, Math.min(x, offset.x)), y: Math.max(-y, Math.min(y, offset.y)) };
}

export function zoomAround(startZoom: number, nextZoom: number, start: ImageOffset, anchor: ImageOffset): ImageOffset {
  const ratio = nextZoom / startZoom;
  return { x: anchor.x - (anchor.x - start.x) * ratio, y: anchor.y - (anchor.y - start.y) * ratio };
}

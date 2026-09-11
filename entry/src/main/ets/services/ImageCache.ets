import { http } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { isImageUrl } from '../utils/PixivMapper';

interface CachedFile { name: string; size: number; modified: number; }

class ImageCache {
  private directory: string = '';
  private inflight: Map<string, Promise<string>> = new Map();
  private active: number = 0;
  private waiting: Array<() => void> = [];
  private writes: number = 0;

  initialize(cacheDir: string): void {
    this.directory = cacheDir + '/pixiv_images';
    try { fs.mkdirSync(this.directory); } catch (_) { /* Directory may already exist. */ }
    this.trim();
  }

  private trim(): void {
    try {
      const files: CachedFile[] = fs.listFileSync(this.directory).map((name: string) => {
        const stat = fs.statSync(this.directory + '/' + name);
        return { name: name, size: stat.size, modified: stat.mtime } as CachedFile;
      }).sort((a: CachedFile, b: CachedFile) => a.modified - b.modified);
      let size = files.reduce((sum: number, item: CachedFile) => sum + item.size, 0);
      let count = files.length;
      for (const item of files) {
        if (count <= 240 && size <= 128 * 1024 * 1024) { break; }
        fs.unlinkSync(this.directory + '/' + item.name);
        size -= item.size;
        count--;
      }
    } catch (_) { /* Cache eviction does not affect the local collection or authentication. */ }
  }

  invalidate(local: string): void {
    const path = local.replace(/^file:\/\//, '');
    if (path.startsWith(this.directory + '/') && !path.includes('..')) {
      try { fs.unlinkSync(path); } catch (_) { /* Already evicted. */ }
    }
  }

  async load(url: string, original: boolean = false): Promise<string> {
    if (!isImageUrl(url)) { throw new Error('Invalid Pixiv image host'); }
    const existing = this.inflight.get(url);
    if (existing) { return existing; }
    const promise = this.download(url, original);
    this.inflight.set(url, promise);
    try { return await promise; } finally { this.inflight.delete(url); }
  }

  private async download(url: string, original: boolean): Promise<string> {
    const digest = cryptoFramework.createMd('SHA256');
    await digest.update({ data: new util.TextEncoder().encodeInto(url) });
    const hash = Array.from((await digest.digest()).data).map((value: number) => value.toString(16).padStart(2, '0')).join('');
    const path = this.directory + '/' + hash + '.image';
    try { if (fs.statSync(path).size > 0) { return 'file://' + path; } } catch (_) { /* Cache miss. */ }
    if (this.active >= 6) {
      await new Promise<void>((resolve) => { if (original) { this.waiting.unshift(resolve); } else { this.waiting.push(resolve); } });
    }
    else { this.active++; }
    const request = http.createHttp();
    try {
      const response = await request.request(url, { method: http.RequestMethod.GET,
        header: { 'Referer': 'https://www.pixiv.net/', 'User-Agent': 'Mozilla/5.0' },
        expectDataType: http.HttpDataType.ARRAY_BUFFER, connectTimeout: 12000, readTimeout: original ? 60000 : 20000,
        maxLimit: (original ? 100 : 20) * 1024 * 1024 });
      if (response.responseCode !== 200) { throw new Error('Image unavailable'); }
      const data = response.result as ArrayBuffer;
      if (data.byteLength === 0) { throw new Error('Empty image file'); }
      const temporary = path + '.part';
      const file = fs.openSync(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        if (fs.writeSync(file.fd, data) !== data.byteLength) { throw new Error('Incomplete image file'); }
      } catch (error) {
        try { fs.unlinkSync(temporary); } catch (_) { /* Failed cache write. */ }
        throw error as Error;
      } finally { fs.closeSync(file); }
      fs.renameSync(temporary, path);
      this.writes++;
      if (this.writes % 20 === 0) { this.trim(); }
      return 'file://' + path;
    } finally {
      request.destroy();
      const next = this.waiting.shift();
      if (next) { next(); } else { this.active--; }
    }
  }
}

export const imageCache = new ImageCache();

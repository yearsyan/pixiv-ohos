import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ImagePage } from '../models/PixivModels';
import { requireOriginal, originalExtension } from '../utils/ViewerGeometry';
import { imageCache } from './ImageCache';

async function digestFile(fd: number): Promise<string> {
  const md = cryptoFramework.createMd('SHA256');
  const chunk = new ArrayBuffer(1024 * 1024);
  fs.lseek(fd, 0, fs.WhenceType.SEEK_SET);
  while (true) {
    const count = await fs.read(fd, chunk, { length: chunk.byteLength });
    if (count === 0) { break; }
    await md.update({ data: new Uint8Array(chunk.slice(0, count)) });
  }
  return Array.from((await md.digest()).data).map((byte: number) => byte.toString(16).padStart(2, '0')).join('');
}

class AlbumService {
  private busy: boolean = false;

  async saveOriginal(context: common.UIAbilityContext, page: ImagePage, artworkId: number, index: number): Promise<boolean> {
    if (this.busy) { return false; }
    this.busy = true;
    let staging = '';
    let phase = 'download';
    try {
      const url = requireOriginal(page);
      const extension = originalExtension(url);
      const local = await imageCache.load(url, true);
      phase = 'stage';
      staging = context.tempDir + '/pixiv_' + artworkId.toString() + '_p' + index.toString() + '_' + Date.now().toString() + '.' + extension;
      // Keep a stable source while the system save dialog is open. This is a
      // byte-for-byte file copy, with no image decoder, packer or screenshot.
      await fs.copyFile(local.replace(/^file:\/\//, ''), staging);
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      try {
        const configs: photoAccessHelper.PhotoCreationConfig[] = [{ title: 'pixiv_' + artworkId.toString() + '_p' + index.toString(),
          fileNameExtension: extension, photoType: photoAccessHelper.PhotoType.IMAGE }];
        phase = 'dialog';
        const uris = await helper.showAssetsCreationDialog([fileUri.getUriFromPath(staging)], configs);
        if (uris.length === 0) { return false; }
        phase = 'copy';
        const source = await fs.open(staging, fs.OpenMode.READ_ONLY);
        try {
          const target = await fs.open(uris[0], fs.OpenMode.READ_WRITE);
          try {
            await fs.copyFile(source.fd, target.fd);
            phase = 'verify';
            const sourceHash = await digestFile(source.fd);
            const targetHash = await digestFile(target.fd);
            if (sourceHash !== targetHash) { throw new Error('原图写入校验失败'); }
            hilog.info(0x0000, 'PixivAlbum', 'Original bytes verified: SHA256 equal, bytes=%{public}d', fs.statSync(source.fd).size);
          } finally { await fs.close(target); }
        } finally { await fs.close(source); }
        return true;
      } finally { await helper.release(); }
    } catch (error) {
      hilog.error(0x0000, 'PixivAlbum', 'Original save failed phase=%{public}s code=%{public}d', phase, (error as BusinessError).code || 0);
      throw error as Error;
    } finally {
      if (staging) { try { await fs.unlink(staging); } catch (_) { /* Already cleaned up. */ } }
      this.busy = false;
    }
  }
}

export const albumService = new AlbumService();

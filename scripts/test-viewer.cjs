#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const Module = require('node:module');
const crypto = require('node:crypto');
const { test, after } = require('node:test');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript');
require.extensions['.ets'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }, fileName: filename.replace(/\.ets$/, '.ts')
}).outputText, filename);
const root = path.resolve(__dirname, '../entry/src/main/ets');
const geometry = require(root + '/utils/ViewerGeometry.ets');
const { ViewerTapGuard } = require(root + '/utils/ViewerTapGuard.ets');
const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'pixiv-original-tests-'));
after(() => fs.rmSync(folder, { recursive: true, force: true }));
const source = path.join(folder, 'source.png');
const target = path.join(folder, 'album.png');
const positions = new Map();
const logs = [];
const downloads = [];
let cancelled = false, corrupt = false, dialogs = 0;
const fileIo = {
  OpenMode: { READ_ONLY: 0, READ_WRITE: 2 }, WhenceType: { SEEK_SET: 0 },
  open: async (p, mode) => { const fd = fs.openSync(p, mode === 0 ? 'r' : 'r+'); positions.set(fd, 0); return { fd }; },
  close: async file => { fs.closeSync(file.fd); positions.delete(file.fd); },
  lseek: (fd, offset) => { positions.set(fd, offset); return offset; },
  read: async (fd, buffer, options) => {
    const position = (positions.get(fd) || 0) + (options.offset || 0);
    const count = fs.readSync(fd, new Uint8Array(buffer), 0, options.length, position);
    positions.set(fd, position + count); return count;
  },
  statSync: fd => fs.fstatSync(fd),
  unlink: async p => fs.unlinkSync(p),
  copyFile: async (src, dst) => {
    if (typeof src === 'string') { fs.copyFileSync(src, dst); return; }
    const bytes = Buffer.alloc(fs.fstatSync(src).size);
    fs.readSync(src, bytes, 0, bytes.length, 0);
    if (corrupt) bytes[bytes.length - 1] ^= 1;
    fs.writeSync(dst, bytes, 0, bytes.length, 0);
    positions.set(src, bytes.length); positions.set(dst, bytes.length);
  }
};
const windowCalls = [];
const mockWindow = {
  getWindowSystemBarProperties: () => ({ statusBarColor: '#FFFFFF' }),
  setWindowBackgroundColor: async color => windowCalls.push(['background', color]),
  setWindowSystemBarProperties: async props => windowCalls.push(['colors', props.statusBarColor]),
  setWindowSystemBarEnable: async bars => windowCalls.push(['bars', bars]),
  setSpecificSystemBarEnabled: async (_, enabled) => windowCalls.push(['indicator', enabled])
};
const mocks = {
  '@kit.CoreFileKit': { fileIo, fileUri: { getUriFromPath: p => 'file://' + p } },
  '@kit.MediaLibraryKit': { photoAccessHelper: { PhotoType: { IMAGE: 1 }, getPhotoAccessHelper: () => ({
    showAssetsCreationDialog: async (uris, configs) => { dialogs++; assert.equal(configs[0].fileNameExtension, 'png'); assert.ok(uris[0].endsWith('.png')); if (cancelled) return []; fs.writeFileSync(target, ''); return [target]; },
    release: async () => {}
  }) } },
  '@kit.CryptoArchitectureKit': { cryptoFramework: { createMd: name => { const hash = crypto.createHash(name.toLowerCase()); return {
    update: async blob => hash.update(blob.data), digest: async () => ({ data: new Uint8Array(hash.digest()) })
  }; } } },
  '@kit.PerformanceAnalysisKit': { hilog: { info: (...args) => logs.push(args), warn: (...args) => logs.push(args), error: (...args) => logs.push(args) } },
  '@kit.ArkUI': { window: { getLastWindow: async () => mockWindow } },
  './ImageCache': { imageCache: { load: async (url, original) => { downloads.push({ url, original }); return 'file://' + source; } } }
};
const oldLoad = Module._load;
Module._load = function(id, ...rest) { return mocks[id] || oldLoad.call(this, id, ...rest); };
const { albumService } = require(root + '/services/AlbumService.ets');
const { viewerWindow } = require(root + '/services/ViewerWindow.ets');
const page = { url: 'https://i.pximg.net/img-master/preview.jpg', original: 'https://i.pximg.net/img-original/full.png', width: 3200, height: 2400 };
const context = { tempDir: folder };

test('only a short stationary single-finger tap can close the viewer', async t => {
  await t.test('small natural movement is accepted once, including delayed recognition', () => {
    const guard = new ViewerTapGuard();
    guard.down(0, 100, 100, 0);
    guard.move(0, 102, 104);
    guard.up(0, 102, 103, 80);
    assert.equal(guard.consume(), true);
    assert.equal(guard.consume(), false);
  });
  await t.test('dragging out and back is rejected, and a subsequent fresh tap still works', () => {
    const guard = new ViewerTapGuard();
    guard.down(0, 100, 100, 0);
    guard.move(0, 130, 100);
    guard.up(0, 100, 100, 180);
    assert.equal(guard.consume(), false);
    guard.down(0, 100, 100, 500);
    guard.up(0, 100, 100, 570);
    assert.equal(guard.consume(), true);
  });
  await t.test('both slow and fast drags are rejected, including movement only on release', () => {
    for (const duration of [30, 200, 800]) {
      const guard = new ViewerTapGuard();
      guard.down(0, 100, 100, 0);
      guard.up(0, 110, 100, duration);
      assert.equal(guard.consume(), false);
    }
  });
  await t.test('holding still is not a short tap', () => {
    const guard = new ViewerTapGuard();
    guard.down(0, 100, 100, 0);
    guard.up(0, 100, 100, 350);
    assert.equal(guard.consume(), false);
  });
  await t.test('multiple fingers stay rejected whichever finger lifts first', () => {
    for (const order of [[0, 1], [1, 0]]) {
      const guard = new ViewerTapGuard();
      guard.down(0, 100, 100, 0);
      guard.down(1, 200, 100, 10);
      guard.up(order[0], order[0] ? 200 : 100, 100, 60);
      guard.up(order[1], order[1] ? 200 : 100, 100, 80);
      assert.equal(guard.consume(), false);
    }
  });
  await t.test('recognized pinch, pan, long press, double tap and cancellation suppress closing', () => {
    const guard = new ViewerTapGuard();
    guard.down(0, 100, 100, 0);
    guard.invalidate();
    guard.up(0, 100, 100, 100);
    assert.equal(guard.consume(), false);
    guard.down(0, 100, 100, 200);
    guard.cancel();
    guard.up(0, 100, 100, 250);
    assert.equal(guard.consume(), false);
  });
});

test('original viewer and album invariants', async t => {
  await t.test('missing or foreign originals never fall back to previews', () => {
    assert.equal(geometry.requireOriginal(page), page.original);
    assert.throws(() => geometry.requireOriginal({ ...page, original: '' }));
    assert.throws(() => geometry.requireOriginal({ ...page, original: 'https://example.test/full.png' }));
    assert.equal(geometry.originalExtension(page.original + '?cache=1'), 'png');
  });
  await t.test('zoom keeps its anchor and pan bounds account for letterboxing', () => {
    assert.deepEqual(geometry.zoomAround(2, 4, { x: 50, y: 20 }, { x: 100, y: 100 }), { x: 0, y: -60 });
    assert.deepEqual(geometry.boundImageOffset({ width: 2000, height: 1000 }, { width: 1000, height: 1000 }, 1, { x: 500, y: 500 }), { x: 0, y: 0 });
    assert.deepEqual(geometry.boundImageOffset({ width: 2000, height: 1000 }, { width: 1000, height: 1000 }, 2, { x: 600, y: 500 }), { x: 500, y: 0 });
  });
  await t.test('album stores exactly the original bytes across multiple hash chunks', async () => {
    const bytes = crypto.randomBytes(3 * 1024 * 1024 + 37);
    fs.writeFileSync(source, bytes);
    assert.equal(await albumService.saveOriginal(context, page, 1, 0), true);
    assert.deepEqual(downloads.at(-1), { url: page.original, original: true });
    assert.deepEqual(fs.readFileSync(target), bytes);
    assert.ok(logs.some(args => args.includes(bytes.length)));
    assert.equal(positions.size, 0);
    assert.equal(fs.readdirSync(folder).filter(n => n.startsWith('pixiv_')).length, 0);
  });
  await t.test('a changed final byte fails full-file verification', async () => {
    corrupt = true;
    await assert.rejects(albumService.saveOriginal(context, page, 1, 0), /校验失败/);
    corrupt = false;
    assert.equal(positions.size, 0);
  });
  await t.test('cancelling save creates no asset and cleans the staging file', async () => {
    cancelled = true;
    fs.unlinkSync(target);
    assert.equal(await albumService.saveOriginal(context, page, 1, 0), false);
    assert.equal(fs.existsSync(target), false);
    assert.equal(fs.readdirSync(folder).filter(n => n.startsWith('pixiv_')).length, 0);
    cancelled = false;
  });
  await t.test('missing original does not download a preview or open a save dialog', async () => {
    const before = [downloads.length, dialogs];
    await assert.rejects(albumService.saveOriginal(context, { ...page, original: '' }, 1, 0));
    assert.deepEqual([downloads.length, dialogs], before);
  });
  await t.test('rapid viewer transitions restore bars only after the final viewer closes', async () => {
    const a = viewerWindow.acquire(context);
    await new Promise(resolve => setImmediate(resolve));
    const b = viewerWindow.acquire(context);
    viewerWindow.release(context, a);
    await new Promise(resolve => setImmediate(resolve));
    assert.deepEqual(windowCalls.filter(c => c[0] === 'bars').at(-1), ['bars', []]);
    viewerWindow.release(context, b);
    await new Promise(resolve => setImmediate(resolve));
    assert.deepEqual(windowCalls.filter(c => c[0] === 'bars').at(-1), ['bars', ['status', 'navigation']]);
    assert.deepEqual(windowCalls.at(-1), ['indicator', true]);
  });
});

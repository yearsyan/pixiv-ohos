#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const crypto = require('node:crypto');
const { test } = require('node:test');
const root = path.resolve(__dirname, '..');
const sdk = process.env.DEVECO_ROOT || '/Applications/DevEco-Studio.app/Contents';
const ts = require(sdk + '/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript');
require.extensions['.ets'] = (module, filename) => {
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }, fileName: filename.replace(/\.ets$/, '.ts')
  });
  module._compile(output.outputText, filename);
};
const requests = [];
let handler = async () => ({ responseCode: 200, result: '{}' });
const assetData = new Map();
const preferenceData = new Map();
let preferenceFailure = false;
const asset = {
  Tag: { ALIAS: 1, SECRET: 2, RETURN_TYPE: 3, ACCESSIBILITY: 4, CONFLICT_RESOLUTION: 5, IS_PERSISTENT: 6 },
  Accessibility: { DEVICE_UNLOCKED: 2 }, ConflictResolution: { OVERWRITE: 0 }, ReturnType: { ALL: 0 },
  ErrorCode: { NOT_FOUND: 24000002, STATUS_MISMATCH: 24000005 },
  async add(values) {
    // Native ASSET checks presence, not the boolean value, of the privileged tag.
    if (values.has(6)) { const error = new Error('Permission denied'); error.code = 201; throw error; }
    assetData.set(Buffer.from(values.get(1)).toString(), new Map(values));
  },
  async query(values) { const entry = assetData.get(Buffer.from(values.get(1)).toString()); return entry ? [entry] : []; },
  async remove(values) { assetData.delete(Buffer.from(values.get(1)).toString()); }
};
const mocks = {
  '@kit.PerformanceAnalysisKit': { hilog: { info() {}, error() {} } },
  '@kit.NetworkKit': { http: { RequestMethod: { GET: 'GET', POST: 'POST' }, HttpDataType: { STRING: 0 },
    createHttp: () => ({ request: async (url, options) => { requests.push({ url, options }); return handler(url, options); }, destroy() {} }) } },
  '@kit.AssetStoreKit': { asset },
  '@kit.CryptoArchitectureKit': { cryptoFramework: {
    createRandom: () => ({ generateRandom: async size => ({ data: new Uint8Array(crypto.randomBytes(size)) }) }),
    createMd: algorithm => { const hash = crypto.createHash(algorithm.toLowerCase()); return {
      update: async blob => { hash.update(blob.data); }, digest: async () => ({ data: new Uint8Array(hash.digest()) })
    }; }
  } },
  '@kit.ArkTS': { util: {
    TextEncoder: class { encodeInto(text) { return new Uint8Array(Buffer.from(text)); } },
    TextDecoder: class { decodeToString(bytes) { return Buffer.from(bytes).toString(); } },
    Base64Helper: class { encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64'); } }
  } },
  '@kit.ArkData': { preferences: { getPreferences: async () => ({
    get: async (key, fallback) => preferenceData.get(key) || fallback,
    put: async (key, value) => { if (preferenceFailure) throw new Error('disk full'); preferenceData.set(key, value); },
    flush: async () => {}
  }) } }
};
const originalLoad = Module._load;
Module._load = function(id, parent, main) { return mocks[id] || originalLoad.apply(this, arguments); };
const load = name => require(path.join(root, 'entry/src/main/ets', name));
const mapper = load('utils/PixivMapper.ets');
const models = load('models/PixivModels.ets');
const { authService: auth } = load('services/AuthService.ets');
const { pixivApi: api } = load('services/PixivApi.ets');
const { libraryStore: library } = load('services/LibraryStore.ets');
const transport = load('services/HttpClient.ets');
const tokenData = () => ({ access_token: 'synthetic-access', refresh_token: 'synthetic-refresh-token', expires_in: 3600,
  user: { id: 123, name: 'Test user', profile_image_urls: { medium: '' } } });
const tokenResponse = () => ({ responseCode: 200, result: JSON.stringify({ response: tokenData() }) });
const work = (id = 1) => ({ ...models.emptyArtwork(), id, title: 'Test landscape', imageUrl: 'https://i.pximg.net/a.jpg' });

// Serial by design: the singleton service and transport mocks model one app session.
test('Pixiv protocol and local state', async t => {
  await t.test('caption text preserves line breaks and strips markup', () => {
    assert.equal(mapper.plainText('<p>A &amp; B<br />C &quot;D&quot;</p>'), 'A & B\nC "D"');
  });
  await t.test('search thumbnails become uncropped masters', () => {
    assert.equal(mapper.largeThumbnail('https://i.pximg.net/c/250x250_80_a2/img-master/1_square1200.jpg'),
      'https://i.pximg.net/img-master/1_master1200.jpg');
  });
  await t.test('pagination deduplicates and filters restricted/invalid works', () => {
    assert.deepEqual(mapper.uniqueArtworks([work(1), work(1), { ...work(2), restricted: true }, work(3), work(0)]).map(w => w.id), [1, 3]);
  });
  await t.test('API bearer tokens cannot follow a foreign pagination origin', () => {
    for (const url of ['http://app-api.pixiv.net/v1/user', 'https://app-api.pixiv.net.evil.test/v1/user',
      'https://app-api.pixiv.net@evil.test/v1/user', 'https://evil.test/v1/user']) assert.equal(mapper.isApiUrl(url), false);
    assert.equal(mapper.isApiUrl('https://app-api.pixiv.net/v1/illust/ranking?offset=30&mode=day'), true);
  });
  await t.test('image cache accepts only actual pximg hosts', () => {
    assert.equal(mapper.isImageUrl('https://i.pximg.net/a.jpg'), true);
    assert.equal(mapper.isImageUrl('https://i.pximg.net.evil.test/a.jpg'), false);
    assert.equal(mapper.isImageUrl('file:///secret'), false);
  });
  await t.test('PKCE creates random verifiers and matching S256 challenges', async () => {
    const first = await auth.beginLogin();
    assert.equal(new URL(first).searchParams.get('code_challenge_method'), 'S256');
    assert.equal(new URL(first).searchParams.get('code_challenge').length, 43);
    const second = await auth.beginLogin();
    assert.notEqual(first, second);
    let verifier = '';
    handler = async (_, options) => { verifier = new URLSearchParams(options.extraData).get('code_verifier'); return tokenResponse(); };
    await auth.finishLogin('pixiv://account/login?code=synthetic-code');
    assert.equal(crypto.createHash('sha256').update(verifier).digest('base64url'), new URL(second).searchParams.get('code_challenge'));
    assert.equal(assetData.size, 1);
    assert.equal(auth.session.userId, 123);
  });
  await t.test('secure storage omits the privileged persistence tag', () => {
    const attributes = [...assetData.values()][0];
    assert.equal(attributes.has(asset.Tag.IS_PERSISTENT), false);
    assert.equal(attributes.get(asset.Tag.ACCESSIBILITY), asset.Accessibility.DEVICE_UNLOCKED);
  });
  await t.test('storage failures are not misreported as network failures', async () => {
    const add = asset.add;
    asset.add = async () => { const error = new Error('Permission denied'); error.code = 201; throw error; };
    handler = async () => tokenResponse();
    await assert.rejects(() => auth.loginWithRefreshToken('synthetic-refresh-token'), /安全保存.*201/);
    asset.add = async () => { const error = new Error('Device locked'); error.code = 24000005; throw error; };
    await assert.rejects(() => auth.loginWithRefreshToken('synthetic-refresh-token'), /解锁设备/);
    asset.add = add;
  });
  await t.test('invalid/replayed authorization callbacks are rejected', async () => {
    await assert.rejects(() => auth.finishLogin('https://evil.test/?code=abc'));
    await assert.rejects(() => auth.finishLogin('pixiv://account/login?code=synthetic-code'));
  });
  await t.test('concurrent expired-token requests share one refresh', async () => {
    auth.session.expiresAt = 0;
    requests.length = 0;
    handler = async () => { await new Promise(resolve => setTimeout(resolve, 15)); return tokenResponse(); };
    const tokens = await Promise.all([auth.accessToken(), auth.accessToken(), auth.accessToken()]);
    assert.deepEqual(tokens, ['synthetic-access', 'synthetic-access', 'synthetic-access']);
    assert.equal(requests.length, 1);
  });
  await t.test('authenticated API retries a 401 once after refreshing', async () => {
    let apiCalls = 0, refreshCalls = 0;
    handler = async url => {
      if (url.includes('auth/token')) { refreshCalls++; return tokenResponse(); }
      apiCalls++;
      return apiCalls === 1 ? { responseCode: 401, result: '' } : { responseCode: 200, result: '{"illusts":[],"next_url":null}' };
    };
    assert.deepEqual((await api.following()).items, []);
    assert.equal(apiCalls, 2); assert.equal(refreshCalls, 1);
  });
  await t.test('untrusted next_url fails before sending credentials', async () => {
    requests.length = 0;
    await assert.rejects(() => api.following('https://evil.test/steal'));
    assert.equal(requests.length, 0);
  });
  await t.test('logout removes the secure asset and blocks authenticated calls', async () => {
    await auth.logout();
    assert.equal(assetData.size, 0); assert.equal(auth.loggedIn, false);
    await assert.rejects(() => api.following());
  });
  await t.test('cancelling an in-flight login prevents session persistence', async () => {
    let release;
    handler = async () => { await new Promise(resolve => { release = resolve; }); return tokenResponse(); };
    const login = auth.loginWithRefreshToken('synthetic-refresh-token');
    while (!release) await new Promise(resolve => setImmediate(resolve));
    auth.cancelLogin(); release();
    await assert.rejects(() => login, /取消/);
    assert.equal(auth.loggedIn, false); assert.equal(assetData.size, 0);
  });
  await t.test('cancelling during secure-store commit removes the stale session', async () => {
    handler = async () => tokenResponse();
    const add = asset.add;
    let release;
    asset.add = async values => { await new Promise(resolve => { release = resolve; }); return add(values); };
    const login = auth.loginWithRefreshToken('synthetic-refresh-token');
    while (!release) await new Promise(resolve => setImmediate(resolve));
    auth.cancelLogin(); release();
    await assert.rejects(() => login, /取消/);
    assert.equal(auth.loggedIn, false); assert.equal(assetData.size, 0);
    asset.add = add;
  });
  await t.test('public ranking uses explicit cursor and filters masked items', async () => {
    handler = async () => ({ responseCode: 200, result: JSON.stringify({ contents: [
      { illust_id: 1, title: 'Landscape', url: 'https://i.pximg.net/1.jpg', width: 100, height: 200, tags: [], illust_page_count: '2', rank: 1 },
      { illust_id: 2, title: 'Masked', url: 'https://i.pximg.net/2.jpg', is_masked: true }
    ], next: 3, date: '20260910', rank_total: 500 }) });
    const result = await api.ranking('week', 'illust', '2');
    assert.equal(result.next, '3'); assert.equal(result.items.length, 1); assert.equal(result.items[0].pageCount, 2);
    assert.match(requests.at(-1).url, /mode=weekly&content=illust&p=2/);
    await assert.rejects(() => api.ranking('day', 'illust', 'NaN'));
  });
  await t.test('public search encodes user input and uses safe content mode', async () => {
    handler = async () => ({ responseCode: 200, result: '{"error":false,"body":{"illustManga":{"data":[],"total":0}}}' });
    await api.search('a & b/风景', 'all', 'date_desc');
    assert.match(requests.at(-1).url, /a%20%26%20b%2F%E9%A3%8E%E6%99%AF/);
    assert.match(requests.at(-1).url, /mode=safe/);
  });
  await t.test('malformed and unavailable responses become useful errors', async () => {
    handler = async () => ({ responseCode: 200, result: '<html>challenge</html>' });
    await assert.rejects(() => transport.requestJson('https://www.pixiv.net/', {}), /无法识别/);
    handler = async () => ({ responseCode: 429, result: '{}' });
    await assert.rejects(() => transport.requestJson('https://www.pixiv.net/', {}), /频繁/);
  });
  await t.test('local collections survive initialization and duplicate toggles', async () => {
    await library.initialize({});
    assert.equal(await library.toggleSaved(work(1)), true);
    await library.initialize({}); assert.equal(library.saved.length, 1);
    assert.equal(await library.toggleSaved(work(1)), false); assert.equal(library.saved.length, 0);
  });
  await t.test('failed collection write rolls state back', async () => {
    preferenceFailure = true;
    await assert.rejects(() => library.toggleSaved(work(1)));
    assert.equal(library.saved.length, 0);
    preferenceFailure = false;
  });
  await t.test('rapid collection toggles serialize without losing updates', async () => {
    assert.deepEqual(await Promise.all([library.toggleSaved(work(1)), library.toggleSaved(work(1))]), [true, false]);
    assert.equal(library.saved.length, 0);
    await Promise.all([library.toggleSaved(work(1)), library.toggleSaved(work(2))]);
    assert.equal(library.saved.length, 2);
    await Promise.all([library.toggleSaved(work(1)), library.toggleSaved(work(2))]);
    assert.equal(library.saved.length, 0);
  });
  await t.test('history and searches deduplicate with bounded persistence', async () => {
    for (let i = 1; i <= 155; i++) await library.recordView(work(i));
    await library.recordView(work(154));
    assert.equal(library.history.length, 150); assert.equal(library.history[0].id, 154);
    await library.recordSearch('landscape'); await library.recordSearch('sky'); await library.recordSearch('landscape');
    assert.deepEqual(library.searches, ['landscape', 'sky']);
  });
});

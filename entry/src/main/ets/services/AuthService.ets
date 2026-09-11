import { asset } from '@kit.AssetStoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Session, TokenResponse, TokenData, emptySession } from '../models/PixivModels';
import { requestJson, appHeaders, formEncode, PixivError } from './HttpClient';
import { queryValue } from '../utils/PixivMapper';

// Pixiv's public app client identifiers, also used by the referenced open-source clients.
// These identify the application protocol; user credentials are never embedded in this project.
const CLIENT_ID = 'MOBrBDS8blbauoSck0ZfDbtuzpyT';
const CLIENT_SECRET = 'lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj';
const HASH_SALT = '28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c';
const REDIRECT = 'https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback';

class AuthService {
  session: Session = emptySession();
  private verifier: string = '';
  private pendingRefresh: Promise<void> | undefined = undefined;
  private epoch: number = 0;
  private commits: Promise<void> = Promise.resolve();
  private encoder: util.TextEncoder = new util.TextEncoder();

  get loggedIn(): boolean { return this.session.refreshToken.length > 0; }

  private alias(): asset.AssetMap {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.encoder.encodeInto('pixiv.oauth.session.v1'));
    return query;
  }

  async initialize(): Promise<void> {
    const query = this.alias();
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const entries = await asset.query(query);
      if (entries.length > 0) {
        const bytes = entries[0].get(asset.Tag.SECRET) as Uint8Array;
        const stored = JSON.parse(new util.TextDecoder().decodeToString(bytes)) as Session;
        if (stored.refreshToken && stored.userId) { this.session = stored; }
      }
    } catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) {
        throw new PixivError('无法读取安全存储中的账号，请解锁设备后重试。');
      }
    }
  }

  private async persist(session: Session): Promise<void> {
    const attributes = this.alias();
    attributes.set(asset.Tag.SECRET, this.encoder.encodeInto(JSON.stringify(session)));
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    // Omit IS_PERSISTENT: its default is false. Merely including the tag (even
    // false) requires STORE_PERSISTENT_DATA, which this application does not need.
    try {
      await asset.add(attributes);
    } catch (error) {
      const code = (error as BusinessError).code || 0;
      // Never log the asset contents, token response, or account information.
      hilog.error(0x0000, 'PixivAuth', 'secure-store write failed, code=%{public}d', code);
      if (code === asset.ErrorCode.STATUS_MISMATCH) {
        throw new PixivError('Pixiv 已授权，请解锁设备后重新登录以保存账号。', code);
      }
      throw new PixivError('Pixiv 已授权，但登录信息未能安全保存（错误码 ' + code.toString() + '）。请重试。', code);
    }
  }

  private async digest(text: string, algorithm: string): Promise<Uint8Array> {
    const md = cryptoFramework.createMd(algorithm);
    await md.update({ data: this.encoder.encodeInto(text) });
    return (await md.digest()).data;
  }

  private base64url(bytes: Uint8Array): string {
    return new util.Base64Helper().encodeToStringSync(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  async beginLogin(): Promise<string> {
    this.verifier = this.base64url((await cryptoFramework.createRandom().generateRandom(32)).data);
    const challenge = this.base64url(await this.digest(this.verifier, 'SHA256'));
    return 'https://app-api.pixiv.net/web/v1/login?code_challenge=' + challenge +
      '&code_challenge_method=S256&client=pixiv-android';
  }

  cancelLogin(): void { this.verifier = ''; ++this.epoch; }

  isCallback(url: string): boolean {
    return /^pixiv:\/\/account\/login(?:\?|$)/.test(url) || url.startsWith(REDIRECT + '?');
  }

  async finishLogin(url: string): Promise<void> {
    if (!this.isCallback(url) || !this.verifier) { throw new PixivError('登录会话已失效，请重新打开登录页面。'); }
    const code = queryValue(url, 'code');
    if (!code) { throw new PixivError('未收到有效的登录授权，请重新登录。'); }
    const verifier = this.verifier;
    this.verifier = '';
    const generation = ++this.epoch;
    await this.exchange({ 'grant_type': 'authorization_code', 'code': code,
      'code_verifier': verifier, 'redirect_uri': REDIRECT }, generation);
  }

  async loginWithRefreshToken(token: string): Promise<void> {
    if (token.trim().length < 16) { throw new PixivError('请输入有效的 Refresh Token。'); }
    const generation = ++this.epoch;
    await this.exchange({ 'grant_type': 'refresh_token', 'refresh_token': token.trim() }, generation);
  }

  private async exchange(values: Record<string, string>, generation: number): Promise<void> {
    const headers = appHeaders();
    const time = new Date().toISOString().replace(/\.\d{3}Z$/, '+00:00');
    let hash: Uint8Array;
    try { hash = await this.digest(time + HASH_SALT, 'MD5'); }
    catch (error) {
      const code = (error as BusinessError).code || 0;
      hilog.error(0x0000, 'PixivAuth', 'OAuth request signing failed, code=%{public}d', code);
      throw new PixivError('无法完成登录校验（错误码 ' + code.toString() + '）。', code);
    }
    headers['X-Client-Time'] = time;
    headers['X-Client-Hash'] = Array.from(hash).map((byte: number) => byte.toString(16).padStart(2, '0')).join('');
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    values['client_id'] = CLIENT_ID;
    values['client_secret'] = CLIENT_SECRET;
    values['get_secure_url'] = '1';
    values['include_policy'] = 'true';
    const result = await requestJson<TokenResponse>('https://oauth.secure.pixiv.net/auth/token', headers,
      http.RequestMethod.POST, formEncode(values));
    hilog.info(0x0000, 'PixivAuth', 'OAuth token exchange completed');
    const token = result.response || result as TokenData;
    if (!token.access_token || !token.refresh_token || !token.user?.id) {
      throw new PixivError('Pixiv 未返回有效的登录信息。');
    }
    if (generation !== this.epoch) { throw new PixivError('登录操作已取消。'); }
    const session: Session = { accessToken: token.access_token, refreshToken: token.refresh_token,
      expiresAt: Date.now() + (token.expires_in || 3600) * 1000,
      userId: Number(token.user.id), name: token.user.name, avatar: token.user.profile_image_urls?.medium || '' };
    const commit = this.commits.catch(() => {}).then(async () => {
      if (generation !== this.epoch) { throw new PixivError('登录操作已取消。'); }
      await this.persist(session);
      if (generation !== this.epoch) {
        await asset.remove(this.alias());
        throw new PixivError('登录操作已取消。');
      }
      this.session = session;
      hilog.info(0x0000, 'PixivAuth', 'OAuth session securely committed');
    });
    this.commits = commit;
    await commit;
  }

  async accessToken(force: boolean = false): Promise<string> {
    if (!this.loggedIn) { throw new PixivError('登录 Pixiv 后即可使用这个功能。', 401); }
    if (force || Date.now() >= this.session.expiresAt - 60000) {
      if (!this.pendingRefresh) {
        this.pendingRefresh = this.exchange({ 'grant_type': 'refresh_token', 'refresh_token': this.session.refreshToken }, this.epoch);
      }
      try { await this.pendingRefresh; } finally { this.pendingRefresh = undefined; }
    }
    return this.session.accessToken;
  }

  async logout(): Promise<void> {
    ++this.epoch;
    this.verifier = '';
    if (this.pendingRefresh) {
      try { await this.pendingRefresh; } catch (_) { /* Finish the in-flight write before removing the asset. */ }
    }
    await this.commits.catch(() => {});
    try { await asset.remove(this.alias()); } catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) { throw new PixivError('退出失败，请稍后重试。'); }
    }
    this.session = emptySession();
  }
}

export const authService = new AuthService();

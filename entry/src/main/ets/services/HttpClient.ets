import { http } from '@kit.NetworkKit';

export class PixivError extends Error {
  status: number;
  constructor(message: string, status: number = 0) {
    super(message);
    this.name = 'PixivError';
    this.status = status;
  }
}

export function errorMessage(error: Error): string {
  return error instanceof PixivError ? error.message : '操作未完成，请重试。';
}

export async function requestJson<T>(url: string, headers: Record<string, string>,
  method: http.RequestMethod = http.RequestMethod.GET, body: string = ''): Promise<T> {
  return parseJson<T>(await requestText(url, headers, method, body));
}

export function parseJson<T>(text: string): T {
  try { return JSON.parse(text) as T; }
  catch (_) { throw new PixivError('Pixiv 返回了无法识别的内容，请稍后重试。'); }
}

export async function requestText(url: string, headers: Record<string, string>,
  method: http.RequestMethod = http.RequestMethod.GET, body: string = ''): Promise<string> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, {
      method: method, header: headers, extraData: body,
      expectDataType: http.HttpDataType.STRING, connectTimeout: 15000, readTimeout: 20000,
      usingCache: false
    });
    if (response.responseCode < 200 || response.responseCode >= 300) {
      const code = response.responseCode;
      if (code === 401) { throw new PixivError('登录已过期，请重新登录 Pixiv。', code); }
      if (code === 403) { throw new PixivError('Pixiv 暂时拒绝了请求，请稍后重试或登录后访问。', code); }
      if (code === 404) { throw new PixivError('作品不存在，或当前账号无法访问。', code); }
      if (code === 429) { throw new PixivError('请求有些频繁，请稍等片刻再试。', code); }
      throw new PixivError('Pixiv 服务暂时不可用（' + code.toString() + '）。', code);
    }
    return response.result as string;
  } catch (error) {
    if (error instanceof PixivError) { throw error; }
    throw new PixivError('连接 Pixiv 失败，请确认当前网络可以访问 pixiv.net。');
  } finally {
    request.destroy();
  }
}

export function formEncode(values: Record<string, string>): string {
  return Object.keys(values).map((key: string) => encodeURIComponent(key) + '=' + encodeURIComponent(values[key])).join('&');
}

export const WEB_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0', 'Referer': 'https://www.pixiv.net/', 'Accept-Language': 'zh-CN,ja;q=0.8'
};

export function appHeaders(): Record<string, string> {
  return { 'User-Agent': 'PixivAndroidApp/6.195.0 (Android 16; Pixel 9)',
    'App-OS': 'android', 'App-OS-Version': '16', 'App-Version': '6.195.0',
    'Accept-Language': 'zh-CN', 'Referer': 'https://app-api.pixiv.net/' };
}

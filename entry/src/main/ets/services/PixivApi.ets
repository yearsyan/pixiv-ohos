import { http } from '@kit.NetworkKit';
import { Artwork, ArtworkPage, Artist, ImagePage, AppIllustResponse, AppDetailResponse,
  AppUserResponse, AppTrendsResponse, RankingResponse, WebSearchResponse, WebDetailResponse,
  WebPagesResponse, WebArtistResponse, WebUserIdsResponse, WebUserWorksResponse } from '../models/PixivModels';
import { fromApp, fromRanking, fromSearch, fromWebDetail, uniqueArtworks, isApiUrl, isNovelWebviewUrl, plainText } from '../utils/PixivMapper';
import { NovelList, NovelContent, CommentPage, AppNovelsResponse, AppNovelResponse, WebNovelRanking,
  WebNovelSearch, WebNovelResponse, AppCommentsResponse, WebCommentsResponse, NovelChapterList,
  NovelChapter, WebNovelChapters, WebRelatedResponse, WebRelatedPage } from '../models/ReadingModels';
import { appNovel, rankedNovel, webNovel, detailedNovel, uniqueNovels, appComment, webComment,
  uniqueComments, parseNovelWebview, novelImages, relatedIds, relatedCursor, uniqueChapters } from '../utils/ReadingMapper';
import { authService } from './AuthService';
import { requestJson, requestText, parseJson, appHeaders, formEncode, WEB_HEADERS, PixivError } from './HttpClient';

const API = 'https://app-api.pixiv.net';
const WEB = 'https://www.pixiv.net';

class PixivApi {
  private async app<T>(path: string, method: http.RequestMethod = http.RequestMethod.GET,
    body: string = ''): Promise<T> {
    return parseJson<T>(await this.appRaw(path, method, body));
  }

  private async appRaw(path: string, method: http.RequestMethod = http.RequestMethod.GET,
    body: string = ''): Promise<string> {
    const url = path.startsWith('https://') ? path : API + path;
    if (!isApiUrl(url) && !isNovelWebviewUrl(url)) { throw new PixivError('无效的 Pixiv 分页地址。'); }
    const headers = appHeaders();
    headers['Authorization'] = 'Bearer ' + await authService.accessToken();
    if (method === http.RequestMethod.POST) { headers['Content-Type'] = 'application/x-www-form-urlencoded'; }
    try { return await requestText(url, headers, method, body); } catch (error) {
      if (error instanceof PixivError && error.status === 401) {
        headers['Authorization'] = 'Bearer ' + await authService.accessToken(true);
        return await requestText(url, headers, method, body);
      }
      throw error as Error;
    }
  }

  async novels(mode: string, word: string = '', sort: string = 'date_desc', cursor: string = ''): Promise<NovelList> {
    if (authService.loggedIn) {
      let path = '/v1/novel/recommended?filter=for_android&include_ranking_label=true';
      if (word.trim()) {
        path = '/v1/search/novel?filter=for_android&search_target=partial_match_for_tags&word=' +
          encodeURIComponent(word.trim()) + '&sort=' + (sort === 'date_asc' ? 'date_asc' : 'date_desc');
      } else if (mode !== 'discover') {
        path = '/v1/novel/ranking?filter=for_android&mode=' + this.novelRankMode(mode);
      }
      const response = await this.app<AppNovelsResponse>(cursor || path);
      if (!Array.isArray(response.novels)) { throw new PixivError('暂时无法读取小说列表。'); }
      return { items: uniqueNovels(response.novels.map(appNovel)), next: response.next_url || '' };
    }
    const page = this.pageNumber(cursor, 1);
    if (word.trim()) {
      const query = encodeURIComponent(word.trim());
      const response = await requestJson<WebNovelSearch>(WEB + '/ajax/search/novels/' + query + '?word=' + query +
        '&order=' + (sort === 'date_asc' ? 'date' : 'date_d') + '&mode=safe&p=' + page.toString() + '&s_mode=s_tag&lang=zh', WEB_HEADERS);
      const group = response.body?.novel;
      if (response.error || !group || !Array.isArray(group.data)) { throw new PixivError('暂时无法搜索小说，请稍后重试。'); }
      return { items: uniqueNovels(group.data.map(webNovel)),
        next: page < group.lastPage ? (page + 1).toString() : '' };
    }
    const rankMode = this.novelRankMode(mode);
    const webMode = rankMode === 'week' ? 'weekly' : rankMode === 'week_rookie' ? 'rookie' : 'daily';
    const response = await requestJson<WebNovelRanking>(WEB + '/ajax/ranking/novel?mode=' + webMode +
      '&content=novel&p=' + page.toString() + '&lang=zh', WEB_HEADERS);
    const display = response.body?.display_a;
    if (response.error || !display || !Array.isArray(display.rank_a)) { throw new PixivError('暂时无法读取小说排行榜。'); }
    return { items: uniqueNovels(display.rank_a.map(rankedNovel)),
      next: typeof display.next === 'number' && display.next > page ? display.next.toString() : '' };
  }

  private novelRankMode(mode: string): string { return mode === 'week' || mode === 'week_rookie' ? mode : 'day'; }

  private contentId(id: number): void {
    if (!Number.isSafeInteger(id) || id <= 0) { throw new PixivError('无效的作品 ID。'); }
  }

  private async webRelated(id: number, kind: string, cursor: string): Promise<WebRelatedPage> {
    const ids = cursor ? relatedCursor(cursor, id) : [];
    if (cursor && ids.length === 0) { return { body: { illusts: [], novels: [] }, next: '' }; }
    const key = kind === 'illust' ? 'illust_ids' : 'novelIds';
    const path = cursor ? '/ajax/' + kind + '/recommend/' + (kind === 'illust' ? 'illusts' : 'novels') + '?' +
      ids.slice(0, 6).map(value => key + '%5B%5D=' + value.toString()).join('&') :
      '/ajax/' + kind + '/' + id.toString() + '/recommend/init?limit=6';
    const response = await requestJson<WebRelatedResponse>(WEB + path + '&lang=zh', WEB_HEADERS);
    if (response.error || !response.body) { throw new PixivError('暂时无法读取推荐作品。'); }
    return { body: response.body, next: (cursor ? ids.slice(6) : relatedIds(response.body.nextIds || [], id)).join(',') };
  }

  async relatedArtworks(id: number, cursor: string = ''): Promise<ArtworkPage> {
    this.contentId(id);
    if (authService.loggedIn) {
      const page = await this.appPage(cursor || '/v2/illust/related?filter=for_android&illust_id=' + id.toString());
      page.items = page.items.filter(work => work.id !== id);
      return page;
    }
    const page = await this.webRelated(id, 'illust', cursor);
    if (!Array.isArray(page.body.illusts)) { throw new PixivError('暂时无法读取推荐作品。'); }
    return { items: uniqueArtworks(page.body.illusts.map(fromSearch)).filter(work => work.id !== id), next: page.next, date: '', total: 0 };
  }

  async relatedNovels(id: number, cursor: string = ''): Promise<NovelList> {
    this.contentId(id);
    if (authService.loggedIn) {
      const response = await this.app<AppNovelsResponse>(cursor || '/v1/novel/related?novel_id=' + id.toString());
      if (!Array.isArray(response.novels)) { throw new PixivError('暂时无法读取推荐小说。'); }
      return { items: uniqueNovels(response.novels.map(appNovel)).filter(novel => novel.id !== id), next: response.next_url || '' };
    }
    const page = await this.webRelated(id, 'novel', cursor);
    if (!Array.isArray(page.body.novels)) { throw new PixivError('暂时无法读取推荐小说。'); }
    return { items: uniqueNovels(page.body.novels.map(webNovel)).filter(novel => novel.id !== id), next: page.next };
  }

  async novelChapters(seriesId: number, cursor: string = ''): Promise<NovelChapterList> {
    this.contentId(seriesId);
    if (authService.loggedIn) {
      const response = await this.app<AppNovelsResponse>(cursor || '/v2/novel/series?filter=for_android&series_id=' + seriesId.toString());
      if (!Array.isArray(response.novels)) { throw new PixivError('暂时无法读取系列目录。'); }
      return { items: uniqueChapters(response.novels.map(novel => ({ id: novel.id, title: novel.title || '未命名章节',
        available: novel.visible !== false && !(novel.x_restrict > 0) } as NovelChapter))), next: response.next_url || '' };
    }
    if (cursor) { throw new PixivError('无效的目录分页。'); }
    const response = await requestJson<WebNovelChapters>(WEB + '/ajax/novel/series/' + seriesId.toString() + '/content_titles?lang=zh', WEB_HEADERS);
    if (response.error || !Array.isArray(response.body)) { throw new PixivError('暂时无法读取系列目录，请登录后重试。'); }
    return { items: uniqueChapters(response.body.map(novel => ({ id: Number(novel.id), title: novel.title || '未命名章节',
      available: novel.available === true } as NovelChapter))), next: '' };
  }

  private pageNumber(cursor: string, first: number): number {
    const value = cursor ? Number(cursor) : first;
    if (!Number.isSafeInteger(value) || value < first) { throw new PixivError('无效的页码。'); }
    return value;
  }

  async novelContent(id: number): Promise<NovelContent> {
    if (!Number.isSafeInteger(id) || id <= 0) { throw new PixivError('无效的小说 ID。'); }
    if (authService.loggedIn) {
      const response = await this.app<AppNovelResponse>('/v2/novel/detail?novel_id=' + id.toString());
      const novel = appNovel(response.novel);
      if (novel.restricted) { throw new PixivError('当前浏览模式不展示这篇小说。'); }
      const html = await this.appRaw('/webview/v2/novel?id=' + id.toString() + '&viewer_version=20221031_ai');
      const content = parseNovelWebview(html, id);
      const navigation = content.seriesNavigation;
      return { novel: novel, text: content.text,
        previousId: navigation?.prevNovel?.viewable === true ? Number(navigation.prevNovel.id) : 0,
        nextId: navigation?.nextNovel?.viewable === true ? Number(navigation.nextNovel.id) : 0,
        images: novelImages(content.images, content.illusts) };
    }
    const response = await requestJson<WebNovelResponse>(WEB + '/ajax/novel/' + id.toString() + '?lang=zh', WEB_HEADERS);
    if (response.error || !response.body) { throw new PixivError('小说不存在，或需要登录后阅读。'); }
    const novel = detailedNovel(response.body);
    if (novel.restricted) { throw new PixivError('当前浏览模式不展示这篇小说。'); }
    if (novel.id !== id || typeof response.body.content !== 'string') { throw new PixivError('这篇小说需要登录后阅读。'); }
    const navigation = response.body.seriesNavData;
    return { novel: novel, text: response.body.content,
      previousId: navigation?.prev?.available === true ? Number(navigation.prev.id) : 0,
      nextId: navigation?.next?.available === true ? Number(navigation.next.id) : 0,
      images: novelImages(response.body.textEmbeddedImages) };
  }

  async comments(id: number, kind: string, parentId: number = 0, cursor: string = ''): Promise<CommentPage> {
    if (!Number.isSafeInteger(id) || id <= 0 || !Number.isSafeInteger(parentId) || parentId < 0 ||
      (kind !== 'illust' && kind !== 'novel')) { throw new PixivError('无效的评论地址。'); }
    if (authService.loggedIn) {
      const path = parentId > 0 ? '/v2/' + kind + '/comment/replies?comment_id=' + parentId.toString() :
        '/v3/' + kind + '/comments?' + kind + '_id=' + id.toString();
      const response = await this.app<AppCommentsResponse>(cursor || path);
      if (!Array.isArray(response.comments)) { throw new PixivError('暂时无法读取评论。'); }
      return { items: uniqueComments(response.comments.map(appComment)), next: response.next_url || '' };
    }
    const offset = this.pageNumber(cursor, parentId > 0 ? 1 : 0);
    const path = '/ajax/' + (kind === 'novel' ? 'novels' : 'illusts') + '/comments/' +
      (parentId > 0 ? 'replies?comment_id=' + parentId.toString() : 'roots?' + kind + '_id=' + id.toString());
    const pagination = parentId > 0 ? '&page=' + offset.toString() : '&offset=' + offset.toString() + '&limit=20';
    const response = await requestJson<WebCommentsResponse>(WEB + path + pagination + '&lang=zh', WEB_HEADERS);
    if (response.error || !Array.isArray(response.body?.comments)) {
      throw new PixivError(parentId > 0 ? '暂时无法读取回复，请登录后重试。' : '暂时无法读取评论，作者可能关闭了评论。');
    }
    return { items: uniqueComments(response.body.comments.map(webComment)),
      next: response.body.hasNext && response.body.comments.length > 0 ?
        (offset + (parentId > 0 ? 1 : response.body.comments.length)).toString() : '' };
  }

  private async appPage(path: string): Promise<ArtworkPage> {
    const response = await this.app<AppIllustResponse>(path);
    if (!Array.isArray(response.illusts)) { throw new PixivError('暂时无法读取作品列表。'); }
    return { items: uniqueArtworks(response.illusts.map(fromApp)), next: response.next_url || '', date: '', total: 0 };
  }

  async recommended(type: string, cursor: string = ''): Promise<ArtworkPage> {
    if (!authService.loggedIn) { return this.ranking('day', type, cursor); }
    const endpoint = type === 'manga' ? '/v1/manga/recommended' : '/v1/illust/recommended';
    return this.appPage(cursor || endpoint + '?filter=for_android&content_type=' + type + '&include_ranking_label=true');
  }

  async ranking(mode: string, type: string, cursor: string = ''): Promise<ArtworkPage> {
    if (authService.loggedIn) {
      const rankMode = type === 'manga' ? 'day_manga' : mode;
      const page = await this.appPage(cursor || '/v1/illust/ranking?filter=for_android&mode=' + rankMode);
      // A page's offset is not always numeric in the App API, so only label the initial page.
      if (!cursor) { page.items.forEach((work: Artwork, index: number) => work.rank = index + 1); }
      return page;
    }
    const pageNo = cursor ? Number(cursor) : 1;
    if (!Number.isInteger(pageNo) || pageNo < 1 || pageNo > 100) { throw new PixivError('无效的页码。'); }
    let webMode = mode === 'week' ? 'weekly' : mode === 'month' ? 'monthly' : mode === 'week_rookie' ? 'rookie' : 'daily';
    if (type === 'manga') { webMode = 'daily'; }
    const response = await requestJson<RankingResponse>(WEB + '/ranking.php?format=json&mode=' + webMode +
      '&content=' + (type === 'manga' ? 'manga' : 'illust') + '&p=' + pageNo.toString(), WEB_HEADERS);
    if (!Array.isArray(response.contents)) { throw new PixivError('暂时无法读取排行榜。'); }
    return { items: uniqueArtworks(response.contents.map(fromRanking)),
      next: typeof response.next === 'number' && response.next > pageNo ? response.next.toString() : '',
      date: response.date || '', total: response.rank_total || 0 };
  }

  async search(word: string, type: string, sort: string, cursor: string = ''): Promise<ArtworkPage> {
    const query = word.trim();
    if (!query) { return { items: [], next: '', date: '', total: 0 }; }
    if (authService.loggedIn) {
      const page = await this.appPage(cursor || '/v1/search/illust?filter=for_android&word=' + encodeURIComponent(query) +
        '&search_target=partial_match_for_tags&sort=' + sort);
      // App search returns illustration and manga together; filter the normalized response,
      // retaining next_url so a page containing only the other category remains pageable.
      if (type !== 'all') { page.items = page.items.filter((work: Artwork) => type === 'manga' ? work.type === 'manga' : work.type !== 'manga'); }
      return page;
    }
    const pageNo = cursor ? Number(cursor) : 1;
    if (!Number.isInteger(pageNo) || pageNo < 1) { throw new PixivError('无效的页码。'); }
    const webType = type === 'manga' ? 'manga' : type === 'illust' ? 'illust_and_ugoira' : 'all';
    const response = await requestJson<WebSearchResponse>(WEB + '/ajax/search/artworks/' + encodeURIComponent(query) +
      '?word=' + encodeURIComponent(query) + '&order=' + (sort === 'date_asc' ? 'date' : 'date_d') +
      '&mode=safe&p=' + pageNo.toString() + '&s_mode=s_tag&type=' + webType + '&lang=zh', WEB_HEADERS);
    if (response.error) { throw new PixivError('暂时无法搜索这个关键词，请稍后重试。'); }
    const group = response.body.illustManga || response.body.illust || response.body.manga;
    if (!group || !Array.isArray(group.data)) { throw new PixivError('暂时无法读取搜索结果。'); }
    return { items: uniqueArtworks(group.data.map(fromSearch)),
      next: group.data.length > 0 && pageNo * 60 < group.total ? (pageNo + 1).toString() : '', date: '', total: group.total };
  }

  async following(cursor: string = ''): Promise<ArtworkPage> {
    return this.appPage(cursor || '/v2/illust/follow?restrict=public');
  }

  async bookmarks(cursor: string = ''): Promise<ArtworkPage> {
    return this.appPage(cursor || '/v1/user/bookmarks/illust?user_id=' + authService.session.userId.toString() + '&restrict=public');
  }

  async detail(work: Artwork): Promise<Artwork> {
    if (authService.loggedIn) {
      const response = await this.app<AppDetailResponse>('/v1/illust/detail?filter=for_android&illust_id=' + work.id.toString());
      const result = fromApp(response.illust);
      if (result.restricted) { throw new PixivError('当前浏览模式不展示这件作品。'); }
      return result;
    }
    const response = await requestJson<WebDetailResponse>(WEB + '/ajax/illust/' + work.id.toString() + '?lang=zh', WEB_HEADERS);
    if (response.error) { throw new PixivError('作品不存在，或需要登录后查看。'); }
    const result = fromWebDetail(response.body, work.avatar);
    if (result.restricted) { throw new PixivError('当前浏览模式不展示这件作品。'); }
    return result;
  }

  async pages(id: number): Promise<ImagePage[]> {
    if (authService.loggedIn) {
      const response = await this.app<AppDetailResponse>('/v1/illust/detail?filter=for_android&illust_id=' + id.toString());
      const work = response.illust;
      if (work.x_restrict > 0) { throw new PixivError('当前浏览模式不展示这件作品。'); }
      if (work.meta_pages && work.meta_pages.length > 0) {
        return work.meta_pages.map((page) => ({ url: page.image_urls.large || page.image_urls.medium || '',
          original: page.image_urls.original || '', width: work.width, height: work.height } as ImagePage));
      }
      return [{ url: work.image_urls.large || work.image_urls.medium || '',
        original: work.meta_single_page?.original_image_url || '', width: work.width, height: work.height }];
    }
    const response = await requestJson<WebPagesResponse>(WEB + '/ajax/illust/' + id.toString() + '/pages', WEB_HEADERS);
    if (response.error) { throw new PixivError('暂时无法读取作品的分页。'); }
    return response.body.map((page) => ({ url: page.urls.regular, original: page.urls.original,
      width: page.width, height: page.height } as ImagePage));
  }

  async artist(id: number): Promise<Artist> {
    if (authService.loggedIn) {
      const response = await this.app<AppUserResponse>('/v2/user/detail?filter=for_android&user_id=' + id.toString());
      return { id: response.user.id, name: response.user.name, avatar: response.user.profile_image_urls?.medium || '',
        comment: plainText(response.user.comment || ''), followed: response.user.is_followed === true,
        totalIllusts: (response.profile?.total_illusts || 0) + (response.profile?.total_manga || 0) };
    }
    const response = await requestJson<WebArtistResponse>(WEB + '/ajax/user/' + id.toString() + '?full=1&lang=zh', WEB_HEADERS);
    if (response.error) { throw new PixivError('暂时无法读取画师信息。'); }
    return { id: id, name: response.body.name, avatar: response.body.imageBig,
      comment: plainText(response.body.comment), followed: response.body.isFollowed, totalIllusts: 0 };
  }

  async artistWorks(id: number, cursor: string = ''): Promise<ArtworkPage> {
    if (authService.loggedIn) {
      return this.appPage(cursor || '/v1/user/illusts?filter=for_android&user_id=' + id.toString() + '&type=illust');
    }
    const response = await requestJson<WebUserIdsResponse>(WEB + '/ajax/user/' + id.toString() + '/profile/all', WEB_HEADERS);
    if (response.error) { throw new PixivError('暂时无法读取画师作品。'); }
    const ids = (response.body.illusts ? Object.keys(response.body.illusts) : []).concat(response.body.manga ? Object.keys(response.body.manga) : [])
      .map((value: string) => Number(value)).sort((a: number, b: number) => b - a);
    const offset = cursor ? Number(cursor) : 0;
    const selection = ids.slice(offset, offset + 30);
    if (selection.length === 0) { return { items: [], next: '', date: '', total: ids.length }; }
    const works = await requestJson<WebUserWorksResponse>(WEB + '/ajax/user/' + id.toString() + '/profile/illusts?' +
      selection.map((value: number) => 'ids%5B%5D=' + value.toString()).join('&') + '&work_category=illustManga&is_first_page=0&lang=zh', WEB_HEADERS);
    if (works.error) { throw new PixivError('暂时无法读取画师作品。'); }
    const items = Object.values(works.body.works).map(fromSearch).sort((a: Artwork, b: Artwork) => b.id - a.id);
    return { items: uniqueArtworks(items), next: offset + 30 < ids.length ? (offset + 30).toString() : '', date: '', total: ids.length };
  }

  async trends(): Promise<string[]> {
    if (authService.loggedIn) {
      const result = await this.app<AppTrendsResponse>('/v1/trending-tags/illust?filter=for_android');
      return result.trend_tags.map((tag) => tag.tag).slice(0, 16);
    }
    const page = await this.ranking('day', 'illust');
    const tags: string[] = [];
    for (const work of page.items) {
      for (const tag of work.tags) {
        if (!tags.includes(tag) && !/users入り|R-18/i.test(tag)) { tags.push(tag); }
      }
      if (tags.length >= 16) { break; }
    }
    return tags.slice(0, 16);
  }

  async bookmark(id: number, remove: boolean): Promise<void> {
    await this.app<Object>(remove ? '/v1/illust/bookmark/delete' : '/v2/illust/bookmark/add',
      http.RequestMethod.POST, formEncode({ 'illust_id': id.toString(), 'restrict': 'public' }));
  }

  async follow(id: number, remove: boolean): Promise<void> {
    await this.app<Object>(remove ? '/v1/user/follow/delete' : '/v1/user/follow/add',
      http.RequestMethod.POST, formEncode({ 'user_id': id.toString(), 'restrict': 'public' }));
  }
}

export const pixivApi = new PixivApi();

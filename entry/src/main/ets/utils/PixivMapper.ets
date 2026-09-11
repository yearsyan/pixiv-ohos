import { Artwork, AppIllust, RankingItem, WebWork, WebDetail } from '../models/PixivModels';

export function plainText(value: string): string {
  return (value || '').replace(/<br\s*\/?\s*>/gi, '\n').replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&nbsp;/g, ' ').trim();
}

export function largeThumbnail(url: string): string {
  // Search thumbnails are square crops. Use Pixiv's uncropped master image for the waterfall.
  return url.replace(/\/c\/[^/]+\//, '/').replace('_square1200', '_master1200');
}

export function fromRanking(item: RankingItem): Artwork {
  return { id: item.illust_id, title: item.title, type: item.illust_type === '1' ? 'manga' : 'illust',
    width: item.width || 1, height: item.height || 1, imageUrl: item.url, originalUrl: '',
    pageCount: Number(item.illust_page_count) || 1, userId: item.user_id, userName: item.user_name,
    avatar: item.profile_img, tags: item.tags || [], caption: '', bookmarkCount: 0,
    viewCount: item.view_count || 0, bookmarked: false, rank: item.rank, createDate: item.date,
    restricted: item.is_masked === true || (item.illust_content_type?.sexual || 0) > 0 };
}

export function fromSearch(item: WebWork): Artwork {
  return { id: Number(item.id), title: item.title, type: item.illustType === 1 ? 'manga' : 'illust',
    width: item.width || 1, height: item.height || 1, imageUrl: largeThumbnail(item.url || ''), originalUrl: '',
    pageCount: item.pageCount || 1, userId: Number(item.userId), userName: item.userName,
    avatar: item.profileImageUrl || '', tags: item.tags || [], caption: '', bookmarkCount: 0,
    viewCount: 0, bookmarked: false, restricted: item.xRestrict > 0 || item.isMasked === true,
    rank: 0, createDate: item.createDate || '' };
}

export function fromWebDetail(item: WebDetail, avatar: string): Artwork {
  return { id: Number(item.id), title: item.title, type: item.illustType === 1 ? 'manga' : 'illust',
    width: item.width || 1, height: item.height || 1, imageUrl: item.urls.regular, originalUrl: item.urls.original,
    pageCount: item.pageCount || 1, userId: Number(item.userId), userName: item.userName, avatar: avatar,
    tags: item.tags.tags.map((tag) => tag.tag), caption: plainText(item.description),
    bookmarkCount: item.bookmarkCount || 0, viewCount: item.viewCount || 0, bookmarked: false,
    restricted: item.xRestrict > 0, rank: 0, createDate: item.createDate };
}

export function fromApp(item: AppIllust): Artwork {
  return { id: item.id, title: item.title, type: item.type, width: item.width || 1, height: item.height || 1,
    imageUrl: item.image_urls.large || item.image_urls.medium || '',
    originalUrl: item.meta_single_page?.original_image_url || item.meta_pages?.[0]?.image_urls.original || '',
    pageCount: item.page_count || 1, userId: item.user.id, userName: item.user.name,
    avatar: item.user.profile_image_urls?.medium || '', tags: (item.tags || []).map((tag) => tag.name),
    caption: plainText(item.caption), bookmarkCount: item.total_bookmarks || 0, viewCount: item.total_view || 0,
    bookmarked: item.is_bookmarked === true, restricted: item.x_restrict > 0 || item.visible === false,
    rank: 0, createDate: item.create_date };
}

export function uniqueArtworks(items: Artwork[]): Artwork[] {
  const seen: Set<number> = new Set<number>();
  return items.filter((item: Artwork) => {
    if (!item.id || item.restricted || seen.has(item.id) || !item.imageUrl) { return false; }
    seen.add(item.id);
    return true;
  });
}

export function compactCount(value: number): string {
  return value >= 10000 ? (value / 10000).toFixed(1) + '万' : value.toString();
}

export function isApiUrl(url: string): boolean {
  return /^https:\/\/app-api\.pixiv\.net\/v[12]\/[a-z0-9/_.?=&%+\[\],-]+$/i.test(url);
}

export function isImageUrl(url: string): boolean {
  return /^https:\/\/(?:[a-z0-9-]+\.)?pximg\.net\//i.test(url);
}

export function queryValue(url: string, key: string): string {
  const query = url.split('?')[1]?.split('#')[0] || '';
  for (const part of query.split('&')) {
    const index = part.indexOf('=');
    if (index > 0 && part.substring(0, index) === key) {
      try { return decodeURIComponent(part.substring(index + 1)); } catch (_) { return ''; }
    }
  }
  return '';
}

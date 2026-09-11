export interface Artwork {
  id: number;
  title: string;
  type: string;
  width: number;
  height: number;
  imageUrl: string;
  originalUrl: string;
  pageCount: number;
  userId: number;
  userName: string;
  avatar: string;
  tags: string[];
  caption: string;
  bookmarkCount: number;
  viewCount: number;
  bookmarked: boolean;
  restricted: boolean;
  rank: number;
  createDate: string;
}

export interface ArtworkPage {
  items: Artwork[];
  next: string;
  date: string;
  total: number;
}

export interface Artist {
  id: number;
  name: string;
  avatar: string;
  comment: string;
  followed: boolean;
  totalIllusts: number;
}

export interface ImagePage {
  url: string;
  original: string;
  width: number;
  height: number;
}

export interface Session {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  userId: number;
  name: string;
  avatar: string;
}

export interface AppImageUrls {
  square_medium?: string;
  medium?: string;
  large?: string;
  original?: string;
}

export interface AppUser {
  id: number;
  name: string;
  comment?: string;
  is_followed?: boolean;
  profile_image_urls?: AppImageUrls;
}

export interface AppTag {
  name: string;
  translated_name?: string;
}

export interface AppMetaPage { image_urls: AppImageUrls; }
export interface AppSinglePage { original_image_url?: string; }

export interface AppIllust {
  id: number;
  title: string;
  type: string;
  image_urls: AppImageUrls;
  caption: string;
  user: AppUser;
  tags: AppTag[];
  create_date: string;
  page_count: number;
  width: number;
  height: number;
  total_view: number;
  total_bookmarks: number;
  is_bookmarked: boolean;
  x_restrict: number;
  visible?: boolean;
  meta_single_page?: AppSinglePage;
  meta_pages?: AppMetaPage[];
}

export interface AppIllustResponse {
  illusts: AppIllust[];
  next_url?: string;
}
export interface AppDetailResponse { illust: AppIllust; }
export interface AppProfile { total_illusts: number; total_manga: number; }
export interface AppUserResponse { user: AppUser; profile: AppProfile; }
export interface AppTrend { tag: string; translated_name?: string; }
export interface AppTrendsResponse { trend_tags: AppTrend[]; }
export interface TokenData {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  user: AppUser;
}
export interface TokenResponse { response?: TokenData; access_token?: string; refresh_token?: string; expires_in?: number; user?: AppUser; }

export interface WebContentType { sexual: number; }
export interface RankingItem {
  illust_id: number;
  title: string;
  illust_type: string;
  url: string;
  width: number;
  height: number;
  illust_page_count: string;
  user_id: number;
  user_name: string;
  profile_img: string;
  tags: string[];
  rank: number;
  date: string;
  view_count: number;
  is_masked?: boolean;
  illust_content_type?: WebContentType;
}
export interface RankingResponse { contents: RankingItem[]; next: number | boolean; date: string; rank_total: number; }

export interface WebWork {
  id: string;
  title: string;
  illustType: number;
  xRestrict: number;
  url: string;
  width: number;
  height: number;
  pageCount: number;
  userId: string;
  userName: string;
  profileImageUrl?: string;
  tags: string[];
  createDate: string;
  isMasked?: boolean;
}
export interface WebSearchGroup { data: WebWork[]; total: number; }
export interface WebSearchBody { illustManga?: WebSearchGroup; illust?: WebSearchGroup; manga?: WebSearchGroup; relatedTags?: string[]; }
export interface WebSearchResponse { error: boolean; message?: string; body: WebSearchBody; }
export interface WebUrls { small: string; regular: string; original: string; }
export interface WebTag { tag: string; }
export interface WebTags { tags: WebTag[]; }
export interface WebDetail {
  id: string;
  title: string;
  illustType: number;
  xRestrict: number;
  urls: WebUrls;
  width: number;
  height: number;
  pageCount: number;
  userId: string;
  userName: string;
  tags: WebTags;
  description: string;
  bookmarkCount: number;
  viewCount: number;
  createDate: string;
}
export interface WebDetailResponse { error: boolean; message: string; body: WebDetail; }
export interface WebImagePage { urls: WebUrls; width: number; height: number; }
export interface WebPagesResponse { error: boolean; message: string; body: WebImagePage[]; }
export interface WebArtist { userId: string; name: string; imageBig: string; comment: string; isFollowed: boolean; }
export interface WebArtistResponse { error: boolean; message: string; body: WebArtist; }
export interface WebUserWorks { works: Record<string, WebWork>; }
export interface WebUserWorksResponse { error: boolean; message: string; body: WebUserWorks; }
export interface WebUserIds { illusts: Record<string, null>; manga: Record<string, null>; }
export interface WebUserIdsResponse { error: boolean; message: string; body: WebUserIds; }

export function emptyArtwork(): Artwork {
  return { id: 0, title: '', type: 'illust', width: 1, height: 1, imageUrl: '', originalUrl: '', pageCount: 1,
    userId: 0, userName: '', avatar: '', tags: [], caption: '', bookmarkCount: 0, viewCount: 0,
    bookmarked: false, restricted: false, rank: 0, createDate: '' };
}

export function emptySession(): Session {
  return { accessToken: '', refreshToken: '', expiresAt: 0, userId: 0, name: '', avatar: '' };
}

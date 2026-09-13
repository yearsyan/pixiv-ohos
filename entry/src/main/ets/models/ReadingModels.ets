import { AppImageUrls, AppUser, AppTag, WebTags } from './PixivModels';

export interface Novel {
  id: number;
  title: string;
  cover: string;
  userId: number;
  userName: string;
  caption: string;
  tags: string[];
  textCount: number;
  bookmarkCount: number;
  createDate: string;
  restricted: boolean;
  seriesTitle: string;
  rank: number;
}

export interface NovelList { items: Novel[]; next: string; }
export interface NovelContent { novel: Novel; text: string; previousId: number; nextId: number; images: Record<string, string>; }
export interface ReaderBlock { kind: string; text: string; imageUrl?: string; }
export interface ReaderPage { blocks: ReaderBlock[]; }

export interface WorkComment {
  id: number;
  text: string;
  date: string;
  userName: string;
  avatar: string;
  stampUrl: string;
  hasReplies: boolean;
  replyTo: string;
}
export interface CommentPage { items: WorkComment[]; next: string; }
export interface CommentTarget { id: number; kind: string; title: string; parent?: WorkComment; }

export interface AppNovel {
  id: number;
  title: string;
  image_urls: AppImageUrls;
  caption: string;
  tags: AppTag[];
  user: AppUser;
  text_length: number;
  total_bookmarks: number;
  create_date: string;
  x_restrict: number;
  visible?: boolean;
  series?: AppNovelSeries;
}
export interface AppNovelSeries { id?: number; title?: string; }
export interface AppNovelsResponse { novels: AppNovel[]; next_url?: string; }
export interface AppNovelResponse { novel: AppNovel; }
export interface NovelNeighbor { id: string | number; available?: boolean; viewable?: boolean; }
export interface NovelNavigation { title?: string; prev?: NovelNeighbor; next?: NovelNeighbor; }
export interface AppNovelNavigation { prevNovel?: NovelNeighbor; nextNovel?: NovelNeighbor; }
export interface NovelEmbeddedUrls { original?: string; }
export interface NovelEmbeddedImage { urls: NovelEmbeddedUrls; }
export interface NovelEmbeddedIllustInfo { images: NovelEmbeddedUrls; }
export interface NovelEmbeddedIllust { illust?: NovelEmbeddedIllustInfo; }
export interface AppNovelText {
  id: string | number;
  text: string;
  seriesNavigation?: AppNovelNavigation;
  images?: Record<string, NovelEmbeddedImage>;
  illusts?: Record<string, NovelEmbeddedIllust>;
}

export interface WebNovel {
  id: string;
  title: string;
  url?: string;
  userId: string;
  userName: string;
  description?: string;
  tags: string[];
  textCount?: number;
  bookmarkCount?: number;
  createDate?: string;
  xRestrict: number;
  isMasked?: boolean;
  seriesTitle?: string;
}
export interface WebNovelSearch { error: boolean; body: WebNovelSearchBody; }
export interface WebNovelSearchBody { novel: WebNovelSearchGroup; }
export interface WebNovelSearchGroup { data: WebNovel[]; total: number; lastPage: number; }
export interface WebNovelRank {
  id: string;
  title: string;
  url: string;
  user_id: string;
  user_name: string;
  comment?: string;
  tag_a: string[];
  character_count: string;
  bookmark_count: number;
  create_date: string;
  x_restrict: string;
  series_title?: string;
  rank: number;
}
export interface WebNovelRanking { error: boolean; body: WebNovelRankingBody; }
export interface WebNovelRankingBody { display_a: WebNovelRankingDisplay; }
export interface WebNovelRankingDisplay { rank_a: WebNovelRank[]; next?: number; }
export interface WebNovelDetail {
  id: string;
  title: string;
  coverUrl: string;
  userId: string;
  userName: string;
  description: string;
  tags: WebTags;
  characterCount?: number;
  bookmarkCount: number;
  createDate: string;
  xRestrict: number;
  content?: string;
  isLoginOnly?: boolean;
  seriesNavData?: NovelNavigation;
  textEmbeddedImages?: Record<string, NovelEmbeddedImage>;
}
export interface WebNovelResponse { error: boolean; body: WebNovelDetail; }

export interface AppCommentStamp { stamp_url?: string; stamp_id?: number; }
export interface AppComment {
  id: number;
  comment: string;
  date: string;
  user?: AppUser;
  stamp?: AppCommentStamp;
  has_replies?: boolean;
  parent_comment?: AppComment;
}
export interface AppCommentsResponse { comments: AppComment[]; next_url?: string; }
export interface WebComment {
  id: string;
  comment: string;
  commentDate: string;
  userName: string;
  img: string;
  stampId?: string;
  hasReplies: boolean;
  isDeletedUser?: boolean;
  replyToUserName?: string;
}
export interface WebCommentsResponse { error: boolean; body: WebCommentsBody; }
export interface WebCommentsBody { comments: WebComment[]; hasNext: boolean; }

export function emptyNovel(): Novel {
  return { id: 0, title: '', cover: '', userId: 0, userName: '', caption: '', tags: [], textCount: 0,
    bookmarkCount: 0, createDate: '', restricted: false, seriesTitle: '', rank: 0 };
}

import { Novel, AppNovel, WebNovel, WebNovelRank, WebNovelDetail, WorkComment,
  AppComment, WebComment, AppNovelText, ReaderBlock, ReaderPage, NovelEmbeddedImage, NovelEmbeddedIllust } from '../models/ReadingModels';
import { plainText, isImageUrl } from './PixivMapper';
import { PixivError } from '../services/HttpClient';

export function appNovel(item: AppNovel): Novel {
  return { id: item.id, title: item.title, cover: item.image_urls?.large || item.image_urls?.medium || '',
    userId: item.user.id, userName: item.user.name, caption: plainText(item.caption), tags: (item.tags || []).map(tag => tag.name),
    textCount: item.text_length || 0, bookmarkCount: item.total_bookmarks || 0, createDate: item.create_date || '',
    restricted: item.x_restrict > 0 || item.visible === false, seriesTitle: item.series?.title || '', rank: 0 };
}

export function webNovel(item: WebNovel): Novel {
  return { id: Number(item.id), title: item.title, cover: item.url || '', userId: Number(item.userId), userName: item.userName,
    caption: plainText(item.description || ''), tags: item.tags || [], textCount: item.textCount || 0,
    bookmarkCount: item.bookmarkCount || 0, createDate: item.createDate || '',
    restricted: item.xRestrict > 0 || item.isMasked === true, seriesTitle: item.seriesTitle || '', rank: 0 };
}

export function rankedNovel(item: WebNovelRank): Novel {
  return { id: Number(item.id), title: item.title, cover: item.url || '', userId: Number(item.user_id), userName: item.user_name,
    caption: plainText(item.comment || ''), tags: item.tag_a || [], textCount: Number(item.character_count) || 0,
    bookmarkCount: item.bookmark_count || 0, createDate: item.create_date || '',
    restricted: Number(item.x_restrict) > 0, seriesTitle: item.series_title || '', rank: item.rank || 0 };
}

export function detailedNovel(item: WebNovelDetail): Novel {
  return { id: Number(item.id), title: item.title, cover: item.coverUrl || '', userId: Number(item.userId), userName: item.userName,
    caption: plainText(item.description), tags: (item.tags?.tags || []).map(tag => tag.tag),
    textCount: item.characterCount || item.content?.length || 0, bookmarkCount: item.bookmarkCount || 0,
    createDate: item.createDate || '', restricted: item.xRestrict > 0, seriesTitle: item.seriesNavData?.title || '', rank: 0 };
}

export function uniqueNovels(items: Novel[]): Novel[] {
  const seen: Set<number> = new Set<number>();
  return items.filter((item: Novel) => {
    if (!Number.isSafeInteger(item.id) || item.id <= 0 || item.restricted || seen.has(item.id)) { return false; }
    seen.add(item.id);
    return true;
  });
}

function stampUrl(id: string): string {
  return /^\d+$/.test(id) ? 'https://s.pximg.net/common/images/stamp/generated-stamps/' + id + '_s.jpg' : '';
}

export function appComment(item: AppComment): WorkComment {
  const stamp = item.stamp?.stamp_url || stampUrl((item.stamp?.stamp_id || '').toString());
  return { id: item.id, text: item.comment || '', date: item.date || '', userName: item.user?.name || '已注销用户',
    avatar: item.user?.profile_image_urls?.medium || '', stampUrl: isImageUrl(stamp) ? stamp : '',
    hasReplies: item.has_replies === true, replyTo: item.parent_comment?.user?.name || '' };
}

export function webComment(item: WebComment): WorkComment {
  return { id: Number(item.id), text: item.comment || '', date: item.commentDate || '',
    userName: item.isDeletedUser ? '已注销用户' : item.userName || 'Pixiv 用户', avatar: item.img || '',
    stampUrl: stampUrl(item.stampId || ''), hasReplies: item.hasReplies === true, replyTo: item.replyToUserName || '' };
}

export function uniqueComments(items: WorkComment[]): WorkComment[] {
  const seen: Set<number> = new Set<number>();
  return items.filter((item: WorkComment) => {
    if (!Number.isSafeInteger(item.id) || item.id <= 0 || seen.has(item.id)) { return false; }
    seen.add(item.id);
    return true;
  });
}

// Read the embedded JSON object only; never execute Pixiv's webview scripts.
export function parseNovelWebview(html: string, id: number): AppNovelText {
  const marker = /\bnovel\s*:\s*\{/.exec(html);
  if (!marker) { throw new PixivError('暂时无法读取小说正文，请重试或在原站查看。'); }
  const start = marker.index + marker[0].lastIndexOf('{');
  let depth = 0;
  let quoted = false;
  let escaped = false;
  for (let i = start; i < html.length; i++) {
    const char = html.charAt(i);
    if (quoted) {
      if (escaped) { escaped = false; }
      else if (char === '\\') { escaped = true; }
      else if (char === '"') { quoted = false; }
    } else if (char === '"') { quoted = true; }
    else if (char === '{') { depth++; }
    else if (char === '}') {
      depth--;
      if (depth === 0) {
        try {
          const novel = JSON.parse(html.substring(start, i + 1)) as AppNovelText;
          if (Number(novel.id) === id && typeof novel.text === 'string') { return novel; }
        } catch (_) {}
        break;
      }
    }
  }
  throw new PixivError('暂时无法读取小说正文，请重试或在原站查看。');
}

export function novelImages(images?: Record<string, NovelEmbeddedImage>, illusts?: Record<string, NovelEmbeddedIllust>): Record<string, string> {
  const result: Record<string, string> = {};
  if (images) {
    for (const key of Object.keys(images)) {
      const url = images[key]?.urls?.original || '';
      if (isImageUrl(url)) { result['uploadedimage:' + key] = url; }
    }
  }
  if (illusts) {
    for (const key of Object.keys(illusts)) {
      const url = illusts[key]?.illust?.images?.original || '';
      if (isImageUrl(url)) { result['pixivimage:' + key] = url; }
    }
  }
  return result;
}

export function readerPages(text: string, images: Record<string, string> = {}): ReaderPage[] {
  const pages: ReaderPage[] = [];
  const source = text.replace(/\r\n?/g, '\n')
    .replace(/\[\[rb:([^\]]+?)\s*>\s*([^\]]+?)\]\]/g, '$1（$2）')
    .replace(/\[\[jumpuri:([^\]]+?)\s*>\s*([^\]]+?)\]\]/g, '$1（$2）')
    .replace(/\[jump:(\d+)\]/g, '（跳转至原文第 $1 页）')
    .replace(/\[(chapter:[^\]]*|pixivimage:[^\]]*|uploadedimage:[^\]]*)\]/g, '\n[$1]\n');
  for (const section of source.split('[newpage]')) {
    let blocks: ReaderBlock[] = [];
    let length = 0;
    for (const line of section.split('\n')) {
      if (!line.trim()) { continue; }
      let kind = 'text';
      let content = line;
      let imageUrl = '';
      if (line.startsWith('[chapter:') && line.endsWith(']')) { kind = 'chapter'; content = line.slice(9, -1); }
      else if (/^\[(pixivimage|uploadedimage):[^\]]*\]$/.test(line)) {
        kind = 'image'; content = '在原站查看插图';
        imageUrl = images[line.slice(1, -1)] || '';
        if (!isImageUrl(imageUrl)) { imageUrl = ''; }
      }
      // Bound each Text node and each screenful, including novels without manual page breaks.
      for (let offset = 0; offset < content.length;) {
        if (length >= 10000) { pages.push({ blocks: blocks }); blocks = []; length = 0; }
        let end = Math.min(content.length, offset + 2000);
        const last = content.charCodeAt(end - 1);
        if (end < content.length && last >= 0xD800 && last <= 0xDBFF) { end++; }
        const chunk = content.substring(offset, end);
        blocks.push({ kind: kind, text: chunk, imageUrl: imageUrl });
        length += chunk.length;
        offset = end;
      }
    }
    if (blocks.length > 0) { pages.push({ blocks: blocks }); }
  }
  return pages;
}

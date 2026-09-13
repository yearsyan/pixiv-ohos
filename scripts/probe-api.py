#!/usr/bin/env python3
"""Read-only public API smoke checks. Never download images or print account credentials."""
import concurrent.futures, json, sys, urllib.request, urllib.parse
HEADERS={'User-Agent':'Mozilla/5.0','Referer':'https://www.pixiv.net/','Accept-Language':'zh-CN'}
def get(path):
 req=urllib.request.Request('https://www.pixiv.net'+path,headers=HEADERS)
 with urllib.request.urlopen(req,timeout=20) as response:
  data=json.load(response)
 assert not data.get('error'), 'Pixiv returned an error'
 return data

def reading_checks(illust_id):
 paths={
  'novel daily':'/ajax/ranking/novel?mode=daily&content=novel&p=1&lang=zh',
  'novel weekly':'/ajax/ranking/novel?mode=weekly&content=novel&p=1&lang=zh',
  'novel rookie':'/ajax/ranking/novel?mode=rookie&content=novel&p=1&lang=zh',
  'novel search':'/ajax/search/novels/landscape?word=landscape&order=date_d&mode=safe&p=1&s_mode=s_tag&lang=zh',
  'artwork comments':'/ajax/illusts/comments/roots?illust_id='+str(illust_id)+'&offset=0&limit=20&lang=zh'
 }
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
  results=dict(zip(paths,pool.map(get,paths.values())))
 for key in ('novel daily','novel weekly','novel rookie'):
  assert isinstance(results[key]['body']['display_a']['rank_a'],list)
  print('PASS',key)
 group=results['novel search']['body']['novel']
 assert isinstance(group['data'],list) and isinstance(group['lastPage'],int)
 print('PASS novel search pagination schema')
 assert isinstance(results['artwork comments']['body']['comments'],list)
 print('PASS artwork comments')
 novels=[n for n in results['novel daily']['body']['display_a']['rank_a'] if not int(n.get('x_restrict',0))]
 assert novels
 detail=get('/ajax/novel/'+str(novels[0]['id'])+'?lang=zh')['body']
 assert isinstance(detail['content'],str) and str(detail['id'])==str(novels[0]['id'])
 print('PASS novel detail and text schema')
 reply_checked=False
 for novel in novels[:8]:
  body=get('/ajax/novels/comments/roots?novel_id='+str(novel['id'])+'&offset=0&limit=20&lang=zh')['body']
  assert isinstance(body['comments'],list) and isinstance(body['hasNext'],bool)
  parent=next((c for c in body['comments'] if c.get('hasReplies')),None)
  if not parent:continue
  try:
   replies=get('/ajax/novels/comments/replies?comment_id='+str(parent['id'])+'&page=1&lang=zh')['body']
  except AssertionError:
   continue  # Some threads require login even when their roots are public.
  assert isinstance(replies['comments'],list) and isinstance(replies['hasNext'],bool)
  reply_checked=True
  print('PASS public novel replies:',len(replies['comments']),'items')
  break
 print('PASS novel root comments')
 if not reply_checked:print('SKIP replies: no accessible reply thread among the first 8 novels')
 stamp=urllib.request.Request('https://s.pximg.net/common/images/stamp/generated-stamps/101_s.jpg',headers=HEADERS,method='HEAD')
 with urllib.request.urlopen(stamp,timeout=20) as response:
  assert response.headers.get('Content-Type','').startswith('image/')
 print('PASS comment stamp URL (HEAD only)')

def main():
 ranking=get('/ranking.php?format=json&mode=daily&content=illust&p=1')
 items=ranking['contents'];assert items and isinstance(items[0]['illust_id'],int)
 safe=next(x for x in items if not x.get('is_masked') and not x.get('illust_content_type',{}).get('sexual'))
 print('PASS daily ranking:',len(items),'items; next page:',ranking['next'])
 if '--reading-only' in sys.argv:
  reading_checks(safe['illust_id'])
  return
 paths={
  'weekly':'/ranking.php?format=json&mode=weekly&content=illust&p=1',
  'monthly':'/ranking.php?format=json&mode=monthly&content=illust&p=1',
  'rookie':'/ranking.php?format=json&mode=rookie&content=illust&p=1',
  'manga':'/ranking.php?format=json&mode=daily&content=manga&p=1',
  'search':'/ajax/search/artworks/landscape?word=landscape&order=date_d&mode=safe&p=1&s_mode=s_tag&type=all&lang=zh',
  'detail':'/ajax/illust/'+str(safe['illust_id'])+'?lang=zh',
  'pages':'/ajax/illust/'+str(safe['illust_id'])+'/pages',
  'artist':'/ajax/user/'+str(safe['user_id'])+'?full=1&lang=zh',
  'artistIds':'/ajax/user/'+str(safe['user_id'])+'/profile/all'
 }
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
  results=dict(zip(paths,pool.map(get,paths.values())))
 for kind,result in results.items():
  assert result.get('contents') or result.get('body') is not None
  print('PASS',kind,'response schema')
 assert results['search']['body']['illustManga']['data']
 assert results['detail']['body']['urls']['regular'].startswith('https://i.pximg.net/')
 assert len(results['pages']['body'])>=1
 ids=results['artistIds']['body'].get('illusts') or {}
 selection=sorted(ids,key=int,reverse=True)[:3]
 works=get('/ajax/user/'+str(safe['user_id'])+'/profile/illusts?'+urllib.parse.urlencode([('ids[]',i) for i in selection])+'&work_category=illustManga&is_first_page=0&lang=zh')
 assert len(works['body']['works'])>0
 print('PASS artist works; all public read-only checks passed')
 reading_checks(safe['illust_id'])
if __name__=='__main__':main()

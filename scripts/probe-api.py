#!/usr/bin/env python3
"""Read-only public API smoke checks. Never download images or print account credentials."""
import concurrent.futures, json, urllib.request, urllib.parse
HEADERS={'User-Agent':'Mozilla/5.0','Referer':'https://www.pixiv.net/','Accept-Language':'zh-CN'}
def get(path):
 req=urllib.request.Request('https://www.pixiv.net'+path,headers=HEADERS)
 with urllib.request.urlopen(req,timeout=20) as response:
  data=json.load(response)
 assert not data.get('error'), 'Pixiv returned an error'
 return data

def main():
 ranking=get('/ranking.php?format=json&mode=daily&content=illust&p=1')
 items=ranking['contents'];assert items and isinstance(items[0]['illust_id'],int)
 safe=next(x for x in items if not x.get('is_masked') and not x.get('illust_content_type',{}).get('sexual'))
 print('PASS daily ranking:',len(items),'items; next page:',ranking['next'])
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
if __name__=='__main__':main()

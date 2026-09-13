# Pixiv 接口接入说明

核对日期：2026-09-13。Android 参考版本：6.195.0（versionCode 68093）。安装包中已确认 App API 域名、客户端标识与下列 JSON 接口路径；小说正文补充参考开源客户端的 WebView 协议。

## 登录后的 App API

主机：`https://app-api.pixiv.net`。

| 功能 | 方法与路径 |
| --- | --- |
| 插画推荐 | GET `/v1/illust/recommended?filter=for_android` |
| 漫画推荐 | GET `/v1/manga/recommended?filter=for_android` |
| 排行榜 | GET `/v1/illust/ranking?filter=for_android&mode=day` |
| 搜索 | GET `/v1/search/illust?filter=for_android&word=...&search_target=partial_match_for_tags&sort=date_desc` |
| 作品详情 | GET `/v1/illust/detail?filter=for_android&illust_id=...` |
| 小说推荐 / 榜单 | GET `/v1/novel/recommended` / `/v1/novel/ranking?mode=day` |
| 小说搜索 | GET `/v1/search/novel?word=...&search_target=partial_match_for_tags&sort=date_desc` |
| 小说详情 | GET `/v2/novel/detail?novel_id=...` |
| 小说正文 | GET `/webview/v2/novel?id=...&viewer_version=20221031_ai` |
| 作品评论 | GET `/v3/illust/comments?illust_id=...` / `/v3/novel/comments?novel_id=...` |
| 评论回复 | GET `/v2/illust/comment/replies?comment_id=...` / `/v2/novel/comment/replies?comment_id=...` |
| 画师详情 | GET `/v2/user/detail?filter=for_android&user_id=...` |
| 画师作品 | GET `/v1/user/illusts?filter=for_android&user_id=...&type=illust` |
| 热门标签 | GET `/v1/trending-tags/illust?filter=for_android` |
| 关注动态 | GET `/v2/illust/follow?restrict=public` |
| 公开收藏 | GET `/v1/user/bookmarks/illust?user_id=...&restrict=public` |
| 收藏 / 取消 | POST `/v2/illust/bookmark/add` / `/v1/illust/bookmark/delete` |
| 关注 / 取消 | POST `/v1/user/follow/add` / `/v1/user/follow/delete` |

使用 Bearer Token、App-OS、App-Version、User-Agent、Accept-Language 等请求头。写入请求使用表单编码，只在用户点击收藏/关注时调用。`next_url` 保留服务端原始分页参数，并在发送 Authorization 前检查 HTTPS 和精确主机。App 搜索的插画/漫画分类在响应归一化后过滤，仍保留游标以继续加载。

多图作品使用详情中的 `meta_pages[].image_urls.original`。单图原图地址来自 `meta_single_page.original_image_url`。游客使用图片分页响应中的 `urls.original`。独立全屏查看与相册保存只使用这些原图地址；缺失时补取详情/分页数据，仍缺失则报错，不退回预览图。

普通作品详情也加载上述 original 地址。`large / regular` 仅在等待原图时作为预览，原图解码成功后才替换；下载或解码失败时保留预览并提供重试。详情图关闭自动降采样，以实际像素计算 `Contain` 缩放比例，缩小时使用 `Medium` 插值、放大时使用 `High` 插值。仅当前可见页渲染原图，异步结果按请求代次检查，翻页或离开后不会把旧请求写回新页面。全屏查看和相册保存复用同一份文件缓存。

原图请求携带 Pixiv Referer，超时为 60 秒，单次响应上限为 SDK 允许的 100 MiB。原图文件优先排队，先完整写入临时文件再原子改名进入缓存。查看时关闭 Image 自动降采样，仅当前页解码。保存时使用 HarmonyOS `showAssetsCreationDialog` 获得单个目标资产的授权，将下载的原始文件直接复制到相册 URI，完成后核对源文件与相册文件的完整 SHA-256；不做图片重编码，不请求全相册访问权限。

## OAuth

- 入口：`https://app-api.pixiv.net/web/v1/login`。
- 使用安全随机数生成 32 字节 verifier，使用 SHA-256 + Base64URL 生成 S256 challenge。
- 捕获 `pixiv://account/login?code=...` 授权回调，也支持精确的 HTTPS callback 路径。
- 令牌交换：POST `https://oauth.secure.pixiv.net/auth/token`。
- 回调地址参数：`https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback`。
- 支持 `authorization_code` 和 `refresh_token` 两种授权。
- OAuth 请求附带 X-Client-Time / X-Client-Hash。客户端标识是公开 App 协议常量，不是用户账号凭据。
- 续期提前 60 秒触发，同一轮并发请求共享一次续期；API 401 时只重试一次。
- 取消登录会废弃授权会话，并防止在途安全存储写入重新恢复已经取消的会话。

真实账号已在鸿蒙真机完成网页授权、授权回调、令牌交换和安全存储，登录后个性化推荐正常加载。真实令牌过期后的续期及云端写操作尚待实测；测试套件用合成令牌覆盖这些代码路径。

## 游客公开接口

主机：`https://www.pixiv.net`。不附带账号 Cookie 或 Token。

| 功能 | 路径 |
| --- | --- |
| 排行榜 | `/ranking.php?format=json&mode=daily&content=illust&p=1` |
| 搜索 | `/ajax/search/artworks/{word}?word=...&mode=safe&p=1&s_mode=s_tag&type=all&order=date_d&lang=zh` |
| 详情 | `/ajax/illust/{id}?lang=zh` |
| 图片分页 | `/ajax/illust/{id}/pages` |
| 画师资料 | `/ajax/user/{id}?full=1&lang=zh` |
| 画师作品 ID | `/ajax/user/{id}/profile/all` |
| 画师作品元数据 | `/ajax/user/{id}/profile/illusts?ids[]=...&work_category=illustManga&is_first_page=0&lang=zh` |
| 小说榜单 | `/ajax/ranking/novel?mode=daily&content=novel&p=1&lang=zh` |
| 小说搜索 | `/ajax/search/novels/{word}?word=...&order=date_d&mode=safe&p=1&s_mode=s_tag&lang=zh` |
| 小说详情与正文 | `/ajax/novel/{id}?lang=zh` |
| 插画 / 漫画评论 | `/ajax/illusts/comments/roots?illust_id=...&offset=0&limit=20&lang=zh` |
| 小说评论 | `/ajax/novels/comments/roots?novel_id=...&offset=0&limit=20&lang=zh` |
| 评论回复 | `/ajax/{illusts\|novels}/comments/replies?comment_id=...&page=1&lang=zh` |

公开接口已执行只读请求验证。旧的 `/v1/illust/recommended-nologin` 在本次验证中返回端点不存在，因此游客首页明确展示「来自 Pixiv 公开排行榜」，没有把公开榜单冒充个性化推荐。

图片只接受 `pximg.net` 域名，附带 `Referer: https://www.pixiv.net/`。不将登录令牌发送给图片 CDN。

## 小说与评论

游客小说精选使用公开日榜，小说榜单只提供日榜、周榜和新人榜。公开搜索依赖 `body.novel.lastPage` 判断分页，不假定每页条数。小说正文解析章节、换页、注音和插图；普通文本中的尖括号原样保留，长正文分块渲染。系列跳转仅使用服务端标记为可访问的相邻作品。沿用作品列表的受限内容过滤规则。

App 正文接口返回 HTML，只提取 `novel: {...}` 内的 JSON 对象，不执行脚本。该路径有独立白名单，并复用一次 401 续期；不把任意 WebView URL 作为带令牌的请求目标。系列相邻项是 `seriesNavigation.prevNovel / nextNovel`，插图来自 `images` 和 `illusts`。协议字段参考 [PixivPy](https://github.com/upbit/pixivpy/blob/master/pixivpy3/aapi.py) 与 [PixEz 的正文模型](https://github.com/Notsfsssf/pixez-flutter/blob/master/lib/models/novel_web_response.dart)。

公开根评论用 `offset / limit`，回复用从 1 开始的 `page`，均以 `hasNext` 判断后续页。某些回复会返回 `error: true, body: []`，此时保留重试并引导登录，不显示为「暂无回复」。表情贴图位于 `s.pximg.net/common/images/stamp/generated-stamps/{stampId}_s.jpg`。这些公开路径已实际只读验证；新增的 App 小说 / 评论接口和鉴权由合成数据测试覆盖，尚未用真实账号验证。评论功能不调用发表或删除接口。

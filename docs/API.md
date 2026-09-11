# Pixiv 接口接入说明

核对日期：2026-09-11。Android 参考版本：6.195.0（versionCode 68093）。安装包中已确认 App API 域名、客户端标识与下列接口路径。

## 登录后的 App API

主机：`https://app-api.pixiv.net`。

| 功能 | 方法与路径 |
| --- | --- |
| 插画推荐 | GET `/v1/illust/recommended?filter=for_android` |
| 漫画推荐 | GET `/v1/manga/recommended?filter=for_android` |
| 排行榜 | GET `/v1/illust/ranking?filter=for_android&mode=day` |
| 搜索 | GET `/v1/search/illust?filter=for_android&word=...&search_target=partial_match_for_tags&sort=date_desc` |
| 作品详情 | GET `/v1/illust/detail?filter=for_android&illust_id=...` |
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

公开接口已执行只读请求验证。旧的 `/v1/illust/recommended-nologin` 在本次验证中返回端点不存在，因此游客首页明确展示「来自 Pixiv 公开排行榜」，没有把公开榜单冒充个性化推荐。

图片只接受 `pximg.net` 域名，附带 `Referer: https://www.pixiv.net/`。不将登录令牌发送给图片 CDN。

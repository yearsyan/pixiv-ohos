# Pixiv for HarmonyOS

基于 ArkTS / ArkUI 的独立鸿蒙原生 Pixiv 客户端。直接请求 Pixiv 接口，使用真实作品数据；UI 独立设计，支持手机瀑布流和平板侧栏布局。

## 当前功能

| 功能 | 游客 | 登录 Pixiv 后 |
| --- | --- | --- |
| 插画、漫画浏览 | 公开榜单精选 | 个性化推荐 |
| 日榜、周榜、月榜、新人榜 | 支持；漫画使用日榜 | 支持 |
| 搜索、标签跳转、最新/最早排序 | 支持 | 支持 |
| 作品详情原图显示、多图翻页、全屏缩放 | 公开作品 | 账号可访问的作品 |
| 插画、漫画、小说评论及回复 | 公开评论，受限回复引导登录 | 已接入评论 / 回复 App API |
| 小说精选、日榜 / 周榜 / 新人榜、搜索 | 公开榜单及搜索 | 推荐、榜单及搜索 App API |
| 小说阅读 | 公开正文 | 账号可访问的正文 |
| 作品相关推荐 | 插画 / 漫画 / 小说相关推荐及分页 | App API 相关推荐及分页 |
| 小说目录 | 本篇分页、公开系列章节及跳转 | 本篇分页、系列章节及分页 |
| 原图保存到相册 | 支持，系统授权保存 | 支持，系统授权保存 |
| 画师主页、画师作品分页 | 支持 | 支持 |
| 本地收藏、浏览记录、搜索历史 | 支持，保存在设备 | 支持，独立于云端收藏 |
| 关注画师、关注动态 | 引导登录 | 已接入 App API |
| Pixiv 公开收藏、取消收藏 | 引导登录 | 已接入 App API |
| 登录 | 官方网页 PKCE 登录 / 自有 Refresh Token | 自动续期与一次 401 重试 |

在首页或搜索结果中选择「小说」进入小说列表。阅读页支持章节、分页、字号调整、日间 / 夜间模式、可用插图，以及系列上一篇 / 下一篇；当前运行期间会保留阅读页码和阅读设置。「目录」列出本篇分页和系列其他章节，标记当前阅读项，点击可直接切换；不可访问的章节保留提示。简介可以展开，复杂跳转和缺失插图可通过「原站」查看。

插画 / 漫画详情底部展示「你可能还喜欢」，点击进入推荐作品。小说阅读页的「推荐」标签和正文最后一页也展示相关推荐，支持加载更多。

插画 / 漫画详情的「查看评论和回复」、小说阅读页的「查看评论」进入评论列表；有回复的评论显示「查看回复」。支持文字、表情贴图、分页和重试，目前只提供查看功能。

## 构建与安装

当前工程使用 HarmonyOS SDK 26，兼容 API 24，设备类型为 phone / tablet。首次检出后，复制无签名信息的配置模板，再用 DevEco Studio 打开工程并同步 OHPM 依赖：

```sh
cp build-profile.example.json5 build-profile.json5
```

本机 `build-profile.json5` 可能包含签名密码和证书路径，因此不纳入版本控制；模块级 `entry/build-profile.json5` 正常提交。当前电脑原有的签名配置保留在本地。在其他电脑上需要通过 DevEco Studio 的 Signing Configs 配置自己的签名，才能安装到真机。

```sh
./scripts/build.sh
```

脚本默认使用 `/Applications/DevEco-Studio.app/Contents`，可以通过 `DEVECO_ROOT` 指定其他安装目录。缺少本地构建配置时会自动从模板创建，不覆盖已有配置；未配置签名时只生成未签名包。

配置签名后的产物：`entry/build/default/outputs/default/entry-default-signed.hap`。

```sh
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
"$HDC" -t <鸿蒙设备ID> install entry/build/default/outputs/default/entry-default-signed.hap
"$HDC" -t <鸿蒙设备ID> shell aa start -a EntryAbility -b dev.app.pixivohos
```

## GitHub Actions 发布构建

推送以 `v` 开头的版本 tag（例如 `v1.0.0`）会触发 `.github/workflows/release-hap.yml`，以 `release` 模式构建未签名 HAP，并自动发布到对应的 GitHub Release：

```sh
git tag v1.0.0
git push origin v1.0.0
```

打 tag 前需先提交工作流，确保 tag 指向包含工作流的提交。也可以在 GitHub 的 **Actions → Build unsigned release HAP → Run workflow** 手动触发：填写 `tag` 时会检出该已有 tag 的代码并发布 Release，可用于补发旧版本；留空时只构建所选分支或 tag，分支构建仅上传 Artifacts。

工作流使用 Ubuntu 24.04，通过 [ErBWs/setup-ohos](https://github.com/ErBWs/setup-ohos) 安装固定版本 `26.0.0.821` 的 HarmonyOS Command Line Tools（含 SDK 26），从 `build-profile.example.json5` 创建无签名配置并安装 OHPM 依赖，无需配置签名 Secrets。

构建完成后，可在 [GitHub Releases](https://github.com/yearsyan/pixiv-ohos/releases) 下载 `entry-default-unsigned.hap` 和 `entry-default-unsigned.hap.sha256`。已有 Release 会更新同名附件；含 `-` 的版本 tag（例如 `v1.1.0-beta.1`）在首次发布时会标记为预发布。发布任务使用 GitHub 自动提供的 `GITHUB_TOKEN`，仅该任务授予 `contents: write` 权限。

Actions 运行页面仍保留 `pixiv-ohos-unsigned-<运行编号>` Artifacts，保存 30 天。Actions 显示的 SHA-256 对应整个 ZIP，`.hap.sha256` 对应解压后的 HAP，可在两个附件所在目录执行以下命令校验：

```sh
shasum -a 256 -c entry-default-unsigned.hap.sha256
```

未签名 HAP 需要自行签名后才能安装到真机。

## 验证

```sh
# 协议、鉴权竞争条件和本地存储测试；全部使用合成登录数据
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --test scripts/test.cjs scripts/test-viewer.cjs

# 只读探测 Pixiv 的公开接口；不下载图片，不读取账号
python3 scripts/probe-api.py

# 只验证小说与评论新增接口
python3 scripts/probe-api.py --reading-only

# 只验证相关推荐与系列目录
python3 scripts/probe-api.py --related-only
```

小说和评论已用公开接口与鸿蒙真机游客模式验证；新增的登录接口、正文 WebView 数据解析及 401 续期由合成数据测试覆盖，尚未用真实账号验证。
相关推荐与目录已通过公开接口、合成数据测试和构建验证；该增量尚待真机复查。

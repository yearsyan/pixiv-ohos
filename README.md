# Pixiv for HarmonyOS

基于 ArkTS / ArkUI 的独立鸿蒙原生 Pixiv 客户端。直接请求 Pixiv 接口，使用真实作品数据；UI 独立设计，支持手机瀑布流和平板侧栏布局。

## 当前功能

| 功能 | 游客 | 登录 Pixiv 后 |
| --- | --- | --- |
| 插画、漫画浏览 | 公开榜单精选 | 个性化推荐 |
| 日榜、周榜、月榜、新人榜 | 支持；漫画使用日榜 | 支持 |
| 搜索、标签跳转、最新/最早排序 | 支持 | 支持 |
| 作品详情原图显示、多图翻页、全屏缩放 | 公开作品 | 账号可访问的作品 |
| 原图保存到相册 | 支持，系统授权保存 | 支持，系统授权保存 |
| 画师主页、画师作品分页 | 支持 | 支持 |
| 本地收藏、浏览记录、搜索历史 | 支持，保存在设备 | 支持，独立于云端收藏 |
| 关注画师、关注动态 | 引导登录 | 已接入 App API |
| Pixiv 公开收藏、取消收藏 | 引导登录 | 已接入 App API |
| 登录 | 官方网页 PKCE 登录 / 自有 Refresh Token | 自动续期与一次 401 重试 |

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

## 验证

```sh
# 协议、鉴权竞争条件和本地存储测试；全部使用合成登录数据
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --test scripts/test.cjs scripts/test-viewer.cjs

# 只读探测 Pixiv 的公开接口；不下载图片，不读取账号
python3 scripts/probe-api.py
```

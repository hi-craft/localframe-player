# Vela Player 跨电脑接续记录

更新日期：2026-10-29，Asia/Hong_Kong。

## 先看当前状态

- 私有仓库：[hi-craft/localframe-player](https://github.com/hi-craft/localframe-player)，使用 `main` 分支。应用名是 **Vela Player**，工程名仍为 LocalFrame。
- 最新可安装产物是 **0.2.0 / build 3**，文件名 `VelaPlayer-0.2.0.ipa`，需要 SideStore 签名后安装。
- **新包已经通过 USB 传入 iPhone 的 `SideStore/Documents/VelaPlayer-0.2.0.ipa`，并核对文件大小。用户尚未确认 0.2.0 已安装，也尚未确认新版交互修复通过。**
- 下一步先在手机 SideStore → My Apps → `+` → 浏览 → 我的 iPhone → SideStore 中选择这个新包更新，再收集真机反馈。手机已经有包，做这一步不需要重新构建。
- 代码构建提交：`585ebf5985a3011b889d7eb0fc666dcc7951d07f`。`main` 还包含后续说明文档更新，接续时拉取最新 `main`。
- [本版成功构建](https://github.com/hi-craft/localframe-player/actions/runs/40738060248)：ARM64 Release IPA 构建成功，**9 项 Core 测试通过，零失败**。按用户要求跳过模拟器和本轮原生播放测试。
- IPA 大小：50,961,436 字节。SHA-256：`39ef7e145ad6337bc13fcb7624829b3c6bd30dc7ea9ac10520cb6b25bdabab64`。

## 已确认的需求与偏好

- 设备：iPhone 15 Pro Max、iPad Air M1。按最新系统考虑；工程最低 iOS / iPadOS 17。
- 用户使用 Windows，没有付费 Apple 开发者账号。接受 GitHub 云端构建，选择免费 SideStore 安装与续签，不要求上架。
- 使用系统文件夹选择器添加多个“我的 iPhone / iPad”或外接存储目录，递归扫描所有子目录，合并展示。约 500～1000 个视频，单文件约 300 MB～1 GB，常见格式即可。
- App 只播放获授权目录内的本地文件；不复制或缓存视频，不主动联网。允许目录书签、轻量文件索引和少量首帧缩略图缓存。
- 封面严格使用首个解码帧，黑场首帧可以是黑色。磁盘缩略图预算 64 MB，内存图片缓存约 8 MB，串行按需解码并取消离屏请求。
- 不保存观看历史、播放进度。支持自动下一集，最后一集结束停止。字幕关闭、使用默认音轨，无字幕和音轨切换界面。
- 播控包括倍速、进度拖动、双指捏合 1～4 倍、放大后双指平移、左右滑动定位、左侧上下亮度、右侧上下音量、单击显隐控制和双击暂停/继续。
- 切后台、锁屏、音频中断、耳机拔出时暂停，返回前台手动恢复。外接盘断开时停止并保留索引，重连刷新或重新授权后手动播放。
- 设计参考 Infuse 的深色媒体库与封面卡片；首页三列书本比例封面，上方封面、下方缩略标题，点击视频进入二级播放页。
- **排序的最终约定：保留实际扫描读取顺序，不按名称或日期做二次排序。** 这覆盖先前“跟随文件 App / 日期最新在前”的讨论。文件系统枚举顺序没有稳定性保证，也不等于系统“文件”App 的界面排序。
- **用户优先速度，明确表示不需要模拟器验证。后续默认运行 Core 检查和设备打包，跳过模拟器；需要改变这个安排时先说明原因。**

## 版本与待验收问题

0.1.1 已在 iPhone 安装，用户实际播放过视频，并报告：主页不好看、顺序不符、画面中加载圈常驻、全屏无反应、单击画面不显示浮层。

0.2.0 已做以下修改，但交互效果仍待用户真机确认：

1. 首页改为三列 2:3 首帧封面流，标题最多两行；点击后进入独立播放页。
2. 保留扫描返回顺序与根目录扫描顺序；部分 I/O 失败时保留未确认的旧索引。
3. 使用实际播放时钟前进判断播放活动，清除过期缓冲状态；延迟显示加载提示。
4. 全屏按钮直接切换布局，同时请求系统旋转；旋转被拒绝时布局仍能扩展。
5. 将原生视频视图和 SwiftUI 控制层放在同一 UIKit 触控容器。以真实控件视图范围排除按钮和滑块触摸，避免浮层空白阻挡画面手势。

真机首先检查：首页三列与首帧、点击进入/返回、加载圈是否消失、单击浮层、按钮与拖动进度、全屏进入/退出、播放列表同步、旋转时播放是否连续。

500～1000 文件性能、iPad、系统音量、外接盘拔插、4K / HDR 尚未完成验收。

改名前的 [完整验证基线](https://github.com/hi-craft/localframe-player/actions/runs/40723131697) 对应 `4836c32a7c01ddfb5ecaa071d1f570224be1f2a9`，7 项 Core 测试和 4 项原生播放测试通过，iPhone / iPad 模拟器独立启动成功。这不能当作 0.2.0 界面测试结果。该基线出现 MobileVLCKit `VLCOpenGLES2VideoView` 后台线程图层修改诊断；详见 [VALIDATION.md](VALIDATION.md)。

## 在另一台电脑继续

1. 登录具有该私有仓库权限的 GitHub 账号。旧电脑的登录态和本地路径不会随着仓库同步。
2. 克隆仓库并切到 `main`，阅读本文件、[README.md](README.md)、[INSTALL-Windows.md](INSTALL-Windows.md) 和 [VALIDATION.md](VALIDATION.md)。
3. 先确认手机是否已经更新到 0.2.0，再根据真实反馈继续修复。不要把“已传入安装包”当作“新版已验收”。
4. 如需在新电脑连接手机，按 [SideStore 官方前置安装说明](https://docs.sidestore.io/docs/installation/prerequisites) 准备 Apple USB 驱动和 iloader，USB 连接、解锁并在手机确认信任。现有 SideStore 和 LocalDevVPN 的配置留在手机上；换电脑本身不要求重装它们。
5. GitHub CLI、Git、代理和文件传输工具按新电脑实际环境配置。旧电脑 `work/` 下的临时工具不属于仓库，也不应作为新电脑的路径前提。

克隆与下载现有安装包（已安装 Git / GitHub CLI 后，在终端执行）：

```sh
gh auth login
gh repo clone hi-craft/localframe-player
cd localframe-player
git switch main
git pull --ff-only
gh run download 40738060248 --name LocalFrame-unsigned-ipa --dir downloads
```

下载产物解压后内部仍叫 `LocalFrame-unsigned.ipa`，就是本次 Vela Player 0.2.0，可改名为 `VelaPlayer-0.2.0.ipa`。Artifacts 配置保留 14 天；明天可直接使用上述成功构建，不必为换电脑重新编译。

以后只打包、不跑模拟器：

```sh
gh workflow run ios.yml --ref main -f build_only=true
gh run list --workflow ios.yml --limit 5
```

也可在 GitHub Actions → Build iOS → Run workflow 勾选 `build_only`。**普通 push 到 main 仍会触发完整验证流程**；采用快速流程时，可用带 `[skip ci]` 的提交推送，再手动运行上述命令，避免重复构建。`build_only=true` 当前仍运行 Core 测试。

## 安装过程已解决的阻塞

以下记录用于同类错误复现时排查，不需要在正常状态下重做：

- Apple 登录 `-80045`：用户按社区临时方案调整 Anisette 后登录成功。步骤包括关闭设备端 Anisette、选 SideStore (New)、关闭自动轮换、获取远程配置并保存覆盖、重置 adi.pb 后重启 SideStore。参见 [问题 #1688](https://github.com/SideStore/SideStore/issues/1688)。服务器可用性会变化，方案不是通用保证。
- 无法确定设备 UDID：通过 iloader 重新生成并放入 SideStore 的配对文件。手机重置信息、电脑清除旧配对及信任确认由用户操作。参见 [官方配对说明](https://docs.sidestore.io/docs/advanced/pairing-file)。
- `Repository could not save notification. Source is not authorized.`：在 iPhone 设置 → 通知 → SideStore 中允许通知，重开后刷新。参见 [问题 #1421](https://github.com/SideStore/SideStore/issues/1421)。
- `appIdName` 拒绝“本地映像”：已将 `CFBundleDisplayName` 和 `CFBundleName` 改为英文 `Vela Player`。不要重新填中文注册名称。参见 [问题 #1489](https://github.com/SideStore/SideStore/issues/1489)。
- 手机需要 Wi-Fi 与 LocalDevVPN 连接，才能用 SideStore 进行安装和刷新。LocalDevVPN 是手机本地通道，没有国家或远程 VPN 服务器可选。免费签名仍有约 7 天周期。

账号登录、二次验证、手机信任和系统权限由用户本人完成。旧电脑的凭据和设备配对缓存未放入仓库或交接包；需要新电脑配对时遵循官方流程。

## 代码位置与构建约束

| 位置 | 用途 |
|---|---|
| `App/Views/LibraryView.swift` | 三列封面首页、独立 PlaybackScreen、播放列表与全屏布局 |
| `App/Views/PlayerPanel.swift` | 播控浮层、4 秒自动隐藏、进度条和按钮 |
| `App/Playback/VideoSurface.swift` | 原生画面、UIHostingController 控制层、共同手势容器和控件触摸范围 |
| `App/Playback/PlayerController.swift` | 加载/播放状态、缓冲提示、生命周期、队列和存储可用性 |
| `Core/Sources/LocalLibraryCore/LibraryModels.swift` | LibraryReadOrder、PlaybackActivity、路径规则和播放队列 |
| `App/Services/LibraryStore.swift` | 索引恢复、扫描结果合并和目录状态 |
| `Core/Tests/LocalLibraryCoreTests/LibraryTests.swift` | 当前 9 项 Core 回归检查 |
| `.github/workflows/ios.yml` | Core 测试、设备打包及可选模拟器步骤 |

技术基线：SwiftUI / UIKit、Objective-C 播放桥、MobileVLCKit 3.7.4、XcodeGen、Xcode 26.3 / iOS SDK 26.2、`macos-15-intel` 云端构建机。设备产物始终是 ARM64。

播放器采用固定官方 XCFramework 下载与 SHA-256 校验，见 `scripts/fetch-playback-framework.sh`。已移除 CocoaPods 解析；动态 `MobileVLCKit.framework` 必须 `embed: true`。固定依赖和嵌入规则与此前实际编译/启动问题相关，修改时需验证产物内容。

应用 Bundle ID 为 `com.localframe.player`，PRODUCT_NAME 为 LocalFrame；英文桌面名为 Vela Player。既有书签和索引目录继续使用 LocalFrame 路径。接续开发时沿用这些内部标识，方便通过 SideStore 更新同一个应用。

## 可直接发给新会话的接续提示

> 继续开发我的 iOS 本地视频播放器 Vela Player。私有 GitHub 仓库是 hi-craft/localframe-player，请先读取 main 分支的 HANDOFF.md、README.md 和 VALIDATION.md，遵循最新需求。0.2.0 安装包已传入 iPhone 的 SideStore 文件夹，但我还没确认新版安装和真机验收。先确认最新反馈，再继续处理首页、加载圈、全屏和浮层问题。排序保留扫描读取顺序，设计参考 Infuse；构建优先快速流程，运行 Core 测试并生成设备 IPA，跳过模拟器。需要操作手机或登录账号时让我本人完成。

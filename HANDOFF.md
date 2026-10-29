# Vela Player 开发接续记录

更新日期：2026-10-29，Asia/Shanghai。

## 当前状态

- 私有 GitHub 仓库：[hi-craft/localframe-player](https://github.com/hi-craft/localframe-player)。应用名 Vela Player，工程名 LocalFrame。
- 用户确认 iPhone 已安装 **0.2.0 / build 3**；实际反馈为单击无法唤起操作区、退出全屏后方向未恢复。不要再询问是否已安装该版本。
- 用户现使用 MacBook，已明确要求本地模拟器验证，覆盖此前“跳过模拟器”的偏好。
- 当前开发版 **0.2.1 / build 12**，基于 `79d8d3cf61aa3f234cf218faa3e01cfa8865d382`；用户明确授权开发分支 **`fix/vela-controls-library`**，并要求提交代码及上传产物。代码以本分支提交为准，安装包、校验文件和验证资料对应 Release 标签 `v0.2.1-build12`；实际验证结果见 [VALIDATION.md](VALIDATION.md)。
- 已在手机 Vela Player 的 Documents 中构造 `Vela测试视频_三层_20261029`：15 个内容不同、每个约 15 秒的视频，三级目录、各层不同数量，包含横屏和竖屏；已核对手机回读散列。该素材不放进仓库或安装包。
- build 12 IPA 已传到手机 Vela Player 的 Documents，手机回读与原包大小和 SHA-256 一致；传输前实际观察到已安装版本为 **0.2.1 / build 11**。build 12 仍需 SideStore 签名后安装，文件传输不代表已更新或真机验收完成。设备标识与配对资料不进入仓库或发布附件。

## 本轮需求与实现范围

1. 隐藏浮层后单击画面重新唤起，双击暂停/继续；按钮、进度条与画面手势互不抢触摸。
2. iPhone 全屏进入横屏，退出全屏回竖屏；返回资料库时重申竖屏方向。iPad 保持自由旋转，复用原播放会话。
3. 首页按多个根文件夹提供横向片架，文件夹页集中显示目录状态和数量；逐层进入子文件夹、本层网格、全局搜索及目录内递归搜索。
4. 不可读根目录保留视频索引和已缓存封面，显示离线提示、刷新和重新授权入口。部分扫描失败保留未确认的旧索引并标记部分可读。用户已确认上述处理符合预期。
5. 参考 [Infuse](https://firecore.com/infuse) 的深色资料库、目录卡片和封面横架，保留本项目离线、不记录历史的约束。
6. build 5：手机播放布局由实际窗口宽高决定，移除全屏标记切换时的独立布局动画；关闭播放页先完成竖屏旋转，再关闭浮层；已是目标方向时不重复请求旋转。iPhone 连续三次退出全屏、单击播控以及 iPad 旋转专项回归通过，并录屏检查两个返回入口。用户决定暂不安装 Infuse，先修复闪动。
7. build 6：播放列表左侧由占位序号改为 112×63 点首帧缩略图，复用原串行解码、缓存和离屏取消；当前播放项保留强调色与波形标记，点击缩略图也能切换视频。
8. build 6：首页和文件夹页加入目录读取进度。递归总量未知时显示活动条与真实已检查/已发现数量，不伪造百分比；完成后显示目录完成数量及离线保留情况。
9. build 6：下拉刷新会取消正在进行的旧扫描，以新的代次扫描所有已添加根目录。完整可读的根目录从空索引构建并原子替换，删除和空目录都能反映到资料库；离线/部分不可读时保留旧索引。只改索引，不删除视频。旧扫描回调不能覆盖新扫描结果。

10. build 7：增加前进/后退 10 秒（首尾截断且保留暂停状态）、锁定播放控制（屏蔽画面手势和列表）、15/30/60 分钟定时暂停（包含暂停/切集，关闭播放页取消），以及可复制相对路径的视频信息。播放页右上角“更多”进入选项，长按封面或列表也能查看信息。到时暂停后解锁，可手动继续；切后台自动解锁并按既有规则暂停。

11. build 8：用户要求 Netflix 质感的主界面与整体配色。采用深黑背景、白字与 #E50914 红色，四个 Tab 为首页、分类、文件夹、设置；首页首帧大封面与分区横架，分类按全部/可播放/离线索引/500 MB 大文件/格式组织。首页大封面按需读取最高 960×540 的首帧，列表仍为最高 320×180，缓存键分开且预算不变。每个 Tab 保留自己的目录或分类导航位置；文件夹管理与缓存/帮助/版本设置分开。仍保持本地文件、真实首帧、原始读取顺序和既有播放/旋转规则。
本轮 build 8 本地回归最终汇总：Core 10 项通过；iPhone / iPad 各 10 项原生、12 项界面通过，1 项按设备跳过。大封面与新增 Tab / 分类专项复测后零未解决失败；原始失败日志保留。两台模拟器恢复各 15 条三级测试素材。详情见 [VALIDATION.md](VALIDATION.md)。

12. build 9：用户反馈首页仍不够像 Netflix，进一步重做首页构图。首帧大图铺满宽度、延伸至状态栏后方，渐变融入黑底；手机标题居中、平板左对齐，播放和信息叠加在画面下方。顶部提供全部 / 可播放 / 文件夹入口，搜索改为点击展开并可取消恢复首页；常驻的目录完成提示移至文件夹页，首页仅扫描中显示进度。首排竖版海报，目录用横版片架，标题叠加图内，去掉底部 Tab 的红色指示线。仍然使用真实首帧及原始读取顺序。本轮 iPhone / iPad 各 13 项界面通过、1 项设备专用检查跳过，零失败；原生及 Core 沿用 build 8 已通过基线，未重跑。测试样本仅在 Debug 加自动化参数时重建，避免混入普通启动的演示视频。

13. build 10：用户认可首页，要求全应用及播放器继续对标 Netflix。保留首页构图，统一深黑 / 白色操作 / 红色重点、较小圆角与扁平面板。播放器中央保留播放 / 前后 10 秒，上一部、倍速、锁定、选集和下一部放到底部，右上角提供缩小；进度条使用保留 UIKit 滑块辅助功能的细轨和小红圆点，触摸区域 44 点。倍速采用独立面板，定时暂停、视频信息、文件夹管理与设置统一样式；列表缩略图改为 120×68 点，当前项白字、波形标记。分类和目录卡片复用真实首帧；设置将长操作说明集中到手势指南。宽度较小时收紧全屏操作间距；锁定后解锁入口遵守屏幕安全区域。 本轮 Core 10 项通过，iPhone / iPad 各 10 项原生、15 项界面通过，1 项设备专用检查跳过；按完整回归及修正后复测的逐项最终结果汇总，零未解决失败。初始失败保留，详细结果及包校验见 VALIDATION.md。

14. build 11：进度条支持任意位置点按跳转；按住或拖动预览真实帧与时间，松手提交定位，保持原播放 / 暂停状态；触控取消不定位。iPad 鼠标 / 触控板悬停只预览。预览使用独立无音频解码实例，半秒缓存、90ms 合并、单解码 + 最新待处理请求；离开、切集、锁定、弹出面板和后台取消，失败仅显示占位图与时间，不影响播放。本轮 iPhone / iPad 各 13 项原生、5 项界面专项通过，完整资料库及 Core 沿用 build 10 基线；真实指针硬件仍待验证。

15. build 12：将底部 Tab 与导航内容显式纵向分开；顶部安全区扩展移至实际测量容器，保留外层状态栏边距，首页最后一排可完整滚到 Tab 上方。全屏侧栏封面 88×49.5 点，竖屏保持 120×67.5 点，文字优先且目录说明最多两行，侧栏保留显示切口与底部安全区。手指落下时记录起点，全屏画面右侧 64 点区域左滑超过 55 点呼出列表，列表上右滑收起；方向与画面定位分开，锁定停用。列表以可取消的点按激活，避免收起时误选行并恢复播放；保留辅助功能按钮动作。iPhone 13 项原生 + 10 项界面、iPad 13 项原生 + 11 项界面（含平板旋转）通过；Core / 完整资料库基线沿用 build 10，进度预览基线 build 11。

## 必须保留的产品约定

- 面向 iPhone 15 Pro Max、iPad Air M1，最低 iOS / iPadOS 17。
- 只访问用户选择的本机或外接根目录，递归扫描。视频不复制、不缓存；只保存书签、轻量索引和缩略图。
- 首帧必须是第一个解码帧，黑色也正常；不跳到中段取图。内存缩略图约 8 MB、磁盘 64 MB LRU；串行解码并取消离屏请求。
- 保留扫描实际读取顺序，不按名称或日期再次排序；不承诺与系统“文件”App 的显示顺序相同。
- 不保存观看历史或播放进度。点击时捕获队列：首页为该根目录全部视频，文件夹页为本层视频，搜索为当前搜索结果。自动下一集，最后一集停止；损坏或不可读文件停止且不跳过。
- 0.5～3 倍速、进度拖动、单/双击、左右定位、左右侧上下亮度/音量、双指 1～4 倍捏合及放大后平移。字幕关闭、默认音轨，不增加字幕/音轨选择。
- 切后台、锁屏、音频中断、拔耳机暂停，前台需手动继续；外接盘断开保留索引，重连后刷新/授权再手动播放。
- 保留 `com.localframe.player`、PRODUCT_NAME LocalFrame，以及 Application Support / Caches 中既有 LocalFrame 路径，方便 SideStore 原应用更新。

## Git 安全与接续

- 严禁把其他本地项目或无关代码上传 GitHub；既有 GitHub 仓库内的本项目修改属于用户允许范围。
- 多会话开发必须使用独立 worktree。新 worktree 只能放在实际挂载的 `/Volumes/DevWorkspace/workspace/localframe-player_worktrees/`，不能回退到本机磁盘。
- 创建/切换分支需用户明确授权；本轮只授权 `fix/vela-controls-library`。编辑前核对仓库根目录、当前分支和状态，不覆盖已有改动。
- 用户说“提交”表示 add、commit 和 push；提交前核对分支与本次文件，检查暂存差异。推送显式使用 `git push origin HEAD:<当前分支>`，严禁强推。
- 没有收到提交指令时保留本地变更，在回复中说明未提交文件。

## 本地开发与验证

```sh
brew install xcodegen ffmpeg
bash scripts/fetch-playback-framework.sh
bash scripts/generate-test-media.sh
xcodegen generate
swift test --package-path Core
xcrun simctl list devices available
xcodebuild test -project LocalFrame.xcodeproj -scheme LocalFrame \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath build/simulator -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=''
bash scripts/build-unsigned.sh
```

模拟器名称按实际安装列表调整。UI 测试在 Debug 启动参数 `-ui-testing` 下准备自己的三级目录及离线索引，会改写所选测试模拟器 App 的索引；普通启动不执行该逻辑。生成的测试视频忽略跟踪，Release 排除 UI 测试素材。

本机本轮环境为 Xcode 26.0 / iOS SDK 26.0、iOS 26.0.1 模拟器。云端工作流沿用 Xcode 26.3 配置；本机结果不能替代一次新的云端运行。未验证的真机项目继续保留在 [VALIDATION.md](VALIDATION.md)。

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
| `App/Views/LibraryView.swift` | 四个 Tab 外壳、首页、分类、文件夹层级、搜索和离线提示 |
| `App/Views/LibraryNavigation.swift`、`FeaturedVideoCard.swift` | Tab 导航、文件分类与首帧大封面 |
| `App/Views/SettingsView.swift`、`FolderManager.swift` | 缓存/帮助/许可设置，以及独立的文件夹管理 |
| `App/Views/PlaybackScreen.swift` | 独立播放页、全屏布局与播放列表 |
| `App/Views/PlayerPanel.swift`、`PlaybackTimeline.swift` | 播控、自动隐藏、前后 10 秒、锁定和细轨进度条 |
| `App/Views/CinemaComponents.swift` | 统一面板、操作行、按钮及目录 / 分类首帧背景 |
| `App/Views/PlaybackOptionsView.swift`、`VideoInfoView.swift` | 锁定、定时暂停、视频信息和路径复制 |
| `App/Playback/VideoSurface.swift` | 原生画面、透明手势层和 SwiftUI 控件坐标排除 |
| `App/Playback/OrientationPolicy.swift` | iPhone 资料库/播放页方向策略与 AppDelegate |
| `App/Playback/PlaybackPresentationCoordinator.swift` | 等待窗口旋转完成后关闭播放页，避免旋转与关闭同时过渡 |
| `App/Services/LibraryStore.swift` | 索引恢复、扫描合并、离线/部分可读状态、重新授权 |
| `App/Views/LibraryReadingProgressView.swift` | 目录读取活动条、真实计数、完成和离线保留提示 |
| `Core/Sources/LocalLibraryCore/DirectoryScanner.swift` | 递归读取元数据与节流的实时进度回调 |
| `Core/Sources/LocalLibraryCore/FolderListing.swift` | 从索引派生本层视频与子文件夹，保留读取顺序 |
| `Tests/`、`UITests/` | 原生播放、离线恢复及实际界面回归 |
| `.github/workflows/ios.yml` | Core、设备包和可选模拟器检查 |

播放内核固定为 MobileVLCKit 3.7.4，官方 XCFramework 下载及 SHA-256 校验见 `scripts/fetch-playback-framework.sh`；必须 `embed: true`。设备产物是 ARM64，无签名包仍需用户签名后安装。

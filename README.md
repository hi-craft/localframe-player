# Vela Player

跨电脑接续请先阅读 [HANDOFF.md](HANDOFF.md)，其中记录最新需求、0.2.1 开发状态、验证结果和接续方法。

为 iPhone 15 Pro Max 和 iPad Air M1 设计的本地视频播放器。SwiftUI / UIKit 界面，MobileVLCKit 3.7.4 播放内核。最低 iOS / iPadOS 17；云端使用 macOS 15 构建机上的 Xcode 26.3。

应用名称为 Vela Player，工程与仓库目录沿用 LocalFrame。0.1.1 将桌面名称和签名注册名称统一为英文，修正 SideStore 注册中文 appIdName 时安装失败的问题；操作界面保留中文。

## 已实现的首版范围

- 系统目录选择器，支持多个本地或外接根目录，递归扫描并按根目录分区；逐层进入子文件夹，也可跨目录或在当前目录内递归搜索。保留实际扫描读取顺序。
- 播放列表左侧使用视频首个解码帧，缩略图为 120×68 点，标记当前播放项；资料库封面复用相同缓存；首页大封面单独生成最高 960×540 像素的首帧，列表保持最高 320×180，仍共用缓存预算。一个封面解码任务同时运行，滚出屏幕时取消。内存图片缓存约 8 MB，磁盘 JPEG 封面缓存预算 64 MB，按最近使用顺序淘汰。
- 首页扫描时显示读取进度，完整读取进度、目录计数和完成状态集中在文件夹页。下拉刷新取消旧扫描并重新读取全部根目录；完整可读目录清空旧索引后以本次结果替换，离线或部分不可读目录保留未确认的旧索引，不改动源文件。
- 重启优先恢复已保存的索引，只检查根目录授权和可读性；回到前台也不递归重扫。首次添加或尚无完整索引的目录自动扫描，后续文件增删通过下拉刷新更新。成功扫描过的空目录也会记住完成状态。
- 采用影院风格的深黑、白字和红色强调色，首页以首帧大封面和分区横向片架展示收藏；底部提供首页、分类、文件夹、设置四个入口，切换时保留各自的文件夹或分类位置。分类支持全部、可播放、离线索引、500 MB 及以上大文件及文件格式；按本地文件信息归类。
- 文件夹页集中管理连接、重新授权与移除，设置页管理封面缓存、操作提示、版本和开源许可。子文件夹和分类采用自适应海报网格，标题叠加在首帧画面上。独立播放页竖屏上播放器下列表，全屏可显隐右侧列表，复用同一播放会话。iPhone 返回资料库后恢复竖屏；iPad 保持自由旋转。
- 中央大播放键与前后 10 秒，细红色进度条显示已播和剩余时间，轻点轨道直接跳转，按住或拖动显示当前时间的真实画面预览，松手定位；鼠标 / 触控板悬停只预览；倍速、锁定、选集及下一部集中在底部，全屏缩小位于右上角。独立倍速面板支持 0.5～3 倍速、拖动进度、前进/后退 10 秒、上一集/下一集、列表自动连播，最后一集结束后停止。
- 播放页“更多”提供锁定控制和 15/30/60 分钟定时暂停。锁定屏蔽画面手势及播放列表，点击解锁恢复；计时包含暂停和切集，关闭播放页取消，切后台仍按既有规则暂停。
- 长按视频封面或播放列表可查看文件名、格式、大小、修改时间、根目录、相对路径与目录状态，并复制相对路径；播放页“更多”也可进入。信息来自本地索引。
- 单击显隐播控，双击暂停/继续，单指左右滑动定位（全宽约 120 秒）；左侧上下调系统亮度，右侧上下调系统音量；双指捏合 1～4 倍、放大后双指平移。
- 切后台、锁屏、音频被打断或耳机拔出时暂停；返回前台不自动恢复。退出播放恢复原屏幕亮度。
- 缓存目录授权和轻量文件索引，不复制视频，不保存播放进度、观看历史或跨启动倍速。字幕关闭，使用默认音轨，无切换界面。
- 文件/存储断开后停止播放、提示用户、保留目录索引；刷新或重新授权后手动开始播放。

列表支持 MP4 / M4V / MOV / MKV / AVI / WebM / MPEG / TS / M2TS / MTS / 3GP / FLV / WMV。容器与编码分别决定可播放性；不承诺所有损坏文件或特殊编码均能播放。具体设备的 4K / HDR、外接盘拔插和解码性能仍需真机验证。

## 当前验证状态

当前开发版为 **0.2.1 / build 12**，基于既有仓库的 `79d8d3c`，开发分支为 `fix/vela-controls-library`。0.2.0 已由用户确认安装；本轮针对单击播控、全屏退出方向、离线目录和多目录界面继续修复。build 5 协调全屏退出的布局、旋转和播放页关闭时机；build 6 增加播放列表首帧缩略图、目录读取进度以及下拉重建索引；build 7 增加前后 10 秒、锁定控制、定时暂停和视频信息；build 8 调整为黑红影院配色、大封面首页和四个 Tab，分开管理分类、文件夹与设置；build 9 重做首页，主视觉铺满屏宽并延伸到状态栏后方，叠加标题、播放与信息按钮，使用顶部筛选、点击展开的搜索，以及竖版海报和横版目录片架；build 10 将分类、文件夹、设置和所有播放面板统一为相同的影院样式，播放器采用中央三键、细红色进度条和独立倍速面板，保留单击、手势和旋转规则；build 11 增加进度条任意位置点击跳转、按住 / 拖动和指针悬停缩略图预览，预览独立静音解码并按需取消；build 12 修正首页底部 Tab 遮挡，缩小全屏列表封面，并支持从右侧左滑呼出、列表右滑收起。

本轮在 MacBook 上使用 Xcode 26.0 / iOS 26.0.1 模拟器执行 Core、原生播放与界面操作测试，并构建 ARM64 Release 包。实际通过项目和仍待真机检查的范围见 [VALIDATION.md](VALIDATION.md)。构建成功不等于新版已在手机安装或验收。

本地构建的 build 12 安装包与验证附件使用 Release 标签 [`v0.2.1-build12`](https://github.com/hi-craft/localframe-player/releases/tag/v0.2.1-build12)，代码在 `fix/vela-controls-library` 分支。下载 IPA 后需自行通过 SideStore 签名安装；SHA-256 文件用于核对下载完整性。

## 使用 GitHub 云端构建（无需 Apple 密码或开发证书）

1. 在既有 `hi-craft/localframe-player` 仓库中修改并提交本项目。严禁将其他本地项目或无关代码上传到 GitHub。
2. 打开仓库 **Actions → Build iOS → Run workflow**，或向 `main` 推送代码自动触发。手动运行时可勾选 `build_only`，运行 Core 测试并构建设备 IPA，跳过模拟器编译和启动验证。
3. 工作流先运行 Swift Package 逻辑测试，然后生成 Xcode 工程、安装固定版本内核，构建设备安装包；模拟器中验证 MP4/MKV 首帧、取消/远程输入拒绝和实际播放进度，最后分别启动 iPhone / iPad 保存截图。
4. 成功后，在该次运行的 Artifacts 下载 `LocalFrame-unsigned-ipa`。解压得到 `LocalFrame-unsigned.ipa`。
5. `build-diagnostics` 含编译日志、测试输出及模拟器启动截图。播放内核采用固定官方发布包及 SHA-256 校验，不依赖 CocoaPods 在线解析。

**unsigned IPA 需要签名才能安装，不能直接点开安装。**云端构建不需要 Apple 账号；网络用于下载构建依赖和上传产物，与播放器运行时行为分开。

私有仓库的 Actions 使用账户可用额度，超出额度可能计费。参阅 [GitHub 构建机说明](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)。

## Windows 安装与签名选择

| 方式 | 有效期与维护 | 适用情况 |
|---|---|---|
| 免费 Apple 账号 + AltStore Classic | 约 7 天，AltServer 可尝试后台刷新，需要电脑配合 | 免费入门、Windows 可安装 |
| 免费 Apple 账号 + SideStore | 仍是 7 天，配置后可尝试设备端后台续签；后台执行不保证每次及时完成 | 减少每周接电脑的操作 |
| 自己的付费开发者账号 + Ad Hoc 签名 | 描述文件通常约一年，须包含两台设备的 UDID，过期仍需重新签名 | 希望长期使用、减少维护 |

普通系统配置描述文件（`.mobileconfig`）不等于应用签名描述文件（`.mobileprovision`），安装前者不能延长免费应用签名。付费 Apple Developer Program 标准年费为 99 美元或当地定价；本工程不要求开通，也不要求上架。

官方说明：[AltStore Windows 安装](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)、[SideStore 安装](https://docs.sidestore.io/docs/installation/install)、[SideStore FAQ](https://docs.sidestore.io/docs/faq.html)、[Apple 免费账户限制](https://developer.apple.com/help/account/basics/about-your-developer-account)、[Apple Ad Hoc 有效期](https://developer.apple.com/videos/play/wwdc2019/304/)、[Apple 开发者年费](https://developer.apple.com/help/account/membership/program-enrollment)。

账号登录与二次验证在对应官方客户端/侧载工具中完成；工程和 GitHub 工作流无需存储 Apple 账号密码。

## 本地 Mac 开发

```sh
brew install xcodegen
bash scripts/fetch-playback-framework.sh
xcodegen generate
open LocalFrame.xcodeproj
```

在 Xcode 中选择模拟器即可本地运行。更新已有 SideStore 安装时保留工程 Bundle ID `com.localframe.player`；直接在 Xcode 真机运行时再配置自己的 Team。只构建无签名 IPA：

```sh
bash scripts/build-unsigned.sh
```

运行可独立测试的库逻辑：

```sh
swift test --package-path Core
```

运行原生播放及界面测试（先生成测试素材，再生成工程；测试视频不会进入 Release 安装包）：

```sh
brew install ffmpeg
bash scripts/generate-test-media.sh
xcodegen generate
xcrun simctl list devices available
xcodebuild test -project LocalFrame.xcodeproj -scheme LocalFrame \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath build/simulator -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=''
```

界面测试仅在 Debug 且带 `-ui-testing` 参数时准备独立样本和一个离线索引，普通启动不重置资料库。测试会在所选模拟器 App 的容器内写入样本，请使用开发测试模拟器。


## 文件访问与离线边界

目录通过 security-scoped bookmark 恢复授权，扫描、首帧解码和播放期间保持作用域有效。扫描使用文件元数据，不预先解析所有视频。应用数据写入自己的 Application Support 和 Caches；不改写用户视频。

应用没有 URL 输入、网络播放、分析统计、广告、更新检查或自行下载文件的代码。播放器输入限制为已授权目录内的普通本地文件，拒绝路径穿越、符号链接、播放列表、已识别 iCloud 项目和非本地卷；每个媒体输入关闭网络元数据和字幕自动发现。VLC 内核自身包含网络协议实现，本工程不使用这些能力；这里不是操作系统级网络防火墙。

系统“文件”选择器可能展示第三方云位置，系统文件提供方的行为不由 App 控制。请只选择“我的 iPhone / iPad”或外接盘。对于第三方提供方伪装为本地路径的文件，不能仅凭 `file://` 声称一定不会触发提供方网络活动。

播放器在每次点击视频时捕获当前浏览结果的读取顺序队列：首页为该根目录全部视频，文件夹页为本层视频，搜索时为搜索结果，分类页为当前分类结果。之后修改搜索不会改变正在播放的连播顺序；再次点击列表项时更新队列。视频或目录不可读时停止，不自动跳过异常文件。目录接口本身不保证顺序稳定，也不提供系统“文件”App 的界面排序偏好。

## 代码结构

- `Core/`：可独立测试的模型、读取顺序合并、播放活动判定、安全路径、递归扫描、播放队列、缓存淘汰规则。
- `App/Services/`：书签作用域、协调读取、轻索引持久化和封面队列。
- `App/Bridge/`：Objective-C 播放桥接；libVLC 首帧像素回调，无视频临时副本。
- `App/Playback/`：播放状态、设备断开检测、手势和系统音量。
- `App/Views/`：iPhone / iPad 自适应列表、播放器、目录与缓存设置。
- `.github/workflows/ios.yml`：测试、编译、打包、模拟器启动检查。

播放内核直接集成官方 XCFramework；版本为 3.7.4，下载与 SHA-256 校验固定在 `scripts/fetch-playback-framework.sh`。首次构建下载并验证，之后复用构建缓存。

开源内核许可见 `THIRD_PARTY_NOTICES.md` 和随 App 提供的上游许可。

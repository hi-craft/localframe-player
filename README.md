# Vela Player

为 iPhone 15 Pro Max 和 iPad Air M1 设计的本地视频播放器。SwiftUI / UIKit 界面，MobileVLCKit 3.7.4 播放内核。最低 iOS / iPadOS 17；云端使用 macOS 15 构建机上的 Xcode 26.3。

应用名称为 Vela Player，工程与仓库目录沿用 LocalFrame。0.1.1 将桌面名称和签名注册名称统一为英文，修正 SideStore 注册中文 appIdName 时安装失败的问题；操作界面保留中文。

## 已实现的首版范围

- 系统目录选择器，支持多个本地或外接根目录，递归扫描；子目录视频合并、自然排序、按文件名和相对路径搜索。
- 左侧视频首个解码帧封面；一个封面解码任务同时运行，滚出屏幕时取消。内存图片缓存约 8 MB，磁盘 JPEG 封面缓存预算 64 MB，按最近使用顺序淘汰。
- 竖屏上播放器下列表；横屏进入大画面，可显隐右侧列表。iPad 横屏默认显示右侧列表；旋转与切换布局复用同一个播放会话。
- 0.5～3 倍速、拖动进度、上一集/下一集、列表自动连播，最后一集结束后停止。
- 单击显隐播控，双击暂停/继续，单指左右滑动定位（全宽约 120 秒）；左侧上下调系统亮度，右侧上下调系统音量；双指捏合 1～4 倍、放大后双指平移。
- 切后台、锁屏、音频被打断或耳机拔出时暂停；返回前台不自动恢复。退出播放恢复原屏幕亮度。
- 缓存目录授权和轻量文件索引，不复制视频，不保存播放进度、观看历史或跨启动倍速。字幕关闭，使用默认音轨，无切换界面。
- 文件/存储断开后停止播放、提示用户、保留目录索引；刷新或重新授权后手动开始播放。

列表支持 MP4 / M4V / MOV / MKV / AVI / WebM / MPEG / TS / M2TS / MTS / 3GP / FLV / WMV。容器与编码分别决定可播放性；不承诺所有损坏文件或特殊编码均能播放。具体设备的 4K / HDR、外接盘拔插和解码性能仍需真机验证。

## 当前验证状态

Vela Player 0.1.1 于 2026-10-29（香港时间）通过 [ARM64 设备 IPA 构建](https://github.com/hi-craft/localframe-player/actions/runs/40733292760)，构建提交为 `9b853b118a9a9ef9d6d2df2a4b237668844d6da5`。已核对安装包完整性、版本、英文名称及播放框架嵌入。本次按用户要求采用 `build_only`，跳过测试和模拟器步骤。

此前的 [完整原生验证](https://github.com/hi-craft/localframe-player/actions/runs/40723131697) 覆盖 7 项 Core 测试、4 项原生播放/首帧测试，以及 iPhone / iPad 模拟器独立启动；该记录对应改名前的提交 `4836c32a7c01ddfb5ecaa071d1f570224be1f2a9`。

**真机播放、500～1000 个视频的性能、系统音量和外接盘拔插仍待两台设备验收。**模拟器测试中还观察到 MobileVLCKit 视频视图的后台线程图层修改诊断，详情见 `VALIDATION.md`。Windows 安装步骤见 [INSTALL-Windows.md](INSTALL-Windows.md)。

## 使用 GitHub 云端构建（无需 Apple 密码或开发证书）

1. 将本目录中的内容放在 GitHub 私有仓库根目录，确保 `.github/workflows/ios.yml` 一起上传。
2. 打开仓库 **Actions → Build iOS → Run workflow**，或向 `main` 推送代码自动触发。手动运行时可勾选 `build_only`，只构建设备 IPA，跳过逻辑测试、模拟器编译和启动验证。
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

在 Xcode 中选择自己的 Team 和唯一 Bundle ID，连接设备后运行。只构建无签名 IPA：

```sh
bash scripts/build-unsigned.sh
```

运行可独立测试的库逻辑：

```sh
swift test --package-path Core
```

## 文件访问与离线边界

目录通过 security-scoped bookmark 恢复授权，扫描、首帧解码和播放期间保持作用域有效。扫描使用文件元数据，不预先解析所有视频。应用数据写入自己的 Application Support 和 Caches；不改写用户视频。

应用没有 URL 输入、网络播放、分析统计、广告、更新检查或自行下载文件的代码。播放器输入限制为已授权目录内的普通本地文件，拒绝路径穿越、符号链接、播放列表、已识别 iCloud 项目和非本地卷；每个媒体输入关闭网络元数据和字幕自动发现。VLC 内核自身包含网络协议实现，本工程不使用这些能力；这里不是操作系统级网络防火墙。

系统“文件”选择器可能展示第三方云位置，系统文件提供方的行为不由 App 控制。请只选择“我的 iPhone / iPad”或外接盘。对于第三方提供方伪装为本地路径的文件，不能仅凭 `file://` 声称一定不会触发提供方网络活动。

播放器在每次点击视频时捕获当前搜索结果的自然排序队列。之后修改搜索不会改变正在播放的连播顺序；再次点击列表项时更新队列。视频或目录不可读时停止，不自动跳过异常文件。

## 代码结构

- `Core/`：可独立测试的模型、自然排序、安全路径、递归扫描、播放队列、缓存淘汰规则。
- `App/Services/`：书签作用域、协调读取、轻索引持久化和封面队列。
- `App/Bridge/`：Objective-C 播放桥接；libVLC 首帧像素回调，无视频临时副本。
- `App/Playback/`：播放状态、设备断开检测、手势和系统音量。
- `App/Views/`：iPhone / iPad 自适应列表、播放器、目录与缓存设置。
- `.github/workflows/ios.yml`：测试、编译、打包、模拟器启动检查。

播放内核直接集成官方 XCFramework；版本为 3.7.4，下载与 SHA-256 校验固定在 `scripts/fetch-playback-framework.sh`。首次构建下载并验证，之后复用构建缓存。

开源内核许可见 `THIRD_PARTY_NOTICES.md` 和随 App 提供的上游许可。

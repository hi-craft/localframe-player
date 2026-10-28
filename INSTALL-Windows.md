# Windows 安装到 iPhone / iPad

本项目的 GitHub Actions 生成 `LocalFrame-unsigned.ipa`。它是已编译的 iPhone / iPad 应用，安装前仍需要用自己的 Apple 账号签名。GitHub 构建不需要 Apple 密码。

## 免费路线：SideStore

1. 按 [SideStore 官方安装说明](https://docs.sidestore.io/docs/installation/install)，在 Windows 上完成 SideStore 的初次安装、设备配对及账号授权；开发者模式、信任和设备端确认由你在设备上完成。
2. 按官方说明安装 [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044)，在手机上连接并允许其 VPN 配置。这是手机本地的开发连接通道，不需要选择国家或购买 VPN 服务。保持 Wi-Fi 已连接，完成 SideStore 登录后，在 My Apps 中点 SideStore 的剩余天数按钮，确认首次刷新成功。
3. 将 `LocalFrame-unsigned.ipa` 放入设备的“文件”。在 SideStore 的 My Apps 中点 `+`，选择这个 IPA，由 SideStore 签名并安装。
4. 打开桌面上的“Vela Player”，点添加目录，在系统选择器中选择“我的 iPhone / iPad”或外接存储目录。首次扫描后列表自动显示视频；点击视频开始播放。
5. SideStore 会尝试后台续签。免费签名周期仍约 7 天，首次设置完成后应确认后台刷新和剩余有效期正常。参阅 [SideStore FAQ](https://docs.sidestore.io/docs/faq.html)。

也可使用 [AltStore Classic 的 Windows 路线](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)，由 Windows 上的 AltServer 辅助刷新签名。

### SideStore 登录报 -80045

SideStore 问题区有“iloader 登录成功、手机登录失败”的相同记录。可按 [问题 #1688 中的社区临时方案](https://github.com/SideStore/SideStore/issues/1688) 关闭设备端 Anisette、选中 SideStore (New) 服务器并关闭自动轮换，然后同步服务器配置、保存覆盖、重置 adi.pb（不保留 Headers），彻底关闭应用后重试。不同版本菜单位置和服务器可用性可能不同，这不是保证有效的官方修复；无需因此重置手机或替换设备配对文件。

若错误变为 HTTP 502，记录新错误及当前服务器；它表示此次服务器请求失败，不能单凭这个错误判断账号密码。[问题 #1664 的排查说明](https://github.com/SideStore/SideStore/issues/1664) 列出内置替代服务器及需要收集的信息。

### 安装时 appIdName 无效

SideStore 注册 App ID 时会使用应用名称，中文名称可能被拒绝，参见 [SideStore 问题 #1489](https://github.com/SideStore/SideStore/issues/1489)。0.1.1 的 `CFBundleDisplayName` 和 `CFBundleName` 使用英文 `Vela Player`，应用内保留中文操作界面。旧包若提示“本地映像 was provided for the parameter appIdName”，请改选修正后的 `VelaPlayer-0.1.1.ipa`。

### 刷新时通知未授权

若出现“Repository could not save notification. Source is not authorized.”，在 iPhone 设置的“通知 → SideStore”中启用允许通知，彻底关闭并重新打开 SideStore 后重试。参见 [SideStore 问题 #1421](https://github.com/SideStore/SideStore/issues/1421)。

## 减少长期维护：自己的付费开发者账号

自己的 Apple Developer Program 账号可为登记的 iPhone / iPad 创建 Ad Hoc 描述文件并签名安装。有效期通常约一年；不需要上架。当前源码没有绑定某个 Apple Team，可后续补充签名构建配置。普通 `.mobileconfig` 配置文件不能延长免费应用签名。

## 首次真机检查

- 先用几段本地 MP4 / MOV / MKV 检查播放、暂停、进度、倍速和首帧封面。
- 检查单击、双击、左右亮度/音量手势、捏合与放大后的双指拖动。
- 检查横竖屏、全屏、列表切换，以及锁屏、切后台和耳机拔出时的暂停行为。
- 外接盘播放中拔出，应停止播放并保留索引；重新连接并刷新后，手动开始播放。
- 再用 500～1000 个文件检查扫描和滚动体验。性能、系统音量和真实外接设备行为需要在实际设备上验收。

签名工具本身需要联网完成 Apple 授权和续签；Vela Player 的日常视频扫描与播放使用本地文件。

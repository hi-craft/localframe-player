# Windows 安装到 iPhone / iPad

本项目的 GitHub Actions 生成 `LocalFrame-unsigned.ipa`。它是已编译的 iPhone / iPad 应用，安装前仍需要用自己的 Apple 账号签名。GitHub 构建不需要 Apple 密码。

## 免费路线：SideStore

1. 按 [SideStore 官方安装说明](https://docs.sidestore.io/docs/installation/install)，在 Windows 上完成 SideStore 的初次安装、设备配对及账号授权；开发者模式、信任和设备端确认由你在设备上完成。
2. 将 `LocalFrame-unsigned.ipa` 放入设备的“文件”。在 SideStore 的应用列表中点添加，选择这个 IPA，由 SideStore 签名并安装。
3. 打开“本地映像”，点添加目录，在系统选择器中选择“我的 iPhone / iPad”或外接存储目录。首次扫描后列表自动显示视频；点击视频开始播放。
4. SideStore 会尝试后台续签。免费签名周期仍约 7 天，首次设置完成后应确认后台刷新和剩余有效期正常。参阅 [SideStore FAQ](https://docs.sidestore.io/docs/faq.html)。

也可使用 [AltStore Classic 的 Windows 路线](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)，由 Windows 上的 AltServer 辅助刷新签名。

## 减少长期维护：自己的付费开发者账号

自己的 Apple Developer Program 账号可为登记的 iPhone / iPad 创建 Ad Hoc 描述文件并签名安装。有效期通常约一年；不需要上架。当前源码没有绑定某个 Apple Team，可后续补充签名构建配置。普通 `.mobileconfig` 配置文件不能延长免费应用签名。

## 首次真机检查

- 先用几段本地 MP4 / MOV / MKV 检查播放、暂停、进度、倍速和首帧封面。
- 检查单击、双击、左右亮度/音量手势、捏合与放大后的双指拖动。
- 检查横竖屏、全屏、列表切换，以及锁屏、切后台和耳机拔出时的暂停行为。
- 外接盘播放中拔出，应停止播放并保留索引；重新连接并刷新后，手动开始播放。
- 再用 500～1000 个文件检查扫描和滚动体验。性能、系统音量和真实外接设备行为需要在实际设备上验收。

签名工具本身需要联网完成 Apple 授权和续签；“本地映像”的日常视频扫描与播放使用本地文件。

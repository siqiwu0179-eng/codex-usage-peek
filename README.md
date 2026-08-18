# Codex Usage Peek

原生 macOS Codex 周用量工具。主应用通过本机 Codex App Server 的只读 `account/rateLimits/read` 方法读取周额度，提供菜单栏入口和自动隐藏的屏幕边缘 Card；WidgetKit 源码用于 macOS 桌面小组件。

## 当前功能

- 读取真实的 Codex 一周额度窗口，不用 API token 用量进行估算。
- 将 `usedPercent` 转换为剩余百分比，并显示服务端重置时间。
- 右侧或左侧屏幕边缘自动展开/隐藏。
- Card 固定、手动刷新、5 分钟自动更新。
- 离线或协议错误时保留上次成功快照。
- 菜单栏快捷查看与设置页。
- WidgetKit 小/中尺寸组件源码与 App Group 快照共享。

## 正式本机版

项目已包含 `CodexUsagePeek.xcodeproj`，其中有主应用和 `CodexUsageWidget` 两个 Target。使用本机 Apple Development Personal Team 签名，仅在自己的 Mac 上使用，不需要付费或上传 App Store。

Release 构建：

```zsh
xcodebuild \
  -project CodexUsagePeek.xcodeproj \
  -scheme CodexUsagePeek \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/XcodeDerived \
  -allowProvisioningUpdates \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
```

输出：`build/XcodeDerived/Build/Products/Release/Codex Usage Peek.app`

当前本机安装位置：`/Applications/Codex Usage Peek.app`。内嵌的 Widget Extension 已签名并注册为 `com.siqi.codexusagepeek.widget`。

`./scripts/build-app.sh` 仍可生成仅含悬浮 Card 的临时测试版，但它不包含可安装的 Widget Extension。

首次启动后，应用会调用 `/Applications/ChatGPT.app/Contents/Resources/codex app-server --stdio`。用户必须已经在 ChatGPT/Codex 应用中登录。

## 小组件

WidgetKit Extension 与主应用使用同一 Apple Development Team 和 App Group `group.com.siqi.codexusagepeek`。主应用每 5 分钟重新读取一次数据，也支持手动刷新；成功后写入 App Group 并请求 WidgetKit 重新加载时间线。小组件的实际显示刷新时机仍由 macOS 调度。

在桌面空白处右键选择“编辑小组件”，搜索“Codex 周用量”即可添加小或中尺寸版本。

App Server 协议可能随 Codex 更新调整。Provider 已隔离协议解析；如果后续 schema 变化，主要更新 `CodexAppServerProvider` 与 `CodexRateLimitParser`。

## 隐私

应用只发送初始化握手和 `account/rateLimits/read`，不请求线程、任务、prompt、代码或文件数据，也不会读取 Codex 的 cookie/token。主应用不需要辅助功能、屏幕录制或完全磁盘访问权限。

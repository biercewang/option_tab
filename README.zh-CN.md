# TrustedAltTab

[English](README.md) | 中文

TrustedAltTab 是一个本地、可审计的 macOS 窗口切换器和轻量窗口管理工具。它使用 Swift、AppKit、Carbon HotKey API、CoreGraphics 和 macOS Accessibility API 构建。

核心流程类似基于窗口的 Alt-Tab：按住 `Option`，按 `Tab` 打开窗口列表，继续按 `Tab` 前进，或用 `Shift-Tab` / `Option-·` 反向选择，松开 `Option` 后切换到选中的窗口。

## 功能

- `Option-Tab` / `Option-Shift-Tab` 窗口切换。
- `Option-·` 作为更方便的反向切换快捷键。
- 最近使用顺序排序，刚用过的窗口排在前面。
- 同时显示可见窗口和最小化到 Dock 的窗口。
- 有屏幕录制权限时显示窗口缩略图。
- 缩略图关闭或不可用时回退到应用图标。
- 双击 `Option` 最小化屏幕最前方窗口。
- 针对屏幕最前方窗口的布局快捷键。
- 可选的实验性 `Option-W` / `Option-Q` 命令转发。
- 菜单栏设置和用户级开机自动启动。
- 完全本地运行：不联网、不上传数据、无遥测、无自动更新器。

## 快捷键

| 快捷键 | 功能 |
| --- | --- |
| `Option-Tab` | 打开或前进窗口切换器 |
| `Option-Shift-Tab` | 在窗口切换器中反向选择 |
| `Option-·` | 在窗口切换器中反向选择 |
| 双击 `Option` | 最小化屏幕最前方窗口 |
| `Option-←` | 将屏幕最前方窗口移动到左半屏 |
| `Option-→` | 将屏幕最前方窗口移动到右半屏 |
| `Option-1` | 将屏幕最前方窗口移动到左半屏 |
| `Option-2` | 将屏幕最前方窗口移动到右半屏 |
| `Option-↑` | 铺满当前屏幕可用区域，但不进入 macOS 全屏空间 |
| `Option-↓` | 还原到布局调整前的位置和大小 |
| `Option-3` | 在铺满和还原之间切换 |
| `Option-W` | 可选：行为类似 `Command-W` |
| `Option-Q` | 可选：行为类似 `Command-Q` |

`Option-W` 和 `Option-Q` 默认关闭。只有在菜单栏中启用后，TrustedAltTab 才会拦截这两个快捷键。

## 菜单项

- 启用或停用 `Option-Tab`。
- 显示或隐藏缩略图。
- 包含或排除最小化到 Dock 的窗口。
- 包含或排除隐藏应用窗口。
- 启用或停用双击 `Option` 最小化。
- 启用或停用实验性 `Option-W/Q` 关闭/退出快捷键。
- 启用或停用开机自动启动。
- 打开辅助功能和屏幕录制权限设置。
- 手动显示窗口列表。

开机自动启动通过用户级 LaunchAgent 实现：

```bash
~/Library/LaunchAgents/local.trusted-alt-tab.login.plist
```

## 权限

TrustedAltTab 可能请求：

- 辅助功能：读取、还原、聚焦、最小化、移动和调整窗口大小。
- 屏幕录制：生成本地窗口缩略图。

快捷键注册本身使用 Carbon，不需要辅助功能权限。关闭缩略图后可以不使用屏幕录制权限。

## 构建

要求：

- macOS 13 或更高版本。
- 带 Swift 5.9 或更高版本的 Xcode Command Line Tools。

构建并安装 app bundle：

```bash
./scripts/build-app.sh
open ~/Applications/TrustedAltTab.app
```

构建脚本会生成：

- `dist/TrustedAltTab.app`
- `~/Applications/TrustedAltTab.app`

脚本会优先使用本机可用的 Apple Development 签名身份；如果没有可用身份，则回退到 ad-hoc 签名。

## 重置权限

如果 macOS 不再弹出权限提示：

```bash
./scripts/reset-permissions.sh
```

然后重新打开：

```bash
open ~/Applications/TrustedAltTab.app
```

## 诊断

日志写入本地：

```bash
~/Library/Logs/TrustedAltTab.log
```

## 项目结构

```text
Sources/TrustedAltTab/
  AppDelegate.swift
  HotKeyManager.swift
  OptionDoubleTapMonitor.swift
  WindowProvider.swift
  DisplayedWindowResolver.swift
  SwitcherOverlay.swift
  WindowRowView.swift
  WindowFocuser.swift
  CurrentWindowMinimizer.swift
  WindowSnapper.swift
  WindowCommandPerformer.swift
  LoginItemManager.swift
scripts/
  build-app.sh
  reset-permissions.sh
docs/
  ARCHITECTURE.md
```

## 与 AltTab 的关系

本项目在功能体验上受到 AltTab for macOS 的启发，但没有复制、vendored、翻译或改写 AltTab 源码。AltTab 的公开源码使用 GPL-3.0 许可证；TrustedAltTab 是直接基于 macOS API 的独立实现。

更多归属和许可边界说明见 [NOTICE.md](NOTICE.md)。

## 许可证

MIT。见 [LICENSE](LICENSE)。

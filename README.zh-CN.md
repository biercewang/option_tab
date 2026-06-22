# AltGesture

[English](README.md) | 中文

AltGesture 是一个本地、可审计的 macOS 窗口切换器、轻量窗口管理工具和右键鼠标手势工具。它使用 Swift、AppKit、Carbon HotKey API、CoreGraphics 和 macOS Accessibility API 构建。

核心流程类似基于窗口的 Alt-Tab：按住 `Option`，按 `Tab` 打开窗口列表，继续按 `Tab` 前进，或用 `Shift-Tab` / `Option-·` 反向选择，松开 `Option` 后切换到选中的窗口。

## 功能

- `Option-Tab` / `Option-Shift-Tab` 窗口切换。
- `Option-·` 作为更方便的反向切换快捷键。
- 最近使用顺序排序，刚用过的窗口排在前面。
- 同时显示可见窗口和最小化到 Dock 的窗口。
- 可选显示窗口缩略图；默认关闭以减少权限请求。
- 缩略图关闭或不可用时回退到应用图标。
- 双击 `Option` 最小化屏幕最前方窗口；如果所有窗口都已最小化，则恢复最近最小化的窗口。
- 针对屏幕最前方窗口的布局快捷键。
- 内置 Magnet 常用窗口布局：左/右/上/下半屏、四角、居中、铺满和还原。
- 可选的实验性 `Option-Z/A/S/X/C/V/W/Q` 命令转发。
- 可配置的右键鼠标手势和右键组合鼠标键动作。
- 连续三击右键切换隐私黑屏，用黑色遮罩覆盖所有屏幕并隐藏鼠标指针；再次三击恢复。
- 菜单栏设置和用户级开机自动启动。
- 完全本地运行：不联网、不上传数据、无遥测、无自动更新器。

## 快捷键

| 快捷键 | 功能 |
| --- | --- |
| `Option-Tab` | 打开或前进窗口切换器 |
| `Option-Shift-Tab` | 在窗口切换器中反向选择 |
| `Option-·` | 在窗口切换器中反向选择 |
| 双击 `Option` | 最小化屏幕最前方窗口；没有可见窗口时恢复最近最小化的窗口 |
| `Option-←` | 将屏幕最前方窗口移动到左半屏 |
| `Option-→` | 将屏幕最前方窗口移动到右半屏 |
| `Option-1` | 将屏幕最前方窗口移动到左半屏 |
| `Option-2` | 将屏幕最前方窗口移动到右半屏 |
| `Option-↑` | 铺满当前屏幕可用区域，但不进入 macOS 全屏空间 |
| `Option-↓` | 还原到布局调整前的位置和大小 |
| `Option-3` | 在铺满和还原之间切换 |
| 连续三击右键 | 隐私黑屏并隐藏鼠标指针；再次三击恢复 |
| `Option-Z` | 可选：行为类似 `Command-Z` |
| `Option-A` | 可选：行为类似 `Command-A` |
| `Option-S` | 可选：行为类似 `Command-S` |
| `Option-X` | 可选：行为类似 `Command-X` |
| `Option-C` | 可选：行为类似 `Command-C` |
| `Option-V` | 可选：行为类似 `Command-V` |
| `Option-W` | 可选：行为类似 `Command-W` |
| `Option-Q` | 可选：行为类似 `Command-Q` |

这些 Option 字母命令快捷键默认关闭。只有在菜单栏中启用后，AltGesture 才会拦截这些快捷键。

右键手势默认启用。按住鼠标右键并拖动，或按住右键再按另一个鼠标键，会触发配置文件中的快捷键。连续三击右键会进入隐私黑屏并隐藏鼠标指针；再次连续三击右键恢复。新 app 会在第一次启动时从下面这些旧配置里优先迁移第一个可用文件：

```text
~/Library/Application Support/TrustedAltTab/right-gestures.json
~/Library/Application Support/RightKeyGesture/gestures.json
```

迁移后的配置写入：

```text
~/Library/Application Support/AltGesture/right-gestures.json
```

旧配置里通过 Magnet 触发的 `Control+Option+方向键` 手势会自动改为 AltGesture 原生窗口布局动作，因此不再需要安装 Magnet。

## 菜单项

- 启用或停用 `Option-Tab`。
- 显示或隐藏缩略图。
- 包含或排除最小化到 Dock 的窗口。
- 包含或排除隐藏应用窗口。
- 启用或停用双击 `Option` 最小化。
- 启用或停用实验性 Option 字母命令快捷键。
- 启用、重启或重新加载右键手势。
- 打开右键手势配置文件。
- 启用或停用开机自动启动。
- 打开辅助功能、输入监控、自动化和屏幕录制权限设置。
- 手动显示窗口列表。

开机自动启动通过用户级 LaunchAgent 实现：

```bash
~/Library/LaunchAgents/local.alt-gesture.login.plist
```

## 权限

AltGesture 可能请求：

- 辅助功能：核心权限，用于读取、还原、聚焦、最小化、移动和调整窗口大小。
- 输入监控：核心权限，用于监听右键鼠标手势、鼠标组合键、连续三击右键、双击 Option 和 Option 释放事件。
- 屏幕录制：可选权限，只用于生成本地窗口缩略图；默认关闭缩略图以避免请求。
- 自动化：条件权限，只在自定义右键手势仍需要通过 System Events 触发全局快捷键时由 macOS 弹窗请求。内置窗口布局不需要自动化权限。

快捷键注册本身使用 Carbon，不需要辅助功能权限。最小授权建议见 [docs/PERMISSIONS.zh-CN.md](docs/PERMISSIONS.zh-CN.md)。

## 构建

要求：

- macOS 13 或更高版本。
- 带 Swift 5.9 或更高版本的 Xcode Command Line Tools。

构建并安装 app bundle：

```bash
./scripts/build-app.sh
open ~/Applications/AltGesture.app
```

构建脚本会生成：

- `dist/AltGesture.app`
- `~/Applications/AltGesture.app`

脚本会优先使用本机可用的 Apple Development 签名身份；如果没有可用身份，则回退到 ad-hoc 签名。

## 重置权限

如果 macOS 不再弹出权限提示：

```bash
./scripts/reset-permissions.sh
```

然后重新打开：

```bash
open ~/Applications/AltGesture.app
```

## 诊断

日志写入本地：

```bash
~/Library/Logs/AltGesture.log
```

## 项目结构

```text
Sources/AltGesture/
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
  InputMonitoringPermission.swift
  RightGestureConfig.swift
  RightGestureEngine.swift
  LoginItemManager.swift
scripts/
  build-app.sh
  generate-app-icon.py
  reset-permissions.sh
docs/
  ARCHITECTURE.md
  PERMISSIONS.zh-CN.md
Resources/
  AppIcon.icns
```

## 与 AltTab 的关系

本项目在功能体验上受到 AltTab for macOS 的启发，但没有复制、vendored、翻译或改写 AltTab 源码。AltTab 的公开源码使用 GPL-3.0 许可证；AltGesture 是直接基于 macOS API 的独立实现。

更多归属和许可边界说明见 [NOTICE.md](NOTICE.md)。

## 许可证

MIT。见 [LICENSE](LICENSE)。

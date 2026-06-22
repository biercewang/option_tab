# AltGesture 权限说明

AltGesture 按最小授权运行：默认只请求核心功能需要的权限；屏幕录制和自动化都不是默认必需项。

## 权限清单

| macOS 权限 | 是否必需 | 用途 | 不授权的影响 |
| --- | --- | --- | --- |
| 辅助功能 | 核心功能需要 | 聚焦、恢复、最小化、移动窗口；右键手势事件拦截也依赖它稳定工作 | 窗口切换、最小化、布局和右键手势会不稳定或不可用 |
| 输入监控 | 核心功能需要 | 监听右键鼠标手势、鼠标组合键、双击 Option 和 Option 释放事件 | 右键手势和双击 Option 不可用；Option-Tab 释放确认会降级 |
| 屏幕录制 | 可选 | 只用于生成本地窗口缩略图 | 关闭缩略图即可不授权；窗口列表会使用应用图标 |
| 自动化 | 条件需要 | 仅当某个右键手势配置为通过 System Events 发送快捷键时使用 | 这些特定手势无法触发 Magnet 等全局快捷键；其他功能不受影响 |

## 最小授权建议

如果只想保持核心体验，授权：

- 辅助功能
- 输入监控

不要授权或不要开启：

- 屏幕录制：保持菜单里的“显示窗口缩略图”关闭。
- 自动化：避免使用配置里带 `"delivery": "systemEvents"` 的右键手势；如果需要 Magnet 的全局快捷键，再按 macOS 弹窗授权。

## 本地数据

- 日志：`~/Library/Logs/AltGesture.log`
- 右键手势配置：`~/Library/Application Support/AltGesture/right-gestures.json`
- 开机启动：`~/Library/LaunchAgents/local.alt-gesture.login.plist`

AltGesture 不联网、不上传数据、无遥测。

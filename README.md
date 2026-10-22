<div align="center">

<img src="docs/images/icon.png" width="128" height="128" alt="BKCleanHelper 图标">

# BKCleanHelper

**一分钟，安心擦一擦 🧽**

macOS 菜单栏小工具：临时暂停键盘、触摸板和外接键鼠 60 秒，放心擦拭，到时自动恢复。

**简体中文** · [English](README.en.md)

<img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
<img src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white" alt="macOS 13+">
<img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
<img src="https://img.shields.io/badge/dependencies-none-brightgreen.svg" alt="无外部依赖">

</div>

---

擦键盘时总会误触一堆按键？擦触摸板时光标乱跑、窗口乱切？BKCleanHelper 在你擦拭的这一分钟里接管所有输入事件，并且**无论发生什么都会让输入自动恢复**。

<p align="center">
  <img src="docs/images/overlay.svg" width="720" alt="清洁遮罩示意图">
  <br><sub>清洁模式全屏界面（示意图）</sub>
</p>

## ✨ 特性

- ⌨️ **一键暂停输入**：内置键盘、触摸板、外接键盘与鼠标统一暂停
- ⏱️ **60 秒自动恢复**：计时由独立子进程负责，不依赖界面是否正常
- 🆘 **随时提前结束**：同时按住 <kbd>⌃ Control</kbd> <kbd>⌥ Option</kbd> <kbd>⌘ Command</kbd> <kbd>U</kbd> 两秒
- 🛡️ **多重兜底**：主程序退出、通信断开、锁屏、睡眠、切换用户时都会立即解除
- 👀 **先预览再使用**：「预览清洁界面」无需授权，看一眼效果（预览时**不会**屏蔽输入）
- 🍎 **原生体验**：AppKit、系统字体、SF Symbols，支持浅色与深色外观
- 🔒 **完全本地**：不联网、不记录输入、不改系统配置、不装驱动

## 🚀 快速开始

### 1. 📦 下载安装

1. 前往 [**Releases**](https://github.com/binbinku/BKCleanHelper/releases/latest) 下载最新的 `BKCleanHelper-版本号.dmg`
2. 双击打开 DMG，把 `BKCleanHelper` **拖到旁边的「Applications」文件夹**（之后不要再移动它，否则可能需要重新授权）
3. 推出 DMG，在「应用程序」中双击打开 BKCleanHelper

支持 macOS 13 及以上，Apple 芯片和 Intel 都能运行（Universal 包）。

> [!IMPORTANT]
> **第一次打开会被 macOS 拦截**，提示「无法验证开发者」。这是因为本项目没有付费的 Apple 开发者签名和公证，并不代表应用有问题，源码都在这个仓库里。放行方法：
>
> - **macOS 15 及以上**：双击后在提示框里点「完成」，然后打开 **系统设置 → 隐私与安全性**，滚动到「安全性」部分，点击「仍要打开」，输入密码后再次确认「打开」
> - **macOS 13 / 14**：在「应用程序」中**右键点击** BKCleanHelper → 「打开」→ 再点「打开」
>
> 只需要操作一次。**不需要、也不应该**为此关闭 SIP 或 Gatekeeper。

<details>
<summary>🔨 也可以从源码构建</summary>

需要 macOS 13 或更新版本，以及 Xcode 16 或更新版本（构建 Universal 包需要完整的 Xcode）。

```sh
git clone https://github.com/binbinku/BKCleanHelper.git
cd BKCleanHelper
bash scripts/build.sh
```

构建完成后得到 `outputs/BKCleanHelper.app`。自己构建的应用使用本机临时签名，重新构建后可能需要在系统设置里重新授权。

</details>

### 2. 授权

打开应用，在主窗口中分别点击「前往设置…」，在 **系统设置 → 隐私与安全性** 中允许 BKCleanHelper 使用：

| 权限 | 用途 |
| --- | --- |
| ♿ 辅助功能 | 拦截并暂停系统投递的输入事件 |
| ⌨️ 输入监控 | 监听键盘、鼠标与触摸板事件（包括提前结束快捷键） |

两项缺一不可，任何一项被撤销，清洁都会立即中断并恢复输入。

如果系统提示退出并重新打开应用，照做即可。两项都显示「已允许」后就可以开始了。

### 3. 开始清洁

<p align="center">
  <img src="docs/images/flow.zh.svg" width="820" alt="清洁流程：开始清洁 → 3 秒准备 → 60 秒清洁 → 自动恢复">
</p>

1. 在菜单栏图标或主窗口中点击「开始清洁」
2. **松开所有按键和鼠标按钮**，3 秒准备期间可以取消
3. 看到「键盘与触摸板已暂停」后再开始擦拭 🧽
4. 60 秒后自动恢复；需要提前结束时，按住 <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>U</kbd> 两秒

关闭主窗口后，菜单栏入口仍然保留；退出应用会立即结束清洁并恢复输入。

## 🛡️ 它为什么不会把你锁在外面

屏蔽输入的工具最怕出问题时“解不开”。BKCleanHelper 把**拦截输入**和**显示界面**拆成了两个进程，并且给每个环节都设计了退路：

<p align="center">
  <img src="docs/images/architecture.zh.svg" width="820" alt="安全架构示意图">
</p>

- **独立的拦截子进程**负责事件拦截，截止时间使用连续时钟，睡眠时间也计算在内，不依赖主窗口计时
- 截止时间一到，即使定时器延迟，也会**立即放行**所有事件，绝不会延长锁定时间
- 主程序退出、通信断开、锁屏、睡眠或切换用户时，拦截会立即解除
- **后台看门狗**：子进程超过 2 秒没有心跳，或者总时长超过 64 秒，主程序会强制结束它
- 子进程一旦结束，系统会自动移除它的事件拦截
- 全屏遮罩**不接收鼠标事件**，避免界面本身变成另一把“锁”
- 权限不足或无法建立完整拦截时**拒绝启动**，不会只显示一个看起来像在拦截的假遮罩

## ⚠️ 已知限制

> [!WARNING]
> - **电源键 / Touch ID 按钮**以及硬件强制关机无法屏蔽，擦拭时请避开它们。
> - 应用拦截的是系统投递的输入事件，并不切断硬件供电，触摸板仍可能产生触感反馈。
> - 多指系统手势、特殊功能键、第三方手势工具、安全输入场景等，需要在你的 Mac 上实际验证，系统更新或其他输入工具也可能影响拦截范围。**第一次正式使用前**，建议先打开一个空白文档，试试普通按键、系统快捷键、触摸板滚动和多指手势。
> - 系统中途中断拦截时，本轮清洁会立即结束，并提示你停止擦拭。

## 🔒 隐私

- 🚫 不联网
- 🚫 不记录、不回放任何输入内容
- 🚫 不修改系统键盘或触摸板设置
- 🚫 不安装驱动或常驻特权服务

## ❓ 常见问题

<details>
<summary><b>如果真的“卡住”了怎么办？</b></summary>

按顺序尝试：

1. 等待：60 秒后一定会自动恢复（看门狗兜底上限为 64 秒）
2. 按住 <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>U</kbd> 两秒
3. 合上屏幕或让 Mac 进入睡眠，锁屏和睡眠都会立即解除拦截
4. 最后的办法：长按电源键强制关机（电源键不受影响）

</details>

<details>
<summary><b>升级新版本或重新构建后，权限显示“未授权”？</b></summary>

应用没有固定的开发者签名，每个新版本都可能被系统当成新的应用。在 **系统设置 → 隐私与安全性** 的「辅助功能」和「输入监控」中，删除旧的 BKCleanHelper 条目，再重新添加即可。

</details>

<details>
<summary><b>为什么提示“请松开所有按键和鼠标按钮”？</b></summary>

如果开始拦截时还有按键或鼠标按钮处于按下状态，它“抬起”的事件会被拦截掉，系统就会以为这个键一直按着。所以准备结束后，BKCleanHelper 会等你松开所有按键再开始；超过 8 秒仍未松开，本轮就会取消。

</details>

<details>
<summary><b>支持 Intel Mac 吗？</b></summary>

支持。发布的是 Universal 包，Apple 芯片和 Intel 都能原生运行。如果你在 Intel Mac 上遇到问题，欢迎反馈 🙌

</details>

## 🛠️ 开发

```text
.
├── Sources/
│   ├── BKCleanHelper/      # App 主程序：菜单栏、主窗口、遮罩、拦截子进程
│   └── CleanCore/      # 纯逻辑：截止时间、提前结束检测、心跳与看门狗
├── Tests/CleanCoreTests/
├── Resources/Info.plist
├── scripts/
│   ├── build.sh        # 构建 .app、生成图标、临时签名并打包
│   ├── check.sh        # 单元测试 + 子进程模拟测试
│   ├── test_worker.py
│   ├── Icon.swift      # 生成 App 图标
│   └── package_icon.py
└── Package.swift
```

```sh
bash scripts/check.sh   # 测试
bash scripts/build.sh   # 构建 outputs/BKCleanHelper.app
```

可以用 Xcode 打开 `Package.swift` 阅读和调试源码；日常运行请使用构建出来的 `.app`，这样权限归属才稳定。

🧪 模拟测试**不会**真正拦截键鼠，覆盖范围包括：精确截止时间、持续按住才能提前结束、重复停止、父进程断开、子进程暂停后恢复、输出管道断开、无效命令。

<details>
<summary><b>📋 实机验收清单</b></summary>

真实的输入屏蔽需要用户手动授权，模拟测试不能代替实机验收。发布前建议逐项检查：

- [ ] 普通键、修饰键
- [ ] <kbd>⌘</kbd><kbd>Tab</kbd>、<kbd>⌘</kbd><kbd>Space</kbd>
- [ ] 音量、亮度键
- [ ] 指针移动、点击、拖动
- [ ] 双指滚动、缩放、旋转
- [ ] 三指、四指手势
- [ ] 外接键盘与鼠标
- [ ] 60 秒自动恢复
- [ ] <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>U</kbd> 提前结束
- [ ] 清洁中撤销权限
- [ ] 正常退出、异常退出
- [ ] 睡眠与唤醒
- [ ] 多显示器

</details>

## 🤝 参与贡献

欢迎提交 Issue 和 Pull Request！

- 🐛 报告问题时，请附上 macOS 版本、机型，以及是否接了外接键鼠
- 🔧 提交代码前请运行 `bash scripts/check.sh`
- ⌨️ 涉及输入拦截的改动，请在实机上按上面的验收清单检查一遍

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。

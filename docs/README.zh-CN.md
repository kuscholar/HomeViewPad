<p align="center">
  <img src="media/homeviewpad-logo.png" width="128" height="128" alt="HomeViewPad：一扇看见家的玻璃窗">
</p>
<h1 align="center">HomeViewPad</h1>
<p align="center"><strong>让闲置 iPad 重新发挥作用。</strong><br>原生 Apple Home 控制、照片与时钟面板。</p>
<p align="center">
  <img src="https://img.shields.io/badge/iPadOS-17%2B-145C50?style=flat-square" alt="iPadOS 17 或以上">
  <img src="https://img.shields.io/badge/Built_with-SwiftUI-145C50?style=flat-square" alt="使用 SwiftUI 构建">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/License-MIT-D6A64D?style=flat-square" alt="MIT 许可证"></a>
  <img src="https://img.shields.io/badge/Status-Early_preview-D6A64D?style=flat-square" alt="早期预览版">
</p>
<p align="center"><a href="../README.md">English</a> · <a href="#先看它干活">看演示</a> · <a href="#让闲置-ipad-重新上岗">开始使用</a> · <a href="ARCHITECTURE.md">隐私与架构</a></p>

---

## 买新屏幕之前，先看看已有的 iPad。

已有的 iPad 可以成为方便查看家庭状态、操作配件和展示照片的共享屏幕。HomeViewPad 将这些日常用途集中起来，无需 App 账号或自建后端。

HomeViewPad 给闲置 iPad 安排了一份新工作：控制家里的灯和温度，显示一眼就能看清的时钟，再把相册里的照片搬进客厅。把 HomePod mini 放在旁边，或者给它们找个共同的支架，一个 DIY 家庭面板就有了雏形。

这是采用 MIT 许可的早期源码预览，需要使用 Xcode 构建。

<p align="center">
  <img src="media/ipad-homepod-use-case.png" width="960" alt="运行 HomeViewPad 的 iPad 与 HomePod mini 并排摆在家中">
  <br><sub>基于实际 App 截图生成的 AI 场景示意图，屏幕使用 DEMO 数据。</sub>
</p>

### 我们的「高度集成」方案

| 准备什么 | 负责什么 |
| :--- | :--- |
| **家里已有的 iPad** | 屏幕、触控和电子相框。需要 iPadOS 17 或以上。 |
| **HomeViewPad** | 玻璃组件、Apple Home 控制、时钟与照片墙。原生 SwiftUI，MIT 许可。 |
| **可选的 HomePod mini** | 通过 Apple 自身功能提供 Siri、支持的家庭中枢功能和音频播放。 |
| **一个支架，一个插座** | 工业设计部门。 |

iPad 跑 App，HomePod mini 在 Apple Home 中独立工作。Apple「家庭」App 仍负责设备配置、授权和自动化。HomeViewPad 是前台面板，不提供 Siri、家庭成员识别、集成 FaceTime 或 Intercom。

## 先看它干活

<p align="center">
  <img src="media/demo.gif" width="880" alt="真实运行演示：温度调整、灯光、组件切换、时钟和三张照片轮播">
  <br><sub>真实模拟器录屏 · 演示配件 · 作者提供的照片 · 约 15 秒</sub>
</p>

调一下温度，关一盏灯，滑过时钟，再让照片占满屏幕。

新版 GIF 为 15 秒实录剪辑，快放操作并剪去轮播等待，展示三张授权照片；App 本身仍按 30 秒间隔轮播。它展示实际界面运行，不代表真实 HomeKit 或 HomePod 联动验证。[素材与录制说明 →](MEDIA.md)

## 不点它的时候，也值得放在那里

| **一眼看见家的状态** | **让相册走出相册** |
| :--- | :--- |
| 大号温控组件搭配五个小组件，玻璃材质、暖灰或青绿背景。菜单平时收好，主屏留给内容。 | 选择相册或单张图片，配上大号时钟和渐变切换。那些拍完就没再打开的照片，终于在客厅有了展位。 |
| **该控制的时候，直接动手** | **少一点界面，多一点生活** |
| 选择家庭和房间，控制支持的配件，确认后运行场景。温度箭头遵守设备的调节范围和步长。 | 左右切页面，上下切组件。每个组件位置各司其职，轮播指示点只在切换时短暂出现。 |

想再安静一点？**Overview 四宫格**只留下日期、数字刻度指针钟、相册和天气。纯黑背景与组件，白色文字、黄色点缀，不用玻璃材质。现在它就是打开 App 的第一屏。Release 使用 [Apple WeatherKit](https://developer.apple.com/cn/weatherkit/)，Debug 默认使用 Open-Meteo，并可在天气面板切换数据源：默认费城，获得 Apple 定位授权后显示所在城市，也能手动选城市。点击天气可搜索、刷新和切换摄氏/华氏；DEMO 中保留固定示例。

还包括按需开启的 HomeKit 摄像头、可选日历与提醒事项、本地音频与系统 AirPlay 选择器，以及前台保持屏幕常亮的选项。实验性「Standby and wake」会保持 App 不锁屏，待机时保留当前页面、只把屏幕亮度降到最低，默认由声音直接恢复原亮度，可调节声音灵敏度，也可以触摸唤醒；若主动选择 TrueDepth 模式，则必须在声音触发后确认近距离人脸才亮屏，平时不开摄像头。没有智能家居设备，也可以直接体验 DEMO。

### 说明书就这几行

| 操作 | 效果 |
| :--- | :--- |
| **左右滑动** | 四宫格（Overview）→ 主屏 → 时钟 → 照片 → 设置 |
| **组件内上下滑动** | 切换该位置可用的内容 |
| **点击背景空白或照片墙** | 显示导航：横屏在右，竖屏在下 |
| **点击温度箭头** | 调整兼容温控器的可写目标温度 |

动画支持系统「减弱动态效果」。灯光组件也不会一滑就变成另一块重复的时钟。

## 让闲置 iPad 重新上岗

**目前需要用 Xcode 构建，尚未上架 App Store。**

```sh
git clone https://github.com/kuscholar/HomeViewPad.git
cd HomeViewPad
open HomePad.xcodeproj
```

选择 **HomePad** scheme 和 iPadOS 17 或以上的 iPad 模拟器，运行后向左滑到 **Home**，点击 **Explore demo**。没有第三方包依赖，也不需要先准备配件。

<details>
<summary><strong>安装到自己的 iPad</strong></summary>

1. 把 `Config/Local.xcconfig.example` 复制为 `Config/Local.xcconfig`。
2. 填入自己的唯一 Bundle ID 和开发团队。此本地文件已被 Git 忽略。
3. 连接 iPad，用 **HomePad** scheme 构建。账号需要支持 HomeKit 签名配置，并按 Apple 提示完成设备信任与开发者模式设置。
4. **Debug 默认使用 Open-Meteo**。点击天气，在 **Debug weather provider** 中切换 Open-Meteo / WeatherKit；重启后保留选择。切换会清除旧天气和搜索结果，城市及温度单位不变，失败时不会自动换源。
5. Debug 测试真实 **WeatherKit** 时，需要付费开发者账号，为 App ID 同时开启 WeatherKit 的 Capability 和 App Service，在被 Git 忽略的 `Config/Local.xcconfig` 加入 `HOMEVIEWPAD_DEBUG_ENTITLEMENTS = HomePad/HomePad.entitlements`，再更新 Xcode 签名。默认 Debug 使用 `HomePadDebug.entitlements`，因此 Open-Meteo 开发不依赖 WeatherKit 签名。**Release 固定使用 WeatherKit**，包含其权限，完全不编译 Open-Meteo 实现或切换选项。
6. 向左滑到 **Home**，选择 **Connect Apple Home**、授权并选择家庭。配件和场景先在 Apple 的「家庭」App 中配置。
7. 点击照片组件，选择单张图片，或连接照片库并选择相册。有限授权下只显示允许访问的照片。

HomePod mini 是可选项，在 Apple「家庭」App 中独立设置。播放本地音频时可通过系统 AirPlay 选择器选择它；Apple Music 使用系统「音乐」App 和音频路由。

对外名称是 HomeViewPad，工程、scheme 和源文件目录暂时保留 HomePad。照片在主屏、四宫格或照片墙可见时每 30 秒轮播；打开面板或离开前台时暂停。

</details>

## 家里不用再多一个账号

无需 App 账号、自建后端或分析 SDK。家庭、照片、日历和提醒事项使用 Apple 公共 API 与系统授权。个人日历和提醒默认隐藏，只有主动开启后才显示。

Release 天气和城市搜索只使用 Apple WeatherKit 与 Core Location。Debug 默认调用 [Open-Meteo](https://open-meteo.com/) 的天气和城市搜索接口，也可以在天气面板切换到 WeatherKit；来源标识、隐私说明随之切换。Open-Meteo 免费端点仅用于非商业开发，Release 会从编译阶段移除该实现和切换选项，并忽略 Debug 保存的数据源选择。

自动定位始终使用 Apple 前台授权，自动检测到的天气坐标取整到约 1 公里精度，不写入磁盘；手动城市与温度单位保存在本机。断网时旧天气标为缓存。不需要第三方 API 密钥或自建后端。WeatherKit 可依 [Apple 条款](https://developer.apple.com/cn/weatherkit/)用于商业 App，每个付费开发者会员每月包含 50 万次调用，由所有用户共享，超出需购买相应套餐。正常可见时每 15 分钟刷新，待机或后台不刷新。

相册按需读取，iCloud 图片可能经 PhotoKit 下载；单张导入照片保存在 App 沙盒内。App 不修改系统照片库。**共享屏幕上的内容，旁人也能看见。** [数据如何保存与清除 →](ARCHITECTURE.md)

<details>
<summary><strong>玩笑归玩笑，能力边界写清楚</strong></summary>

这是早期独立项目，不是 Apple 官方产品，也不替代 Apple「家庭」App。App 本身不是家庭中枢，不承载 Siri、不访问 HomePod 麦克风，不支持 Intercom 或内嵌 FaceTime。

目前不创建自动化，也不直接编辑门锁、窗帘或温控器模式。已有场景可能包含这些动作，因此执行场景前始终需要确认。没有 Apple Music 曲库、身份识别或后台摄像头录制。待机功能默认关闭，可在 Settings → Standby and wake 开启；不能解锁 iPad 或从后台打开 App。开启时会引导授权，权限缺失或麦克风启动失败会保持或恢复正常亮度并显示原因。麦克风仅在待机期间工作，TrueDepth 检测同时使用前置图像和深度，单次最多请求三秒，系统隐私指示灯会正常显示。安静经过可能漏检，真实设备上的识别率、耗电和暗室效果尚未验证。不支持 TrueDepth 的机型可选纯声音或触摸唤醒，不会改用普通摄像头。

模拟器通过不等于硬件验证。真实配件、摄像头、HomePod/AirPlay 和长期常亮仍需要按[硬件清单](HARDWARE_CHECKLIST.md)验证。[实际测试记录 →](VALIDATION.md)

</details>

## 项目状态与贡献

[![iPad 模拟器 CI](https://github.com/kuscholar/HomeViewPad/actions/workflows/ci.yml/badge.svg)](https://github.com/kuscholar/HomeViewPad/actions/workflows/ci.yml)

徽章显示远端工作流状态，不代表硬件已验证。CI 执行 Debug 单元/UI 测试、Release 天气回归和未签名设备构建；三项依赖在线天气/地理编码的测试单独手动运行。请查看[实际测试记录](VALIDATION.md)、[硬件清单](HARDWARE_CHECKLIST.md)和[源码发布说明](RELEASING.md)。目前没有 App Store 版本或已签名的可下载安装包。

[贡献指南](../CONTRIBUTING.md)说明全新模拟器、合成照片、测试模式与 PR 要求；[路线图](ROADMAP.md)提供可参与的小范围任务。请遵守[行为准则](../CODE_OF_CONDUCT.md)，[私下报告安全漏洞](../SECURITY.md)，并查看[更新记录](../CHANGELOG.md)。

## 一起把它做得更好

欢迎问题报告和有明确目标的改进。请说明 iPad 型号、系统版本、复现步骤，以及使用 DEMO 还是真实家庭；提交前移除照片、家庭标识和签名信息。

[构建、测试和录屏命令](../README.md#make-it-yours) · [贡献规则](../AGENTS.md)

---

<p align="center"><strong>旧 iPad 的第二份工作，最好离沙发近一点。</strong><br><sub>SwiftUI、家里现成的设备，以及对好支架的一点执念。</sub></p>

[MIT 许可证](../LICENSE) · [架构](ARCHITECTURE.md) · [验证记录](VALIDATION.md) · [素材说明](MEDIA.md)

Apple、iPad、HomePod mini、HomeKit 和 AirPlay 属于 Apple Inc.。HomeViewPad 与 Apple 及其他相似名称的产品没有关联或背书关系。文中的 DIY 类比指相近的日常用途，不表示功能完全一致。

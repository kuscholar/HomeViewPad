<p align="center">
  <img src="media/homeviewpad-logo.png" width="128" height="128" alt="HomeViewPad：一扇看见家的玻璃窗">
</p>
<h1 align="center">HomeViewPad</h1>
<p align="center"><strong>想要 HomeView？先翻翻抽屉。</strong><br>一台 iPad，一个 HomePod mini，再加一点重新摆放的智慧。</p>
<p align="center">
  <img src="https://img.shields.io/badge/iPadOS-17%2B-145C50?style=flat-square" alt="iPadOS 17 或以上">
  <img src="https://img.shields.io/badge/Built_with-SwiftUI-145C50?style=flat-square" alt="使用 SwiftUI 构建">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/License-MIT-D6A64D?style=flat-square" alt="MIT 许可证"></a>
  <img src="https://img.shields.io/badge/Status-Early_preview-D6A64D?style=flat-square" alt="早期预览版">
</p>
<p align="center"><a href="../README.md">English</a> · <a href="#先看它干活">看演示</a> · <a href="#让闲置-ipad-重新上岗">开始使用</a> · <a href="ARCHITECTURE.md">隐私与架构</a></p>

---

## 苹果发布了 HomeView。我们重新整理了一下桌面。

看完 [Apple HomeView](https://www.apple.com/apple-homeview/)，再看看手里的 iPad 和旁边的 HomePod mini，突然觉得：**屏幕有了，音箱有了，好像就差让它们坐一桌。**

HomeViewPad 给闲置 iPad 安排了一份新工作：控制家里的灯和温度，显示一眼就能看清的时钟，再把相册里的照片搬进客厅。把 HomePod mini 放在旁边，或者给它们找个共同的支架，一个 DIY 家庭面板就有了雏形。

**发布会没有。支架可以有。**

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

iPad 跑 App，HomePod mini 在 Apple Home 中独立工作。这套组合能覆盖看照片、看时间、点按控家等日常用途；**并不等于拥有 HomeView 的全部功能**。内置 Siri AI、家庭成员识别、集成 FaceTime 和 Intercom，都不会因为我们买了一个支架就自动出现。

## 先看它干活

<p align="center">
  <img src="media/demo.gif" width="880" alt="真实运行演示：温度调整、灯光、组件切换、时钟和三张照片轮播">
  <br><sub>真实模拟器录屏 · 演示配件 · 作者提供的照片 · 约 90 秒</sub>
</p>

调一下温度，关一盏灯，滑过时钟，再让照片占满屏幕。

新版 GIF 为 15 秒实录剪辑，快放操作并剪去轮播等待，展示三张授权照片；App 本身仍按 30 秒间隔轮播。它展示实际界面运行，不代表真实 HomeKit 或 HomePod 联动验证。[素材与录制说明 →](MEDIA.md)

## 不点它的时候，也值得放在那里

| **一眼看见家的状态** | **让相册走出相册** |
| :--- | :--- |
| 大号温控组件搭配五个小组件，玻璃材质、暖灰或青绿背景。菜单平时收好，主屏留给内容。 | 选择相册或单张图片，配上大号时钟和渐变切换。那些拍完就没再打开的照片，终于在客厅有了展位。 |
| **该控制的时候，直接动手** | **少一点界面，多一点生活** |
| 选择家庭和房间，控制支持的配件，确认后运行场景。温度箭头遵守设备的调节范围和步长。 | 左右切页面，上下切组件。每个组件位置各司其职，轮播指示点只在切换时短暂出现。 |

想再安静一点？**Overview 四宫格**只留下日期、数字刻度指针钟、相册和天气。纯黑背景与组件，白色文字、黄色点缀，不用玻璃材质。现在它就是打开 App 的第一屏。正常模式接入 [Apple WeatherKit](https://developer.apple.com/cn/weatherkit/) 天气：默认费城，获得 Apple 定位授权后显示所在城市，也能手动选城市。点击天气可搜索、刷新和切换摄氏/华氏；DEMO 中保留固定示例。

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
3. 连接 iPad，用 **HomePad** scheme 构建。账号需要支持 HomeKit 和 WeatherKit 签名配置，并按 Apple 提示完成设备信任与开发者模式设置。
4. 真实天气需要付费 Apple Developer Program 会员。在开发者网站的 App ID 设置中，同时开启 WeatherKit 的 Capability 和 App Service，再让 Xcode 更新自动签名。未签名的模拟器可能显示天气不可用，不能据此判断真实天气已接通。
5. 向左滑到 **Home**，选择 **Connect Apple Home**、授权并选择家庭。配件和场景先在 Apple 的「家庭」App 中配置。
6. 点击照片组件，选择单张图片，或连接照片库并选择相册。有限授权下只显示允许访问的照片。

HomePod mini 是可选项，在 Apple「家庭」App 中独立设置。播放本地音频时可通过系统 AirPlay 选择器选择它；Apple Music 使用系统「音乐」App 和音频路由。

对外名称是 HomeViewPad，工程、scheme 和源文件目录暂时保留 HomePad。照片在主屏、四宫格或照片墙可见时每 30 秒轮播；打开面板或离开前台时暂停。

</details>

## 家里不用再多一个账号

无需 App 账号、自建后端或分析 SDK。家庭、照片、日历和提醒事项使用 Apple 公共 API 与系统授权。个人日历和提醒默认隐藏，只有主动开启后才显示。

天气和城市搜索均使用 Apple 服务：原生 WeatherKit 提供天气，Core Location 提供城市查询。自动定位使用 Apple 的前台授权，天气坐标会取整到约 1 公里精度，自动检测到的坐标不写入磁盘；手动城市与温度单位保存在本机。断网时旧天气会标为缓存数据。天气组件和面板保留 Apple 要求的标识与数据来源链接。不再调用 Open-Meteo，也不需要第三方 API 密钥。WeatherKit 可依 [Apple 条款](https://developer.apple.com/cn/weatherkit/)用于商业 App；每个付费开发者会员每月包含 50 万次调用，由所有用户共享，超出需购买相应套餐。正常情况下可见时每 15 分钟刷新一次，待机或后台不刷新。

相册按需读取，iCloud 图片可能经 PhotoKit 下载；单张导入照片保存在 App 沙盒内。App 不修改系统照片库。**共享屏幕上的内容，旁人也能看见。** [数据如何保存与清除 →](ARCHITECTURE.md)

<details>
<summary><strong>玩笑归玩笑，能力边界写清楚</strong></summary>

这是早期独立项目，不是 Apple 官方产品，也不完整替代 HomeView。App 本身不是家庭中枢，不承载 Siri、不访问 HomePod 麦克风，不支持 Intercom 或内嵌 FaceTime。

目前不创建自动化，也不直接编辑门锁、窗帘或温控器模式。已有场景可能包含这些动作，因此执行场景前始终需要确认。没有 Apple Music 曲库、身份识别或后台摄像头录制。待机功能默认关闭，可在 Settings → Standby and wake 开启；不能解锁 iPad 或从后台打开 App。开启时会引导授权，权限缺失或麦克风启动失败会保持或恢复正常亮度并显示原因。麦克风仅在待机期间工作，TrueDepth 检测同时使用前置图像和深度，单次最多请求三秒，系统隐私指示灯会正常显示。安静经过可能漏检，真实设备上的识别率、耗电和暗室效果尚未验证。不支持 TrueDepth 的机型可选纯声音或触摸唤醒，不会改用普通摄像头。

模拟器通过不等于硬件验证。真实配件、摄像头、HomePod/AirPlay 和长期常亮仍需要按[硬件清单](HARDWARE_CHECKLIST.md)验证。[实际测试记录 →](VALIDATION.md)

</details>

## 一起把它做得更好

欢迎问题报告和有明确目标的改进。请说明 iPad 型号、系统版本、复现步骤，以及使用 DEMO 还是真实家庭；提交前移除照片、家庭标识和签名信息。

[构建、测试和录屏命令](../README.md#make-it-yours) · [贡献规则](../AGENTS.md)

---

<p align="center"><strong>旧 iPad 的第二份工作，最好离沙发近一点。</strong><br><sub>SwiftUI、家里现成的设备，以及对好支架的一点执念。</sub></p>

[MIT 许可证](../LICENSE) · [架构](ARCHITECTURE.md) · [验证记录](VALIDATION.md) · [素材说明](MEDIA.md)

Apple、Apple HomeView、iPad、HomePod mini、HomeKit 和 AirPlay 属于 Apple Inc.。HomeViewPad 与 Apple 及其他相似名称的产品没有关联或背书关系。文中的 DIY 类比指相近的日常用途，不表示功能完全一致。

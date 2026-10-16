# Spor 🇩🇰

[English](#english) | [中文说明](#中文)

[![Release](https://img.shields.io/github/v/release/gwj0323/spor-app?color=blue)](https://github.com/gwj0323/spor-app/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build Android APK](https://github.com/gwj0323/spor-app/actions/workflows/build-apk.yml/badge.svg)](https://github.com/gwj0323/spor-app/actions/workflows/build-apk.yml)
[![Build iOS IPA](https://github.com/gwj0323/spor-app/actions/workflows/build-ios.yml/badge.svg)](https://github.com/gwj0323/spor-app/actions/workflows/build-ios.yml)

---

<a name="english"></a>
## English

Spor is an open-source public transit app for Denmark, available on Android, iOS, and desktop (Windows / macOS / Linux).

It integrates directly with the official [Rejseplanen REST API](https://labs.rejseplanen.dk/), covering nationwide passenger rail (DSB, Arriva), Copenhagen S-tog, Copenhagen Metro (M1–M4), regional and municipal buses (Movia, Midttrafik, etc.), and domestic ferries.

### Features

- **Route Planning**: Search journeys with departure/arrival time filters, transit mode selection, platform numbers, walking transfers, and live delay info.
- **Commute Suggestions & Habit Ranking**:
  - Suggests frequent and return routes based on your usual travel times, recent searches, and nearby stations.
  - Ranks journey results based on your transit habits (duration, transfers, walking, Metro/S-tog/Train/Bus) and highlights the recommended route with a 1-tap `Preferred order` toggle.
  - **Tight Transfer Warnings**: Highlights short or delayed connections where transfer time is tight.
- **Intermediate Stops & Visual Proportions**: Tap any leg to see all stops along the route, or glance at the proportional colored leg duration bar on each card.
- **Live Departure Boards**: Real-time station departure and arrival boards with delay alerts, track changes, 30-second auto-refresh, and quick chips for your most-viewed stations.
- **Unified Trip Reminders**: One sheet to manage departure alerts, transfer alerts, arrival alerts, and the live status bar notification card.
- **Calendar Export & Itinerary Sharing**: Export trips to Apple/Google Calendar or copy a formatted trip summary with 1 tap.
- **Nearby Stops**: Find bus, train, and metro stops near your current location.
- **Themes, Nav Styles & Languages**: English, Danish, and Chinese. Supports dark mode, Material You dynamic colors, custom hex accent colors, and switchable bottom navigation bar styles (floating frosted glass bar with sliding capsule or classic Material 3).
- **In-App Update Check**: Check for new GitHub releases directly from the Settings screen.
- **Offline Demo**: Built-in mock data for testing without an API key.

### Downloads

Pre-built binaries can be downloaded from the **[Releases](https://github.com/gwj0323/spor-app/releases)** page:

| Platform | Package | Installation |
| :--- | :--- | :--- |
| **Android** | `app-release.apk` | Download and install directly (allow installing from unknown sources). Signed with a fixed release key so future releases can update in place without uninstalling. |
| **iOS** | `spor-ios-release.ipa` | Sideload using [Sideloadly](https://sideloadly.io/), [AltStore](https://altstore.io/), or [TrollStore](https://github.com/opa334/TrollStore). |

### API Configuration

The app ships with offline mock data enabled out of the box. To query live transit data across Denmark:

1. Register an account at [Rejseplanen Labs](https://labs.rejseplanen.dk/) and request a free `accessId` (50,000 requests/month for personal non-commercial use).
2. Enter your `accessId` in the app's **Settings** screen and save.

### Development & Builds

#### Mobile (Flutter)

Located in `rejseplanen_mobile/`. Requires Flutter 3.22+:

```bash
cd rejseplanen_mobile
flutter pub get
flutter run
```

Build Release APK:
```bash
flutter build apk --release
```

#### Desktop (PyQt6)

Requires Python 3.10+:

```bash
pip install -r requirements.txt
python app.py
```

Build Windows executable:
```bash
pyinstaller Rejseplanen.spec
```

### License & Attribution
 
- **Source Code**: Licensed under the [MIT License](LICENSE).
- **Transit Data**: Public transit schedules, stop locations, and real-time transit information are provided by and property of [Rejseplanen A/S](https://www.rejseplanen.dk/). Use of the API is subject to the terms and conditions of Rejseplanen Labs (personal, non-commercial use).

---

<a name="中文"></a>
## 中文

Spor 是一款开源的丹麦公共交通出行客户端，支持 Android、iOS 和桌面端（Windows / macOS / Linux）。

接入丹麦官方 [Rejseplanen REST API](https://labs.rejseplanen.dk/)，支持全丹麦境内的火车 (DSB / Arriva)、S-tog、哥本哈根地铁 (M1–M4)、公交 (Movia 等) 及轮渡。

### 功能

- **行程规划**：起终点路线规划，支持按出发/到达时间筛选、多交通方式过滤，提供站台号、换乘步行引导与实时晚点状态，并配有彩色分段耗时比例条。
- **常走路线与乘车习惯排序**：
  - **常走路线快捷卡片**：根据平时的出行时间段、常查记录与当前位置，在首页直接展示常走或返程路线及下一班发车时间。
  - **按习惯排序**：根据日常选车习惯（耗时、换乘次数、步行时长及地铁/S-tog/火车倾向）自动标记「推荐」方案，支持一键切换按习惯或按发车时间排序。
  - **紧凑换乘提示**：当换乘时间较紧或前车晚点时，自动在卡片上醒目提示剩余换乘分钟数。
- **经停站时刻表**：点击车次展开沿途经停站、计划到发时间与站台。
- **车站大屏**：车站实时发车与到达时刻表，显示晚点、停运与站台变更，支持 30 秒自动刷新及常看车站快捷切换。
- **行程提醒**：统一管理出发提醒、换乘提醒、到站提醒与通知栏实时乘车进度卡片。
- **日历导出与复制行程**：一键将班次加入系统日历，或复制带站台号与车次的行程文本。
- **附近车站**：利用 GPS 查找周边公交站与火车站。
- **多语言与外观**：支持中文、英文、丹麦语；支持深色模式、Material You 动态取色及自定义强调色；底栏支持半透明毛玻璃悬浮栏（支持手势左右滑动切换）与 Material 3 样式切换。
- **检查更新**：在设置页点击版本卡片即可检查 GitHub 最新版本并下载更新。
- **离线示例数据**：未填写 API Key 时可使用内置示例时刻表体验。

### 下载安装

最新安装包请前往 **[Releases 页面](https://github.com/gwj0323/spor-app/releases)** 下载：

| 平台 | 安装包 | 安装方式 |
| :--- | :--- | :--- |
| **Android** | `app-release.apk` | 下载直接安装（需允许安装未知来源应用）。 |
| **iOS** | `spor-ios-release.ipa` | 支持通过 [Sideloadly](https://sideloadly.io/)、[AltStore](https://altstore.io/) 或 [TrollStore](https://github.com/opa334/TrollStore) 侧载安装 |

### API 配置

应用内置离线演示数据。如需获取丹麦全境实时交通数据：

1. 前往 [Rejseplanen Labs](https://labs.rejseplanen.dk/) 免费注册并申请 `accessId`（个人非商业用途每月 50,000 次调用额度）。
2. 在应用「设置」页面的 API Key 一栏填入 `accessId` 并保存。

### 本地开发与构建

#### 移动端 (Flutter)

代码位于 `rejseplanen_mobile/`。需要 Flutter 3.22+：

```bash
cd rejseplanen_mobile
flutter pub get
flutter run
```

打包 Release APK：
```bash
flutter build apk --release
```

#### 桌面端 (PyQt6)

需要 Python 3.10+：

```bash
pip install -r requirements.txt
python app.py
```

打包 Windows 可执行程序：
```bash
pyinstaller Rejseplanen.spec
```

### 许可证与数据声明

- **源代码**：遵循 [MIT License](LICENSE) 开源协议。
- **交通数据**：丹麦全境公共交通时刻表、经停站及实时调度数据版权归 [Rejseplanen A/S](https://www.rejseplanen.dk/) 所有，API 接口使用须遵守 Rejseplanen Labs 官方使用条款（个人非商业用途）。

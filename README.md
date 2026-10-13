# Spor 🇩🇰

丹麦公共交通出行客户端，支持 Android、iOS 和桌面端（Windows / macOS / Linux）。

接入丹麦官方 [Rejseplanen REST API](https://labs.rejseplanen.dk/)，支持全丹麦境内的火车 (DSB / Arriva)、S-tog、哥本哈根地铁 (M1–M4)、公交 (Movia 等) 及轮渡。

[![Release](https://img.shields.io/github/v/release/gwj0323/Rejseplanen-Desktop?color=blue)](https://github.com/gwj0323/Rejseplanen-Desktop/releases)
[![Build Android APK](https://github.com/gwj0323/Rejseplanen-Desktop/actions/workflows/build-apk.yml/badge.svg)](https://github.com/gwj0323/Rejseplanen-Desktop/actions/workflows/build-apk.yml)
[![Build iOS IPA](https://github.com/gwj0323/Rejseplanen-Desktop/actions/workflows/build-ios.yml/badge.svg)](https://github.com/gwj0323/Rejseplanen-Desktop/actions/workflows/build-ios.yml)

---

## 功能

- **行程规划**：起终点路线规划，支持按出发/到达时间筛选、多交通方式过滤，提供站台号、换乘步行引导与实时晚点状态。
- **经停站时刻轴 (JourneyDetail)**：点击车次展开沿途完整经停站列表、计划到发时间与实际站台。
- **实时大屏**：各大车站发车与到达时刻表，显示晚点与站台变更，支持 30 秒自动刷新。
- **行程通知**：
  - 发车、换乘与到站提醒，通知栏推送避免坐过站。
  - 行程常驻动态卡片：乘车期间在通知栏实时展示下一站与预计到达时间。
- **日历导出**：一键将所选班次导出至 Apple Calendar 或 Google Calendar，包含换乘步骤与站台备注。
- **附近站点**：利用 GPS 查找周边公交站与火车站，记录搜索历史。
- **多语言与主题**：支持中文、英文、丹麦语；支持深色模式与 Material You 动态取色。
- **离线演示**：未配置 API 密钥时可启用离线模拟数据体验。

---

## 下载安装

最新安装包请前往 **[Releases 页面](https://github.com/gwj0323/Rejseplanen-Desktop/releases)** 下载：

| 平台 | 安装包 | 安装方式 |
| :--- | :--- | :--- |
| **Android** | `app-release.apk` | 下载直接安装（需允许安装未知来源应用） |
| **iOS** | `spor-ios-release.ipa` | 支持通过 [Sideloadly](https://sideloadly.io/)、[AltStore](https://altstore.io/) 或 [TrollStore](https://github.com/opa334/TrollStore) 侧载安装 |

---

## API 配置

应用内置离线演示数据。如需获取丹麦全境实时交通数据：

1. 前往 [Rejseplanen Labs](https://labs.rejseplanen.dk/) 免费注册并申请 `accessId`（个人非商业用途每月 50,000 次调用额度）。
2. 在应用「设置」页面的 API Key 一栏填入 `accessId` 并保存。

---

## 本地开发与构建

### 移动端 (Flutter)

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

### 桌面端 (PyQt6)

需要 Python 3.10+：

```bash
pip install -r requirements.txt
python app.py
```

打包 Windows 可执行程序：
```bash
pyinstaller Rejseplanen.spec
```

---

## 许可证

本项目仅供个人学习与交流使用，交通数据版权归 [Rejseplanen A/S](https://www.rejseplanen.dk/) 所有。

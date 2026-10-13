# Spor 🇩🇰

基于 Flutter (移动端) 与 PyQt6 (桌面端) 开发的丹麦全域公共交通出行助手，接入丹麦官方 Rejseplanen REST API。

## 项目特点

- **行程规划**：支持全丹麦公共交通（火车 IC/RE、S-tog、Metro M1-M4、公交 Movia、轮渡等）路线查询与换乘详情。
- **经停站时刻表 (JourneyDetail)**：点击任意车次展开途经停靠站完整时刻轴、计划到发时刻与站台 (Spor)。
- **实时发车大屏**：各大车站发车与到达时刻大屏，实时延误预警与站台变动标记，支持 30 秒自动刷新。
- **行程通知助手**：
  - 倒计时推送：出发提醒、换乘提醒与到站下车提醒，避免坐过站。
  - 常驻动态卡片：乘车期间在通知栏实时展示下一站与预计到达时间。
- **一键同步日历**：一键将所选班次导出至 Apple Calendar 或 Google Calendar，自动生成行程日程与站台备忘。
- **周边站点与历史记录**：基于手机 GPS 自动探测周边站点，并记录搜索历史与快速收藏。
- **北欧极简美学**：多语言（简体中文、English、Dansk）切换，支持深色模式与 Material You 动态色彩壁纸取色。
- **离线演示**：未配置 API 密钥时自动启用本地模拟数据，开箱即用。

## 客户端下载与使用

### 1. 移动端 (Android & iOS)

移动端工程位于 [`rejseplanen_mobile/`](file:///c:/Users/gewen/Documents/antigravity/jolly-tesla/Rejseplanen-Desktop/rejseplanen_mobile)：
- **Android APK**：在 GitHub Actions 构建产物中下载 `spor-release-apk`。
- **iOS IPA**：在 GitHub Actions 构建产物中下载 `spor-release-ipa`，支持使用 Sideloadly / AltStore / TrollStore 自签或侧载安装。

### 2. 桌面端 (Windows / macOS / Linux)

需要 Python 3.10+ 环境：

```bash
pip install -r requirements.txt
python app.py
```

打包 Windows 可执行程序：
```bash
pyinstaller Rejseplanen.spec
```

## API 配置说明

软件默认使用离线模拟数据。如果需要查询真实丹麦交通数据：

1. 前往 [Rejseplanen Labs](https://labs.rejseplanen.dk/) 申请免费的 API `accessId`（个人非商业用途每月免费 50,000 次调用）。
2. 在客户端「设置」页面填入 `accessId` 并保存即可。

## 技术栈

- 移动端：Flutter 3 (Material 3) + Dart
- 桌面端：Python 3 + PyQt6 + [PyQt6-Fluent-Widgets](https://github.com/zhiyiYo/PyQt-Fluent-Widgets)
- 数据接口：Rejseplanen REST API 2.0

## 作者

- **gwj0323**

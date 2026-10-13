# Spor Mobile 🇩🇰

基于 Flutter 开发的丹麦全域公共交通跨平台客户端（Android & iOS）。

接入丹麦官方 [Rejseplanen REST API](https://labs.rejseplanen.dk/)，支持火车、S-tog、地铁、公交与轮渡路线查询。

---

## 功能特点

- **行程规划**：起终点路线检索、换乘步行时间、站台号与实时延误预警。
- **经停站点 (JourneyDetail)**：点击任意车次展开途经站点时刻轴与当前停靠位置。
- **实时大屏**：车站发车与到达大屏，支持按交通方式过滤与 30 秒自动刷新。
- **行程通知**：
  - 发车、换乘、下车倒计时推送。
  - 乘车期间通知栏常驻卡片，实时显示下一站与预计到达时刻。
- **日历同步**：一键将换乘方案导出到 Apple Calendar 或 Google Calendar。
- **附近站点**：基于 GPS 定位自动查找周边停靠站点与车站搜索历史。
- **多语言与外观**：支持简体中文、English、Dansk；支持深色模式与 Material You 动态壁纸取色。
- **离线演示**：未配置 API 密钥时可启用模拟数据体验。

---

## 下载安装

安装包请前往仓库 **[Releases](https://github.com/gwj0323/Rejseplanen-Desktop/releases)** 页面下载：

- **Android**：下载 `app-release.apk` 直接安装。
- **iOS**：下载 `spor-ios-release.ipa`，支持使用 [Sideloadly](https://sideloadly.io/)、AltStore 或 TrollStore 自签或侧载安装。

---

## 本地运行与构建

需要 [Flutter 3.22+](https://flutter.dev/)：

```bash
# 获取依赖
flutter pub get

# 本地调试
flutter run

# 打包 Release APK
flutter build apk --release
```

---

## API 说明

默认开启离线演示模式。如需使用丹麦实时数据：

1. 前往 [Rejseplanen Labs](https://labs.rejseplanen.dk/) 免费申请 `accessId`。
2. 打开 App 进入「设置」，填入 `accessId` 保存即可。

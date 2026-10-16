# Spor Mobile 🇩🇰

基于 Flutter 开发的丹麦全域公共交通跨平台客户端（Android & iOS）。

接入丹麦官方 [Rejseplanen REST API](https://labs.rejseplanen.dk/)，支持火车、S-tog、地铁、公交与轮渡路线查询。

---

## 功能特点

- **行程规划**：起终点路线检索、换乘步行时间、站台号、实时延误预警与彩色分段耗时比例条。
- **端侧智能通勤与偏好学习**：
  - 基于周期时间核函数、星期规律与实时 GPS 距离自动预测通勤与返程路线。
  - 在线学习个人乘车偏好（耗时、换乘次数、步行及交通工具倾向），标记 `⚡ 智能首选` 并支持一键按智能推荐排序。
  - 结合前序车次实时晚点与站台信息评估换乘衔接风险。
- **经停站点 (JourneyDetail)**：点击任意车次展开途经站点时刻轴与当前停靠位置。
- **实时大屏**：车站发车与到达大屏，支持按交通方式过滤、30 秒自动刷新及智能推荐常看站点。
- **行程通知与一键下车闹钟**：
  - 发车、换乘提醒及一键开启「到站前 5 分钟下车提醒」。
  - 乘车期间通知栏常驻卡片，按乘车进度动态刷新下一站与预计到达时刻。
- **日历同步与行程分享**：一键将换乘方案导出到系统日历，或复制排版好的行程文本摘要。
- **附近站点**：基于 GPS 定位自动查找周边停靠站点与车站搜索历史。
- **多语言与外观**：支持简体中文、English、Dansk；支持深色模式、Material You 动态壁纸取色及自定义色值；底栏支持高通透悬浮毛玻璃（支持手势左右滑动）与 Material 3 样式切换。
- **检查更新**：在设置页点击关于卡片即可检查 GitHub 最新版本。
- **离线演示**：未配置 API 密钥时可启用模拟数据体验。

---

## 下载安装

安装包请前往仓库 **[Releases](https://github.com/gwj0323/spor-app/releases)** 页面下载：

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

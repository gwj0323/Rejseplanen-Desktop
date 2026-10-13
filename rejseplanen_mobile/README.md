# RejseNu Mobile 🇩🇰

基于 Flutter 开发的丹麦全域公共交通跨平台客户端（Android & iOS），接入官方 [Rejseplanen REST API](https://labs.rejseplanen.dk/)。

## 核心功能

- **行程规划**：全丹麦公共交通（火车 IC/RE、S-tog、Metro、公交 Movia、轮渡）路线查询，换乘步骤、站台与延误详情。
- **经停站时刻表 (JourneyDetail)**：
  - 行程方案中点击「查看经停站」即可展开整段车程的全部中途停靠站、到发时间与 Spor 站台。
  - 实时大屏中点击任意进出站车次，半屏弹窗完整停靠站序列并高亮当前车站。
- **行程通知助手**：
  - 倒计时提醒：出发提醒、换乘提醒与到站提醒，通知栏实时推送避免坐过站。
  - 常驻动态卡片：乘车期间在通知栏实时展示下一站与预计到达时间。
- **一键添加系统日历**：一键将所选班次导出至 Apple Calendar 或 Google Calendar，自动生成行程日程与站台备忘。
- **实时大屏**：查询指定车站的实时发车与到达时刻，显示准点/晚点状态，支持 30 秒自动刷新。
- **站点 GPS 探测与历史**：模糊搜索站点，基于 GPS 自动探测周边停靠站点，记录搜索历史与快速收藏。
- **个性化与多语言**：
  - 支持简体中文、English、Dansk 实时切换（默认跟随系统）。
  - 支持浅色、深色及跟随系统主题。
  - 支持 Material You 动态壁纸色彩提取（Android 12+）、北欧预设色及自定义 Hex 色值。
- **离线演示**：未配置 API Key 时自动启用内置模拟数据，便于离线体验。

## 安装包下载

项目配置了 GitHub Actions 自动化编译，无需本地搭建移动端开发环境即可一键获取安装包：

### 1. Android (APK)
1. 打开本仓库的 [Actions](https://github.com/gwj0323/Rejseplanen-Desktop/actions) 页面。
2. 点击最新一次成功的 **Build Android APK** 工作流。
3. 在页面底部的 **Artifacts** 区域下载 `rejsenu-release-apk`，解压后即可在安卓手机上安装 `app-release.apk`。

### 2. iOS (IPA)
1. 打开本仓库的 [Actions](https://github.com/gwj0323/Rejseplanen-Desktop/actions) 页面。
2. 点击最新一次成功的 **Build iOS IPA** 工作流。
3. 在页面底部的 **Artifacts** 区域下载 `rejsenu-release-ipa`，解压后获得 `rejsenu-ios-release.ipa`。
4. **安装方式（侧载 / 自签）**：
   - **Sideloadly** (推荐，Windows/Mac 均支持)：连接 iPhone，拖入 IPA 输入任意免费 Apple ID 即可自签安装。
   - **AltStore**：通过个人电脑端 AltServer 进行自签无线安装。
   - **TrollStore** (适用于支持的 iOS 版本)：直接导入 IPA 永久免证书安装。

## 本地开发与编译

### 前置要求
- [Flutter SDK 3.22+](https://flutter.dev/docs/get-started/install)
- Android SDK (API 34) 或 macOS (Xcode 15+ 用于 iOS)

### 运行步骤
```bash
# 进入移动端目录
cd rejseplanen_mobile

# 获取依赖
flutter pub get

# 运行调试（连接手机或启动模拟器）
flutter run

# 打包 Release APK
flutter build apk --release
```

打包生成的 APK 位于：
`build/app/outputs/flutter-apk/app-release.apk`

## API 配置说明

软件内置了离线演示数据。如需获取真实实时数据：
1. 前往 [Rejseplanen Labs](https://labs.rejseplanen.dk/) 注册并申请免费的 API `accessId`。
2. 打开 App，在「设置」页面填入密钥并保存，也可以点击「测试连接」验证网络与密钥有效性。

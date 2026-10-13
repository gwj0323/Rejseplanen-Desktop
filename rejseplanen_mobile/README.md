# Rejseplanen Mobile (Android / iOS)

基于 **Flutter 3** 构建的丹麦公共交通移动端 App，接入官方 **Rejseplanen REST API 2.0**，支持离线演示模式与多语言切换。

---

## 📱 核心功能特性

1. **行程规划 (Journey Planner)**
   - 起点与终点站联想选择、一键对调。
   - 出发/到达时间切换、日期与时间选择器。
   - 交通方式过滤：火车 (IC/RE)、S-tog、Metro、公交换乘过滤。
   - 详细换乘时间线：每段线路官方标识（S-tog/Metro 纯正配色）、站台/Spor 提示、延误与准点状态。

2. **实时大屏 (Live Board)**
   - 实时发车 (Departures) 与到达 (Arrivals) 切换。
   - 延误分钟数实时计算（红色标明晚点、绿色准点）。
   - 30 秒自动定时刷新与下拉刷新 (Pull-to-refresh)。

3. **站点查询与 GPS 探测 (Station Explorer)**
   - 车站名称模糊联想搜索。
   - 基于经纬度的周边停靠站探测（内置哥本哈根、奥胡斯市中心快捷定位）。
   - 一键将站点发送至“实时大屏”或设为“行程起点”。

4. **常用收藏与历史 (Favorites & History)**
   - 常用车站与常用路线一键快速查询。
   - 自动记录最近搜索历史。

5. **设置与 API 管理 (Settings)**
   - `accessId` 密钥配置与一键“测试连接”诊断。
   - 离线演示数据开关（断网或无 Key 时无缝回退）。
   - 多语言支持：简体中文、English、Dansk 实时切换。
   - 深色 / 浅色 / 跟随系统主题切换。

---

## 🛠️ 技术架构

- **UI 框架**：Flutter (Material 3)
- **状态管理**：`provider` (`ChangeNotifier`)
- **本地存储**：`shared_preferences`
- **网络请求**：`http` (针对 Rejseplanen 官方 REST API 2.0 及 XML/JSON 兼容处理)
- **多语言**：内置轻量级无依赖三语词条系统

---

## 🚀 如何运行与打包 APK

### 方式一：使用 GitHub Actions 自动云端打包（强烈推荐，无需在本地安装几十G的 Android SDK）

本仓库已配置好自动化打包工作流（位于 `.github/workflows/build-apk.yml`）：
1. 将本代码仓库提交推送到你的 GitHub 仓库（`main` 或 `master` 分支）。
2. 在 GitHub 网页端进入 **Actions** 标签页。
3. 可以在 **Build Android APK** 工作流中看到自动执行编译打包。
4. 编译完成后，在工作流页面下方的 **Artifacts** 直接下载 `rejseplanen-release-apk`，解压即为可直接在安卓手机安装的 `.apk` 安装包！

---

### 方式二：在本地电脑运行与编译

#### 1. 安装 Flutter 环境
下载并安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)。

#### 2. 进入目录并安装依赖
```bash
cd rejseplanen_mobile
flutter pub get
```

#### 3. 运行调试
在手机连接 USB 调试或启动安卓模拟器后执行：
```bash
flutter run
```

#### 4. 本地打包 Release APK
```bash
flutter build apk --release
```
生成的文件位于：
`rejseplanen_mobile/build/app/outputs/flutter-apk/app-release.apk`
直接将该 apk 发送到安卓手机即可安装使用。

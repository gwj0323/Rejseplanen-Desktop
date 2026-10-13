# Rejseplanen Desktop

基于 PyQt6 和 QFluentWidgets 的丹麦公共交通桌面客户端，接入丹麦官方 Rejseplanen API。

## 功能

- **行程规划**：支持火车 (IC/RE)、S-tog、地铁 (M1-M4)、公交等丹麦全境公共交通路线查询，提供换乘详情与站台信息。
- **实时大屏**：支持各大车站的发车（Departures）与到达（Arrivals）大屏，显示实时延误与站台变更，支持 30 秒自动刷新。
- **站点查询**：站名联想搜索，支持按 GPS 经纬度探测周边停靠站点。
- **常用收藏**：收藏常用车站与路线，自动保存最近查询历史。
- **多语言支持**：支持简体中文、English、Dansk 动态切换。
- **线路标识**：采用 Mit Tog 风格的 S-tog (A/B/Bx/C/E/F/H) 和 Metro 线路专属配色。
- **离线演示**：未配置 API Key 或断网时自动启用本地演示数据，开箱即用。

## 运行

需要 Python 3.10+ 环境。

```bash
pip install -r requirements.txt
python app.py
```

## API 配置

软件默认使用离线模拟数据。如果需要查询实时交通信息：

1. 在 [Rejseplanen Labs](https://labs.rejseplanen.dk/) 申请免费的 `accessId`（个人非商业用途每月 50,000 次免费调用）。
2. 在客户端的「设置」中填入 `accessId` 并保存，密钥保存在本地 `settings.json` 中。

## 技术栈

- GUI: Python 3 + PyQt6 + [PyQt6-Fluent-Widgets](https://github.com/zhiyiYo/PyQt-Fluent-Widgets)
- 网络: requests
- 数据接口: Rejseplanen REST API

## 作者

- **gwj0323**

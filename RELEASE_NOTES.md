## ✨ v1.2.0 更新内容 / What's New

### 🇨🇳 中文说明
1. **端侧智能通勤感知 (On-Device Commute Prediction)**
   - 基于本地周期时间高斯核、星期规律、历史频次时间衰减与实时 GPS 距离，智能预测当前出行路线与自动返程路线。
2. **乘车方案偏好在线学习 (Online Preference Ranking)**
   - 自动根据你平时查看/开启提醒的班次在线学习个人偏好（耗时、换乘次数、步行时长及 Metro / S-tog / 火车 / 公交倾向），在搜索结果中标记 `⚡ 智能首选` 并支持按智能推荐排序。
3. **换乘衔接风险评估 (Transfer Risk Analyzer)**
   - 结合前序车次实时晚点（`rtTime`）、换乘步行时长及是否同站台（`Same track`），计算实际可用缓冲时间并分级预警（`换乘高危` / `换乘紧凑` / `换乘充裕`）。
4. **车站大屏智能切站 (Smart Station Board)**
   - 打开车站大屏时自动匹配当前时间段常看站点，并在顶部提供智能推荐站点快捷切换条。
5. **高频通勤工具增强**
   - **一键到站前 5 分钟下车提醒**：根据实时到达时间触发高优先级下车通知。
   - **行程分段比例进度条**：按各段步行与车次时长比例绘制彩色进度条。
   - **一键复制行程摘要**：导出包含车次、起止时间与站台号（`Spor`）的文本摘要。
6. **UI 优化**
   - 提升液态毛玻璃底栏通透度，改用外置阴影（`BlurStyle.outer`）消除底层暗色遮挡。

---

### 🇬🇧 English
1. **On-Device Smart Commute Prediction**: Predicts your likely destination and return commute using a local circular time kernel, day-of-week patterns, recency decay, and GPS proximity.
2. **Online Trip Preference Ranking**: Learns your transit preferences (duration, transfers, walking, Metro/S-tog/Train/Bus) and highlights the `⚡ Smart Pick` with a one-tap `Smart Rank` sort toggle.
3. **Transfer Risk Analyzer**: Evaluates real-time delays, walking transfers, and platform changes to warn about tight or risky connections.
4. **Smart Station Board**: Automatically selects and suggests your usual stations based on time of day and location.
5. **Commuter Utilities**: Added 1-tap `Alight Alarm (-5m)`, visual leg duration proportion bars, and 1-tap `Copy Trip` itinerary sharing.
6. **UI Refinement**: Higher transparency for the Liquid Glass bottom navigation bar.

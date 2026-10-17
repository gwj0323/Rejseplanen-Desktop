## v1.2.5 更新内容 / What's New

### 🇨🇳 中文
- **界面文案自然化润色**：全面优化中 / 英 / 丹三语选项与提示文案（如“出行习惯”、“悬浮半透明 / 经典固定”底栏、“跟随系统壁纸”等），去除生硬的机翻与技术术语腔调。
- **安全性加固**：
  - 所有网络异常提示自动脱敏 `accessId`，防止断网或异常时在错误弹窗中暴露密钥。
  - 强制校检并归一化 `https://` 加密接口地址，移除冗余配置字段。
- **性能与体验优化**：
  - 路线查询支持起点与终点 HAFAS 站点 ID 并行解析，缩短首次搜索耗时。
  - 站点缓存增加容量上限保护，设置页输入框改为提交时保存，避免输入卡顿。

### 🇬🇧 English
- **Natural UI Copy Polish**: Refined Chinese, English, and Danish UI labels, notifications, and settings descriptions (e.g., *Commute Habits*, *Floating / Classic* navigation bar, *Match Wallpaper*) for a cleaner, native feel.
- **Security Hardening**:
  - Automatically redacts `accessId` from network error messages.
  - Enforces `https://` across all API endpoints and removes duplicate key storage.
- **Performance Improvements**:
  - Parallelized origin and destination HAFAS station ID resolution for faster route searches.
  - Added bounded station ID caching and decoupled ML weight persistence from general settings saves.

### 🇩🇰 Dansk
- **Sproglig finpudsning**: Mere naturlige og kortfattede tekster på tværs af dansk, engelsk og kinesisk (bl.a. *Rejsevaner*, *Svævende / Klassisk* bundlinje og *Følg baggrundsfarve*).
- **Sikkerhed & Ydeevne**:
  - Automatisk sløring af `accessId` ved netværksfejl og tvungen `https://`-forbindelse.
  - Hurtigere rutesøgning via parallel stationsopslag samt optimeret hukommelses- og indstillingshåndtering.

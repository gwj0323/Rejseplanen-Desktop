## v1.2.3 更新内容 / What's New

### ⚠️ 重要安全与升级说明 (Important Security & Upgrade Notice)
* **发布签名密钥全面轮换**：为彻底防范供应链与签名冒用风险，本次版本启用了全新的独立正式发布密钥，旧密钥已永久废弃。
* **升级提示**：由于签名证书更换，已安装 `v1.2.2` 或更早版本的 Android 用户在升级时系统会提示签名不匹配，**请先卸载旧版后再安装 v1.2.3**（安装新版后未来所有版本可恢复正常覆盖升级）。

---

### 🇨🇳 中文
- **发布签名安全加固**：淘汰并彻底作废历史构建密钥，全面采用高强度 2048 位独立 RSA 证书通过 GitHub Actions Secrets 加密签名，防范侧载伪造与供应链风险。
- **CI 流水线最小权限隔离**：收紧 GitHub Actions 工作流全局权限为只读，PR 触发的构建彻底剥离签名材料。
- **日志敏感信息脱敏**：Release 生产环境静音 `debugPrint` 控制台与 Logcat 输出，移除了所有请求 URL 中关于 `accessId` 以及 GPS 经纬度坐标的日志输出。
- **UI 与异常防御**：对桌面端富文本显示增加 HTML 转义防护，修复 Artifact 清理边界与目录白名单。

### 🇬🇧 English
- **Release Signing Key Rotation**: The release signing certificate has been completely rotated to a fresh, independent 2048-bit RSA key securely managed via GitHub Secrets. (Existing users upgrading from `<=1.2.2` must uninstall the old version first before installing v1.2.3).
- **CI Least Privilege**: Tightened workflow permissions to read-only; pull request builds are strictly isolated and never touch release signing secrets.
- **Log Privacy Hardening**: Silenced `debugPrint` in Release mode, fully removing `accessId` tokens and GPS coordinates from system log outputs.
- **Security & Stability Refinements**: Added HTML escaping to dynamic desktop dialogs, clamped artifact retention bounds, and restricted iOS permissions.

### 🇩🇰 Dansk
- **Sikkerhedsnøgle-opdatering**: Signeringscertifikatet er blevet udskiftet med en helt ny RSA-nøgle for maksimal sikkerhed. (Brugere med version `<=1.2.2` skal afinstallere den gamle version først).
- **Log- og databeskyttelse**: Fjernet API-nøgle og GPS-koordinater fra app-logs og slået debug-udskrifter fra i produktionsbyg.
- **CI-sikkerhed**: Strammet rettigheder i GitHub Actions til læseadgang og isoleret PR-byg fra udgivelsesnøgler.

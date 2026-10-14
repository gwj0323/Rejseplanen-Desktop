import webbrowser
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QFrame
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal
from qfluentwidgets import (
    TitleLabel, CaptionLabel, SubtitleLabel, StrongBodyLabel, BodyLabel,
    CardWidget, LineEdit, PasswordLineEdit, PrimaryPushButton, PushButton,
    SwitchButton, ComboBox, IndeterminateProgressBar, InfoBar, InfoBarPosition,
    setTheme, Theme, FluentIcon as FIF, SmoothScrollArea
)
from api.client import api_client
from config import config
from i18n import t, I18n

class ConnTestThread(QThread):
    finished = pyqtSignal(bool, str)

    def __init__(self, key: str, url: str):
        super().__init__()
        self.key = key
        self.url = url

    def run(self):
        success, msg = api_client.test_connection(api_key=self.key, base_url=self.url)
        self.finished.emit(success, msg)

class SettingsView(QWidget):
    """WinUI 3 Settings View with instant auto-save and live API diagnostics."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("SettingsView")
        
        self._active_workers = set()
        self._current_worker = None
        
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(28, 20, 28, 20)
        main_layout.setSpacing(16)
        
        # Header
        self.title_lbl = TitleLabel(t("settings_title"))
        main_layout.addWidget(self.title_lbl)
        
        scroll_area = SmoothScrollArea(self)
        scroll_area.setWidgetResizable(True)
        scroll_area.setFrameShape(QFrame.Shape.NoFrame)
        scroll_area.enableTransparentBackground()
        
        content = QWidget()
        self.content_layout = QVBoxLayout(content)
        self.content_layout.setContentsMargins(0, 0, 12, 0)
        self.content_layout.setSpacing(16)
        
        # --- Group 1: API Configuration & Live Status ---
        self.api_group_card = CardWidget()
        api_layout = QVBoxLayout(self.api_group_card)
        api_layout.setContentsMargins(20, 16, 20, 16)
        api_layout.setSpacing(12)
        
        self.api_group_title = SubtitleLabel(t("settings_api_group"))
        api_layout.addWidget(self.api_group_title)
        
        # Status Diagnostic Box
        self.status_box = QFrame()
        self.status_box.setStyleSheet("background: rgba(128,128,128,0.08); border-radius: 6px; padding: 10px;")
        s_box_layout = QVBoxLayout(self.status_box)
        s_box_layout.setContentsMargins(10, 8, 10, 8)
        s_box_layout.setSpacing(4)
        
        self.diag_key_lbl = CaptionLabel("")
        self.diag_mode_lbl = CaptionLabel("")
        self.diag_conn_lbl = CaptionLabel("")
        s_box_layout.addWidget(self.diag_key_lbl)
        s_box_layout.addWidget(self.diag_mode_lbl)
        s_box_layout.addWidget(self.diag_conn_lbl)
        api_layout.addWidget(self.status_box)
        
        # API Key (accessId)
        self.key_lbl = StrongBodyLabel(t("settings_api_key_label"))
        api_layout.addWidget(self.key_lbl)
        
        key_row = QHBoxLayout()
        self.key_edit = PasswordLineEdit(self)
        self.key_edit.setPlaceholderText(t("settings_api_key_placeholder"))
        self.key_edit.setText(config.api_key)
        self.key_edit.setClearButtonEnabled(True)
        self.key_edit.textChanged.connect(self._on_key_edited)
        key_row.addWidget(self.key_edit, 1)
        
        self.test_conn_btn = PushButton(FIF.SYNC, t("settings_test_conn_btn"), self)
        self.test_conn_btn.clicked.connect(self._test_connection)
        key_row.addWidget(self.test_conn_btn)
        api_layout.addLayout(key_row)
        
        self.key_desc = CaptionLabel(t("settings_api_key_desc"))
        self.key_desc.setStyleSheet("color: gray;")
        self.key_desc.setWordWrap(True)
        api_layout.addWidget(self.key_desc)
        
        # Portal link button
        labs_row = QHBoxLayout()
        self.labs_btn = PushButton(FIF.SHARE, t("settings_labs_link_btn"), self)
        self.labs_btn.clicked.connect(lambda: webbrowser.open("https://labs.rejseplanen.dk/"))
        labs_row.addWidget(self.labs_btn)
        labs_row.addStretch()
        api_layout.addLayout(labs_row)
        
        api_sep = QFrame()
        api_sep.setFrameShape(QFrame.Shape.HLine)
        api_sep.setStyleSheet("color: rgba(128,128,128,0.15);")
        api_layout.addWidget(api_sep)
        
        # Base URL
        self.url_lbl = StrongBodyLabel(t("settings_base_url_label"))
        api_layout.addWidget(self.url_lbl)
        
        self.url_edit = LineEdit(self)
        self.url_edit.setText(config.base_url)
        self.url_edit.setClearButtonEnabled(True)
        self.url_edit.textChanged.connect(self._on_url_edited)
        api_layout.addWidget(self.url_edit)
        
        self.url_desc = CaptionLabel(t("settings_base_url_desc"))
        self.url_desc.setStyleSheet("color: gray;")
        api_layout.addWidget(self.url_desc)
        
        # Mock Fallback Switch
        mock_row = QHBoxLayout()
        mock_box = QVBoxLayout()
        mock_box.setSpacing(2)
        self.mock_lbl = StrongBodyLabel(t("settings_mock_fallback_label"))
        self.mock_desc = CaptionLabel(t("settings_mock_fallback_desc"))
        self.mock_desc.setStyleSheet("color: gray;")
        mock_box.addWidget(self.mock_lbl)
        mock_box.addWidget(self.mock_desc)
        mock_row.addLayout(mock_box, 1)
        
        self.mock_switch = SwitchButton(self)
        self.mock_switch.setChecked(config.mock_fallback)
        self.mock_switch.checkedChanged.connect(self._on_mock_changed)
        mock_row.addWidget(self.mock_switch)
        api_layout.addLayout(mock_row)
        
        self.content_layout.addWidget(self.api_group_card)
        
        # Progress Bar for Test Connection
        self.progress_bar = IndeterminateProgressBar(self)
        self.progress_bar.setVisible(False)
        self.content_layout.addWidget(self.progress_bar)
        
        # --- Group 2: Appearance & Language ---
        self.pref_group_card = CardWidget()
        pref_layout = QVBoxLayout(self.pref_group_card)
        pref_layout.setContentsMargins(20, 16, 20, 16)
        pref_layout.setSpacing(12)
        
        self.pref_group_title = SubtitleLabel(t("settings_appearance_group"))
        pref_layout.addWidget(self.pref_group_title)
        
        # Language Selector
        lang_row = QHBoxLayout()
        self.lang_lbl = StrongBodyLabel(t("settings_lang_label"))
        lang_row.addWidget(self.lang_lbl)
        lang_row.addStretch()
        
        self.lang_combo = ComboBox(self)
        self.lang_combo.addItems(["简体中文 (Simplified Chinese)", "English", "Dansk (Danish)"])
        lang_map = {"zh_CN": 0, "en_US": 1, "da_DK": 2}
        self.lang_combo.setCurrentIndex(lang_map.get(config.language, 0))
        self.lang_combo.currentIndexChanged.connect(self._on_language_changed)
        lang_row.addWidget(self.lang_combo)
        pref_layout.addLayout(lang_row)
        
        pref_sep = QFrame()
        pref_sep.setFrameShape(QFrame.Shape.HLine)
        pref_sep.setStyleSheet("color: rgba(128,128,128,0.15);")
        pref_layout.addWidget(pref_sep)
        
        # Theme Selector
        theme_row = QHBoxLayout()
        self.theme_lbl = StrongBodyLabel(t("settings_theme_label"))
        theme_row.addWidget(self.theme_lbl)
        theme_row.addStretch()
        
        self.theme_combo = ComboBox(self)
        self.theme_combo.addItems([t("theme_auto"), t("theme_light"), t("theme_dark")])
        theme_map = {"Auto": 0, "Light": 1, "Dark": 2}
        self.theme_combo.setCurrentIndex(theme_map.get(config.theme, 0))
        self.theme_combo.currentIndexChanged.connect(self._on_theme_changed)
        theme_row.addWidget(self.theme_combo)
        pref_layout.addLayout(theme_row)
        
        self.content_layout.addWidget(self.pref_group_card)
        
        # --- Group 3: About Application ---
        self.about_group_card = CardWidget()
        about_layout = QVBoxLayout(self.about_group_card)
        about_layout.setContentsMargins(20, 16, 20, 16)
        about_layout.setSpacing(8)
        
        self.about_title = SubtitleLabel(t("settings_about_group"))
        about_layout.addWidget(self.about_title)
        
        self.about_desc = BodyLabel(t("settings_about_desc"))
        self.about_desc.setStyleSheet("color: gray;")
        about_layout.addWidget(self.about_desc)
        
        self.about_author = CaptionLabel(t("settings_about_author"))
        self.about_author.setStyleSheet("color: gray;")
        about_layout.addWidget(self.about_author)
        
        ver_lbl = CaptionLabel("Version 1.0.2 | Rejseplanen API 2.0")
        ver_lbl.setStyleSheet("color: #0078D4;")
        about_layout.addWidget(ver_lbl)
        
        self.content_layout.addWidget(self.about_group_card)
        
        # Save Button Row
        save_row = QHBoxLayout()
        save_row.addStretch()
        self.save_btn = PrimaryPushButton(FIF.SAVE, t("settings_save_btn"), self)
        self.save_btn.setFixedHeight(36)
        self.save_btn.clicked.connect(self.save_settings)
        save_row.addWidget(self.save_btn)
        self.content_layout.addLayout(save_row)
        
        self.content_layout.addStretch()
        scroll_area.setWidget(content)
        main_layout.addWidget(scroll_area, 1)
        
        I18n.add_listener(self.update_i18n)
        self.update_status_display()

    def update_status_display(self):
        """Update live diagnostic status indicators."""
        k = config.api_key
        key_label = t("diag_key_label")
        if k:
            masked = k[:3] + "*" * (max(0, len(k) - 6)) + k[-3:] if len(k) > 6 else "***"
            desc = t("diag_key_configured", masked=masked)
            self.diag_key_lbl.setText(f"🔑 <b>{key_label}:</b> <span style='color:#10B981;'>{desc}</span>")
        else:
            desc = t("diag_key_missing")
            self.diag_key_lbl.setText(f"🔑 <b>{key_label}:</b> <span style='color:#EF4444;'>{desc}</span>")
            
        mode_label = t("diag_mode_label")
        if not k:
            self.diag_mode_lbl.setText(f"⚙️ <b>{mode_label}:</b> <span style='color:#F59E0B;'>{t('diag_mode_mock')}</span>")
        elif config.mock_fallback:
            self.diag_mode_lbl.setText(f"⚙️ <b>{mode_label}:</b> <span style='color:#10B981;'>{t('diag_mode_live_fallback')}</span>")
        else:
            self.diag_mode_lbl.setText(f"⚙️ <b>{mode_label}:</b> <span style='color:#10B981;'>{t('diag_mode_live_strict')}</span>")
            
        conn_label = t("diag_conn_label")
        if api_client.last_status == "ok":
            self.diag_conn_lbl.setText(f"📡 <b>{conn_label}:</b> <span style='color:#10B981;'>{t('diag_conn_ok_short')}</span>")
        elif api_client.last_status == "error":
            err = api_client.last_error or "Error"
            self.diag_conn_lbl.setText(f"📡 <b>{conn_label}:</b> <span style='color:#EF4444;'>{err}</span>")
        else:
            self.diag_conn_lbl.setText(f"📡 <b>{conn_label}:</b> {t('diag_conn_none')}")

    def _on_key_edited(self, text: str):
        config.api_key = text.strip()
        self.update_status_display()

    def _on_url_edited(self, text: str):
        config.base_url = text.strip()
        self.update_status_display()

    def _on_mock_changed(self, checked: bool):
        config.mock_fallback = checked
        self.update_status_display()

    def _test_connection(self):
        key = self.key_edit.text().strip()
        url = self.url_edit.text().strip()
        
        # Save immediately
        config.api_key = key
        config.base_url = url
        self.update_status_display()
        
        if not key:
            InfoBar.warning(
                title=t("error"),
                content=t("conn_no_key"),
                position=InfoBarPosition.TOP,
                parent=self.window()
            )
            return
            
        self.progress_bar.setVisible(True)
        self.test_conn_btn.setEnabled(False)
        
        if self._current_worker is not None and self._current_worker.isRunning():
            try:
                self._current_worker.finished.disconnect()
            except Exception:
                pass
                
        worker = ConnTestThread(key, url)
        self._current_worker = worker
        self._active_workers.add(worker)
        
        def on_finished(success, msg):
            self._active_workers.discard(worker)
            worker.deleteLater()
            if self._current_worker is worker:
                self._current_worker = None
                self._on_conn_tested(success, msg)
                
        worker.finished.connect(on_finished)
        worker.start()

    def _on_conn_tested(self, success: bool, msg: str):
        self.progress_bar.setVisible(False)
        self.test_conn_btn.setEnabled(True)
        self.update_status_display()
        
        if success:
            InfoBar.success(
                title=t("success"),
                content=msg,
                position=InfoBarPosition.TOP,
                duration=4000,
                parent=self.window()
            )
        else:
            InfoBar.error(
                title=t("error"),
                content=msg,
                position=InfoBarPosition.TOP,
                duration=6000,
                parent=self.window()
            )

    def _on_language_changed(self, idx: int):
        langs = ["zh_CN", "en_US", "da_DK"]
        if 0 <= idx < len(langs):
            config.language = langs[idx]
            I18n.notify_change()

    def _on_theme_changed(self, idx: int):
        themes = ["Auto", "Light", "Dark"]
        if 0 <= idx < len(themes):
            chosen = themes[idx]
            config.theme = chosen
            if chosen == "Light":
                setTheme(Theme.LIGHT)
            elif chosen == "Dark":
                setTheme(Theme.DARK)
            else:
                setTheme(Theme.AUTO)

    def save_settings(self):
        config.api_key = self.key_edit.text().strip()
        config.base_url = self.url_edit.text().strip()
        config.mock_fallback = self.mock_switch.isChecked()
        self.update_status_display()
        
        InfoBar.success(
            title=t("success"),
            content=t("settings_saved_msg"),
            position=InfoBarPosition.TOP,
            duration=2500,
            parent=self.window()
        )

    def update_i18n(self):
        self.title_lbl.setText(t("settings_title"))
        self.api_group_title.setText(t("settings_api_group"))
        self.key_lbl.setText(t("settings_api_key_label"))
        self.key_edit.setPlaceholderText(t("settings_api_key_placeholder"))
        self.test_conn_btn.setText(t("settings_test_conn_btn"))
        self.key_desc.setText(t("settings_api_key_desc"))
        self.labs_btn.setText(t("settings_labs_link_btn"))
        self.url_lbl.setText(t("settings_base_url_label"))
        self.url_desc.setText(t("settings_base_url_desc"))
        self.mock_lbl.setText(t("settings_mock_fallback_label"))
        self.mock_desc.setText(t("settings_mock_fallback_desc"))
        self.pref_group_title.setText(t("settings_appearance_group"))
        self.lang_lbl.setText(t("settings_lang_label"))
        self.theme_lbl.setText(t("settings_theme_label"))
        
        self.theme_combo.blockSignals(True)
        idx = self.theme_combo.currentIndex()
        self.theme_combo.clear()
        self.theme_combo.addItems([t("theme_auto"), t("theme_light"), t("theme_dark")])
        self.theme_combo.setCurrentIndex(idx)
        self.theme_combo.blockSignals(False)
        
        self.about_title.setText(t("settings_about_group"))
        self.about_desc.setText(t("settings_about_desc"))
        self.about_author.setText(t("settings_about_author"))
        self.save_btn.setText(t("settings_save_btn"))
        self.update_status_display()

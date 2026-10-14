from typing import Optional
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QFrame
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QTimer
from qfluentwidgets import (
    TitleLabel, CaptionLabel, StrongBodyLabel, SubtitleLabel,
    CardWidget, PrimaryPushButton, PushButton, ToolButton, TransparentToolButton,
    RadioButton, SwitchButton, IndeterminateProgressBar, InfoBar, InfoBarPosition,
    FluentIcon as FIF
)
from ui.components.station_picker import StationPicker
from ui.components.departure_table import DepartureTable
from ui.components.badge import StatusBadge
from api.client import api_client
from config import config
from i18n import t, I18n

class BoardFetchThread(QThread):
    finished = pyqtSignal(list, bool, object)  # data, is_mock, error_msg
    failed = pyqtSignal(str)

    def __init__(self, station_id: str, is_arrival: bool):
        super().__init__()
        self.station_id = station_id
        self.is_arrival = is_arrival

    def run(self):
        try:
            if self.is_arrival:
                data, is_mock, err = api_client.get_arrival_board(self.station_id)
            else:
                data, is_mock, err = api_client.get_departure_board(self.station_id)
            self.finished.emit(data, is_mock, err)
        except Exception as e:
            self.failed.emit(str(e))

class BoardView(QWidget):
    """WinUI 3 Live Departure and Arrival Board View."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("BoardView")
        self._current_station_id = "8600626"
        self._current_station_name = "København H"
        
        # Thread safety management
        self._active_workers = set()
        self._current_worker = None
        
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(28, 20, 28, 20)
        main_layout.setSpacing(16)
        
        # Header Row
        header_row = QHBoxLayout()
        self.title_lbl = TitleLabel(t("board_title"))
        header_row.addWidget(self.title_lbl)
        header_row.addStretch()
        
        self.mode_badge = StatusBadge(t("live_badge") if config.api_key else t("mock_badge"),
                                      status="normal" if config.api_key else "minor_delay")
        header_row.addWidget(self.mode_badge)
        main_layout.addLayout(header_row)
        
        # Control Card
        control_card = CardWidget(self)
        control_layout = QVBoxLayout(control_card)
        control_layout.setContentsMargins(20, 14, 20, 14)
        control_layout.setSpacing(12)
        
        # Top Row: Station Picker & Quick Actions
        ctrl_top = QHBoxLayout()
        ctrl_top.setSpacing(10)
        
        self.station_lbl = StrongBodyLabel(f"{t('board_station')}:")
        ctrl_top.addWidget(self.station_lbl)
        
        self.station_picker = StationPicker(placeholder=t("board_station_placeholder"))
        self.station_picker.set_station({"id": self._current_station_id, "name": self._current_station_name}, emit_signal=False)
        self.station_picker.stationSelected.connect(self._on_station_selected)
        ctrl_top.addWidget(self.station_picker, 1)
        
        # Add to Favorites button
        self.fav_btn = TransparentToolButton(FIF.HEART, self)
        self.fav_btn.setToolTip(t("board_add_fav"))
        self.fav_btn.clicked.connect(self._on_fav_station)
        ctrl_top.addWidget(self.fav_btn)
        
        # Board Mode Switch: Departure vs Arrival
        self.radio_dep = RadioButton(t("board_type_dep"), self)
        self.radio_dep.setChecked(True)
        self.radio_dep.toggled.connect(self._on_mode_toggled)
        self.radio_arr = RadioButton(t("board_type_arr"), self)
        ctrl_top.addWidget(self.radio_dep)
        ctrl_top.addWidget(self.radio_arr)
        
        # Auto-refresh switch
        self.auto_refresh_lbl = CaptionLabel(t("board_auto_refresh"))
        self.auto_refresh_switch = SwitchButton(self)
        self.auto_refresh_switch.setChecked(False)
        self.auto_refresh_switch.checkedChanged.connect(self._toggle_auto_refresh)
        ctrl_top.addWidget(self.auto_refresh_lbl)
        ctrl_top.addWidget(self.auto_refresh_switch)
        
        # Refresh button
        self.refresh_btn = PrimaryPushButton(FIF.SYNC, t("board_refresh"), self)
        self.refresh_btn.setFixedHeight(34)
        self.refresh_btn.clicked.connect(self.load_board)
        ctrl_top.addWidget(self.refresh_btn)
        
        control_layout.addLayout(ctrl_top)
        
        # Bottom Row: Quick Station Hub Pills
        quick_row = QHBoxLayout()
        quick_row.setSpacing(6)
        self.quick_lbl = CaptionLabel(f"{t('trip_quick_select')}: ")
        self.quick_lbl.setStyleSheet("color: gray;")
        quick_row.addWidget(self.quick_lbl)
        
        hubs = [
            ("København H", "8600626"),
            ("Nørreport St.", "8600646"),
            ("Kongens Nytorv", "8603308"),
            ("CPH Lufthavn", "8600858"),
            ("Østerport St.", "8600650"),
            ("Aarhus H", "8600053"),
            ("Odense St.", "8600512")
        ]
        for name, sid in hubs:
            btn = PushButton(name, self)
            btn.setFixedHeight(24)
            btn.clicked.connect(lambda ch, s_name=name, s_id=sid: self.select_station(s_id, s_name))
            quick_row.addWidget(btn)
        quick_row.addStretch()
        control_layout.addLayout(quick_row)
        
        main_layout.addWidget(control_card)
        
        # Progress Bar
        self.progress_bar = IndeterminateProgressBar(self)
        self.progress_bar.setVisible(False)
        main_layout.addWidget(self.progress_bar)
        
        # Board Table
        self.table_widget = DepartureTable(is_arrival=False, parent=self)
        main_layout.addWidget(self.table_widget, 1)
        
        # Auto refresh timer
        self.refresh_timer = QTimer(self)
        self.refresh_timer.setInterval(self._refresh_interval_ms())  # from settings
        self.refresh_timer.timeout.connect(self.load_board)
        
        I18n.add_listener(self.update_i18n)
        
        # Initial load
        self.load_board()

    def select_station(self, station_id: str, station_name: str):
        self._current_station_id = station_id
        self._current_station_name = station_name
        self.station_picker.set_station({"id": station_id, "name": station_name}, emit_signal=False)
        self.load_board()

    def _on_station_selected(self, station: dict):
        sid = station.get("id", "")
        sname = station.get("name", "")
        if sid and (sid != self._current_station_id or sname != self._current_station_name):
            self._current_station_id = sid
            self._current_station_name = sname
            self.load_board()

    def _on_mode_toggled(self):
        is_arr = self.radio_arr.isChecked()
        self.table_widget.is_arrival = is_arr
        self.table_widget.update_headers()
        self.load_board()

    @staticmethod
    def _refresh_interval_ms() -> int:
        try:
            seconds = int(config.get("auto_refresh_interval", 30))
        except (TypeError, ValueError):
            seconds = 30
        return max(5, seconds) * 1000

    def _toggle_auto_refresh(self, checked: bool):
        if checked:
            # Pick up setting changes each time the switch is enabled.
            self.refresh_timer.setInterval(self._refresh_interval_ms())
            self.refresh_timer.start()
        else:
            self.refresh_timer.stop()

    def _on_fav_station(self):
        st = {"id": self._current_station_id, "name": self._current_station_name, "type": "ST"}
        added = config.add_favorite_station(st)
        if added:
            InfoBar.success(
                title=t("success"),
                content=t("saved_to_fav"),
                orient=Qt.Orientation.Horizontal,
                isClosable=True,
                position=InfoBarPosition.TOP,
                duration=2500,
                parent=self.window()
            )
        else:
            InfoBar.info(
                title=t("info"),
                content=t("already_in_fav"),
                orient=Qt.Orientation.Horizontal,
                isClosable=True,
                position=InfoBarPosition.TOP,
                duration=2000,
                parent=self.window()
            )

    def load_board(self):
        if not self._current_station_id:
            return
            
        self.progress_bar.setVisible(True)
        self.refresh_btn.setEnabled(False)
        is_arr = self.radio_arr.isChecked()
        
        # Disconnect previous worker signals to prevent race conditions
        if self._current_worker is not None and self._current_worker.isRunning():
            try:
                self._current_worker.finished.disconnect()
                self._current_worker.failed.disconnect()
            except Exception:
                pass
                
        worker = BoardFetchThread(self._current_station_id, is_arr)
        self._current_worker = worker
        self._active_workers.add(worker)
        
        def on_finished(data, is_mock, err_msg):
            self._active_workers.discard(worker)
            worker.deleteLater()
            if self._current_worker is worker:
                self._current_worker = None
                self._on_board_loaded(data, is_mock, err_msg)

        def on_failed(err):
            self._active_workers.discard(worker)
            worker.deleteLater()
            if self._current_worker is worker:
                self._current_worker = None
                self._on_board_failed(err)

        worker.finished.connect(on_finished)
        worker.failed.connect(on_failed)
        worker.start()

    def _on_board_loaded(self, data: list, is_mock: bool, err_msg: Optional[str] = None):
        self.progress_bar.setVisible(False)
        self.refresh_btn.setEnabled(True)
        self.table_widget.set_data(data)
        
        has_key = bool(config.api_key.strip())
        
        if is_mock:
            if has_key and err_msg:
                self.mode_badge.update_status(f"{t('mock_badge')} (API错误)", status="minor_delay")
                self.mode_badge.setToolTip(f"官方 API 报错: {err_msg}")
                InfoBar.warning(
                    title="API 调用未成功，已自动降级至模拟数据",
                    content=f"官方返回: {err_msg}\n请在「设置」页测试 accessId 是否有效或通过审核。",
                    position=InfoBarPosition.TOP,
                    duration=5000,
                    parent=self.window()
                )
            else:
                self.mode_badge.update_status(t("mock_badge"), status="minor_delay")
                self.mode_badge.setToolTip("未检测到有效 API Key，当前使用演示模拟数据")
        else:
            self.mode_badge.update_status(t("live_badge"), status="normal")
            self.mode_badge.setToolTip("正在使用 Rejseplanen 官方实时 API 数据")
            if not data and err_msg:
                InfoBar.error(
                    title=t("error"),
                    content=f"加载车次失败: {err_msg}",
                    position=InfoBarPosition.TOP,
                    duration=5000,
                    parent=self.window()
                )

    def _on_board_failed(self, err: str):
        self.progress_bar.setVisible(False)
        self.refresh_btn.setEnabled(True)
        InfoBar.error(
            title=t("error"),
            content=err,
            orient=Qt.Orientation.Horizontal,
            isClosable=True,
            position=InfoBarPosition.TOP,
            duration=3500,
            parent=self.window()
        )

    def update_i18n(self):
        self.title_lbl.setText(t("board_title"))
        self.station_lbl.setText(f"{t('board_station')}:")
        self.station_picker.set_placeholder(t("board_station_placeholder"))
        self.radio_dep.setText(t("board_type_dep"))
        self.radio_arr.setText(t("board_type_arr"))
        self.auto_refresh_lbl.setText(t("board_auto_refresh"))
        self.refresh_btn.setText(t("board_refresh"))
        self.quick_lbl.setText(f"{t('trip_quick_select')}: ")
        self.fav_btn.setToolTip(t("board_add_fav"))
        
        # Update live badge
        is_live = bool(config.api_key.strip())
        self.mode_badge.update_status(t("live_badge") if is_live else t("mock_badge"),
                                      status="normal" if is_live else "minor_delay")
                                      
        self.table_widget.update_i18n()

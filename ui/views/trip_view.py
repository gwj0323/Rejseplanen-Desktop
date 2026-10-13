from typing import Optional
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QFrame
)
from PyQt6.QtCore import Qt, QDate, QTime, QThread, pyqtSignal
from qfluentwidgets import (
    TitleLabel, CaptionLabel, SubtitleLabel, StrongBodyLabel, BodyLabel,
    CardWidget, PrimaryPushButton, PushButton, ToolButton, TransparentToolButton,
    CheckBox, RadioButton, CalendarPicker, TimePicker,
    IndeterminateProgressBar, InfoBar, InfoBarPosition, FluentIcon as FIF,
    SmoothScrollArea
)
from ui.components.station_picker import StationPicker
from ui.components.trip_card import TripCard
from ui.components.badge import StatusBadge
from api.client import api_client
from api.mock_data import STATIONS
from config import config
from i18n import t, I18n

class TripSearchThread(QThread):
    finished = pyqtSignal(list, bool, object)  # results, is_mock, error_msg
    failed = pyqtSignal(str)

    def __init__(self, origin_id: str, dest_id: str, date_str: str, time_str: str, search_arr: bool, modes: dict):
        super().__init__()
        self.origin_id = origin_id
        self.dest_id = dest_id
        self.date_str = date_str
        self.time_str = time_str
        self.search_arr = search_arr
        self.modes = modes

    def run(self):
        try:
            trips, is_mock, err = api_client.get_trips(
                origin_id=self.origin_id,
                dest_id=self.dest_id,
                date_str=self.date_str,
                time_str=self.time_str,
                search_for_arrival=self.search_arr,
                use_bus=self.modes.get("bus", True),
                use_train=self.modes.get("train", True),
                use_metro=self.modes.get("metro", True)
            )
            self.finished.emit(trips, is_mock, err)
        except Exception as e:
            self.failed.emit(str(e))

class TripView(QWidget):
    """WinUI 3 Journey Planner View."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("TripView")
        
        self._active_workers = set()
        self._current_worker = None
        
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(28, 20, 28, 20)
        main_layout.setSpacing(16)
        
        # Header Row
        header_row = QHBoxLayout()
        self.title_lbl = TitleLabel(t("trip_title"))
        header_row.addWidget(self.title_lbl)
        header_row.addStretch()
        
        self.mode_badge = StatusBadge(t("live_badge") if config.api_key else t("mock_badge"),
                                      status="normal" if config.api_key else "minor_delay")
        header_row.addWidget(self.mode_badge)
        main_layout.addLayout(header_row)
        
        # Query Card
        query_card = CardWidget(self)
        query_layout = QVBoxLayout(query_card)
        query_layout.setContentsMargins(20, 16, 20, 16)
        query_layout.setSpacing(14)
        
        # Row 1: Origin & Destination Inputs with Swap
        stations_row = QHBoxLayout()
        stations_row.setSpacing(10)
        
        # Origin
        orig_box = QVBoxLayout()
        orig_box.setSpacing(4)
        self.orig_lbl = StrongBodyLabel(t("trip_origin"))
        self.orig_picker = StationPicker(placeholder=t("trip_origin_placeholder"))
        orig_box.addWidget(self.orig_lbl)
        orig_box.addWidget(self.orig_picker)
        stations_row.addLayout(orig_box, 1)
        
        # Swap Button
        swap_box = QVBoxLayout()
        swap_box.addSpacing(22)
        self.swap_btn = ToolButton(FIF.SYNC, self)
        self.swap_btn.setToolTip(t("trip_swap"))
        self.swap_btn.clicked.connect(self._swap_stations)
        swap_box.addWidget(self.swap_btn)
        stations_row.addLayout(swap_box)
        
        # Destination
        dest_box = QVBoxLayout()
        dest_box.setSpacing(4)
        self.dest_lbl = StrongBodyLabel(t("trip_dest"))
        self.dest_picker = StationPicker(placeholder=t("trip_dest_placeholder"))
        dest_box.addWidget(self.dest_lbl)
        dest_box.addWidget(self.dest_picker)
        stations_row.addLayout(dest_box, 1)
        
        query_layout.addLayout(stations_row)
        
        # Row 2: Quick Station Pills
        quick_row = QHBoxLayout()
        quick_row.setSpacing(6)
        self.quick_lbl = CaptionLabel(f"{t('trip_quick_select')}: ")
        self.quick_lbl.setStyleSheet("color: gray;")
        quick_row.addWidget(self.quick_lbl)
        
        preset_hubs = [
            ("København H", "8600626"),
            ("Nørreport St.", "8600646"),
            ("CPH Lufthavn", "8600858"),
            ("Aarhus H", "8600053"),
            ("Odense St.", "8600512")
        ]
        for name, sid in preset_hubs:
            btn = PushButton(name, self)
            btn.setFixedHeight(26)
            btn.clicked.connect(lambda checked, s_name=name, s_id=sid: self._apply_quick_hub(s_name, s_id))
            quick_row.addWidget(btn)
            
        quick_row.addStretch()
        query_layout.addLayout(quick_row)
        
        # Separator
        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet("color: rgba(128,128,128,0.15);")
        query_layout.addWidget(sep)
        
        # Row 3: Date, Time & Search Options
        options_row = QHBoxLayout()
        options_row.setSpacing(12)
        
        self.date_picker = CalendarPicker(self)
        self.date_picker.setDate(QDate.currentDate())
        options_row.addWidget(self.date_picker)
        
        self.time_picker = TimePicker(self)
        self.time_picker.setTime(QTime.currentTime())
        options_row.addWidget(self.time_picker)
        
        self.radio_dep = RadioButton(t("trip_mode_dep"), self)
        self.radio_dep.setChecked(True)
        self.radio_arr = RadioButton(t("trip_mode_arr"), self)
        options_row.addWidget(self.radio_dep)
        options_row.addWidget(self.radio_arr)
        
        options_row.addStretch()
        
        # Mode Filters Checkboxes
        self.cb_train = CheckBox(t("filter_train"), self)
        self.cb_train.setChecked(True)
        self.cb_metro = CheckBox(t("filter_metro"), self)
        self.cb_metro.setChecked(True)
        self.cb_bus = CheckBox(t("filter_bus"), self)
        self.cb_bus.setChecked(True)
        options_row.addWidget(self.cb_train)
        options_row.addWidget(self.cb_metro)
        options_row.addWidget(self.cb_bus)
        
        # Search Button
        self.search_btn = PrimaryPushButton(FIF.SEARCH, t("trip_search"), self)
        self.search_btn.setFixedHeight(34)
        self.search_btn.clicked.connect(self.search_trips)
        options_row.addWidget(self.search_btn)
        
        query_layout.addLayout(options_row)
        main_layout.addWidget(query_card)
        
        # Progress Bar
        self.progress_bar = IndeterminateProgressBar(self)
        self.progress_bar.setVisible(False)
        main_layout.addWidget(self.progress_bar)
        
        # Results Header
        self.results_title = SubtitleLabel(t("trip_results"))
        main_layout.addWidget(self.results_title)
        
        # Results Scroll Area
        self.scroll_area = SmoothScrollArea(self)
        self.scroll_area.setWidgetResizable(True)
        self.scroll_area.setFrameShape(QFrame.Shape.NoFrame)
        self.scroll_area.enableTransparentBackground()
        
        self.results_widget = QWidget()
        self.results_layout = QVBoxLayout(self.results_widget)
        self.results_layout.setContentsMargins(0, 0, 10, 0)
        self.results_layout.setSpacing(12)
        
        self.scroll_area.setWidget(self.results_widget)
        main_layout.addWidget(self.scroll_area, 1)
        
        # Default preset values
        self.orig_picker.set_station({"id": "8600626", "name": "København H"}, emit_signal=False)
        self.dest_picker.set_station({"id": "8600646", "name": "Nørreport St."}, emit_signal=False)
        
        I18n.add_listener(self.update_i18n)

    def _swap_stations(self):
        orig = self.orig_picker.get_station()
        dest = self.dest_picker.get_station()
        self.orig_picker.set_station(dest, emit_signal=False)
        self.dest_picker.set_station(orig, emit_signal=False)

    def _apply_quick_hub(self, name: str, sid: str):
        orig = self.orig_picker.get_station()
        if not orig or not orig.get("name"):
            self.orig_picker.set_station({"id": sid, "name": name}, emit_signal=False)
        else:
            self.dest_picker.set_station({"id": sid, "name": name}, emit_signal=False)

    def search_trips(self):
        orig = self.orig_picker.get_station()
        dest = self.dest_picker.get_station()
        
        if not orig.get("id") or not dest.get("id"):
            InfoBar.warning(
                title=t("error"),
                content=t("trip_select_both_error"),
                orient=Qt.Orientation.Horizontal,
                isClosable=True,
                position=InfoBarPosition.TOP,
                duration=3000,
                parent=self.window()
            )
            return
            
        self.progress_bar.setVisible(True)
        self.search_btn.setEnabled(False)
        
        date_str = self.date_picker.date.toString("yyyy-MM-dd")
        time_str = self.time_picker.time.toString("HH:mm")
        search_arr = self.radio_arr.isChecked()
        modes = {
            "bus": self.cb_bus.isChecked(),
            "train": self.cb_train.isChecked(),
            "metro": self.cb_metro.isChecked()
        }
        
        # Save to recent searches
        config.add_recent_search({
            "type": "trip",
            "title": f"{orig.get('name')} → {dest.get('name')}",
            "origin": orig,
            "dest": dest,
            "time": time_str,
            "date": date_str
        })
        
        if self._current_worker is not None and self._current_worker.isRunning():
            try:
                self._current_worker.finished.disconnect()
                self._current_worker.failed.disconnect()
            except Exception:
                pass
                
        worker = TripSearchThread(
            origin_id=orig.get("id"),
            dest_id=dest.get("id"),
            date_str=date_str,
            time_str=time_str,
            search_arr=search_arr,
            modes=modes
        )
        self._current_worker = worker
        self._active_workers.add(worker)
        
        def on_finished(trips, is_mock, err_msg):
            self._active_workers.discard(worker)
            worker.deleteLater()
            if self._current_worker is worker:
                self._current_worker = None
                self._on_search_finished(trips, is_mock, err_msg)

        def on_failed(err):
            self._active_workers.discard(worker)
            worker.deleteLater()
            if self._current_worker is worker:
                self._current_worker = None
                self._on_search_failed(err)

        worker.finished.connect(on_finished)
        worker.failed.connect(on_failed)
        worker.start()

    def _on_search_finished(self, trips: list, is_mock: bool, err_msg: Optional[str] = None):
        self.progress_bar.setVisible(False)
        self.search_btn.setEnabled(True)
        
        while self.results_layout.count():
            item = self.results_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
                
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
        
        if not trips:
            if err_msg:
                InfoBar.error(
                    title=t("error"),
                    content=f"查询乘车方案失败: {err_msg}",
                    position=InfoBarPosition.TOP,
                    duration=5000,
                    parent=self.window()
                )
            no_res_lbl = BodyLabel(f"{t('trip_no_results')}" + (f"\n\n官方提示: {err_msg}" if err_msg else ""))
            no_res_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            self.results_layout.addWidget(no_res_lbl)
            return
            
        for trip in trips:
            card = TripCard(trip, self.results_widget)
            self.results_layout.addWidget(card)
        self.results_layout.addStretch()

    def _on_search_failed(self, error_msg: str):
        self.progress_bar.setVisible(False)
        self.search_btn.setEnabled(True)
        InfoBar.error(
            title=t("error"),
            content=error_msg,
            orient=Qt.Orientation.Horizontal,
            isClosable=True,
            position=InfoBarPosition.TOP,
            duration=3500,
            parent=self.window()
        )

    def set_route(self, origin: dict, dest: dict):
        self.orig_picker.set_station(origin, emit_signal=False)
        self.dest_picker.set_station(dest, emit_signal=False)
        self.search_trips()

    def update_i18n(self):
        self.title_lbl.setText(t("trip_title"))
        self.orig_lbl.setText(t("trip_origin"))
        self.dest_lbl.setText(t("trip_dest"))
        self.orig_picker.set_placeholder(t("trip_origin_placeholder"))
        self.dest_picker.set_placeholder(t("trip_dest_placeholder"))
        self.quick_lbl.setText(f"{t('trip_quick_select')}: ")
        self.radio_dep.setText(t("trip_mode_dep"))
        self.radio_arr.setText(t("trip_mode_arr"))
        self.cb_train.setText(t("filter_train"))
        self.cb_metro.setText(t("filter_metro"))
        self.cb_bus.setText(t("filter_bus"))
        self.search_btn.setText(t("trip_search"))
        self.results_title.setText(t("trip_results"))
        
        # Update live badge
        is_live = bool(config.api_key.strip())
        self.mode_badge.update_status(t("live_badge") if is_live else t("mock_badge"),
                                      status="normal" if is_live else "minor_delay")
                                      
        # Update existing trip cards
        for i in range(self.results_layout.count()):
            item = self.results_layout.itemAt(i)
            w = item.widget() if item else None
            if isinstance(w, TripCard):
                w.update_i18n()

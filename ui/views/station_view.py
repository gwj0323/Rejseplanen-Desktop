from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QFrame, QApplication
)
from PyQt6.QtCore import Qt, pyqtSignal, QThread
from qfluentwidgets import (
    TitleLabel, CaptionLabel, SubtitleLabel, StrongBodyLabel, BodyLabel,
    CardWidget, LineEdit, PrimaryPushButton, PushButton, ToolButton, TransparentToolButton,
    IndeterminateProgressBar, InfoBar, InfoBarPosition, FluentIcon as FIF,
    SmoothScrollArea
)
from ui.components.badge import TransitBadge, StatusBadge
from api.client import api_client
from api.mock_data import STATIONS
from config import config
from i18n import t, I18n

class StationSearchThread(QThread):
    finished = pyqtSignal(list, bool, object)  # results, is_mock, error_msg
    failed = pyqtSignal(str)

    def __init__(self, query: str):
        super().__init__()
        self.query = query

    def run(self):
        try:
            results, is_mock, err = api_client.search_locations(self.query)
            self.finished.emit(results, is_mock, err)
        except Exception as e:
            self.failed.emit(str(e))

class NearbyStopsThread(QThread):
    finished = pyqtSignal(list, bool, object)  # results, is_mock, error_msg
    failed = pyqtSignal(str)

    def __init__(self, lat: float, lon: float):
        super().__init__()
        self.lat = lat
        self.lon = lon

    def run(self):
        try:
            results, is_mock, err = api_client.nearby_stops(self.lat, self.lon)
            self.finished.emit(results, is_mock, err)
        except Exception as e:
            self.failed.emit(str(e))

class StationCard(CardWidget):
    """WinUI 3 Card representing a station with coordinates and actions."""
    viewBoardRequested = pyqtSignal(str, str) # id, name
    planTripRequested = pyqtSignal(str, str)  # id, name

    def __init__(self, station: dict, parent=None):
        super().__init__(parent)
        self.station = station
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 12, 16, 12)
        layout.setSpacing(8)
        
        # Header Row
        header_row = QHBoxLayout()
        name_lbl = StrongBodyLabel(station.get("name", "Unknown Station"))
        header_row.addWidget(name_lbl)
        
        sid = station.get("id", "")
        if sid:
            id_badge = CaptionLabel(f"ID: {sid}")
            id_badge.setStyleSheet("background: rgba(128,128,128,0.12); padding: 2px 6px; border-radius: 4px;")
            header_row.addWidget(id_badge)
            
        header_row.addStretch()
        layout.addLayout(header_row)
        
        # Coordinates & Details
        lat = station.get("lat")
        lon = station.get("lon")
        if lat and lon:
            coords_row = QHBoxLayout()
            coord_lbl = CaptionLabel(f"📍 GPS: {lat:.4f}, {lon:.4f}")
            coord_lbl.setStyleSheet("color: gray;")
            coords_row.addWidget(coord_lbl)
            
            dist = station.get("distance")
            if dist:
                dist_lbl = CaptionLabel(f"({dist}m)")
                dist_lbl.setStyleSheet("color: #0284C7;")
                coords_row.addWidget(dist_lbl)
                
            coords_row.addStretch()
            layout.addLayout(coords_row)
            
        # Action Buttons
        btn_row = QHBoxLayout()
        btn_row.setSpacing(8)
        
        self.dep_btn = PushButton(FIF.DATE_TIME, t("station_action_dep"), self)
        self.dep_btn.setFixedHeight(28)
        self.dep_btn.clicked.connect(lambda: self.viewBoardRequested.emit(sid, station.get("name", "")))
        btn_row.addWidget(self.dep_btn)
        
        self.plan_btn = PushButton(FIF.PIN, t("station_action_plan"), self)
        self.plan_btn.setFixedHeight(28)
        self.plan_btn.clicked.connect(lambda: self.planTripRequested.emit(sid, station.get("name", "")))
        btn_row.addWidget(self.plan_btn)
        
        self.fav_btn = TransparentToolButton(FIF.HEART, self)
        self.fav_btn.setToolTip(t("board_add_fav"))
        self.fav_btn.clicked.connect(self._on_fav)
        btn_row.addWidget(self.fav_btn)
        
        btn_row.addStretch()
        layout.addLayout(btn_row)

    def update_i18n(self):
        self.dep_btn.setText(t("station_action_dep"))
        self.plan_btn.setText(t("station_action_plan"))
        self.fav_btn.setToolTip(t("board_add_fav"))

    def _on_fav(self):
        st = {"id": self.station.get("id", ""), "name": self.station.get("name", ""), "type": "ST"}
        added = config.add_favorite_station(st)
        if added:
            InfoBar.success(
                title=t("success"),
                content=t("saved_to_fav"),
                orient=Qt.Orientation.Horizontal,
                isClosable=True,
                position=InfoBarPosition.TOP,
                duration=2000,
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

class StationView(QWidget):
    """WinUI 3 Stations and Stops Explorer View."""
    jumpToBoard = pyqtSignal(str, str)
    jumpToTrip = pyqtSignal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("StationView")
        
        # Thread safety management
        self._active_workers = set()
        self._current_worker = None
        
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(28, 20, 28, 20)
        main_layout.setSpacing(16)
        
        # Header
        self.title_lbl = TitleLabel(t("station_title"))
        main_layout.addWidget(self.title_lbl)
        
        # Search Card
        search_card = CardWidget(self)
        search_layout = QVBoxLayout(search_card)
        search_layout.setContentsMargins(20, 14, 20, 14)
        search_layout.setSpacing(12)
        
        # Search by name row
        name_row = QHBoxLayout()
        name_row.setSpacing(10)
        self.search_edit = LineEdit(self)
        self.search_edit.setPlaceholderText(t("station_search_placeholder"))
        self.search_edit.setClearButtonEnabled(True)
        self.search_edit.returnPressed.connect(self.search_by_name)
        name_row.addWidget(self.search_edit, 1)
        
        self.search_btn = PrimaryPushButton(FIF.SEARCH, t("station_search_btn"), self)
        self.search_btn.setFixedHeight(34)
        self.search_btn.clicked.connect(self.search_by_name)
        name_row.addWidget(self.search_btn)
        search_layout.addLayout(name_row)
        
        # Separator
        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet("color: rgba(128,128,128,0.15);")
        search_layout.addWidget(sep)
        
        # Nearby stops by coordinates row
        nearby_row = QHBoxLayout()
        nearby_row.setSpacing(10)
        self.nearby_lbl = StrongBodyLabel(t("station_nearby_title"))
        nearby_row.addWidget(self.nearby_lbl)
        
        self.lat_edit = LineEdit(self)
        self.lat_edit.setPlaceholderText("55.6761")
        self.lat_edit.setText("55.6761")
        self.lat_edit.setFixedWidth(100)
        nearby_row.addWidget(self.lat_edit)
        
        self.lon_edit = LineEdit(self)
        self.lon_edit.setPlaceholderText("12.5683")
        self.lon_edit.setText("12.5683")
        self.lon_edit.setFixedWidth(100)
        nearby_row.addWidget(self.lon_edit)
        
        self.nearby_btn = PushButton(FIF.PIN, t("station_find_nearby"), self)
        self.nearby_btn.clicked.connect(self.find_nearby)
        nearby_row.addWidget(self.nearby_btn)
        
        self.cph_chip = PushButton(t("station_preset_cph"), self)
        self.cph_chip.clicked.connect(lambda: self._set_coords(55.6761, 12.5683))
        nearby_row.addWidget(self.cph_chip)
        
        self.aarhus_chip = PushButton(t("station_preset_aarhus"), self)
        self.aarhus_chip.clicked.connect(lambda: self._set_coords(56.1504, 10.2038))
        nearby_row.addWidget(self.aarhus_chip)
        
        nearby_row.addStretch()
        search_layout.addLayout(nearby_row)
        main_layout.addWidget(search_card)
        
        # Progress Bar
        self.progress_bar = IndeterminateProgressBar(self)
        self.progress_bar.setVisible(False)
        main_layout.addWidget(self.progress_bar)
        
        # Results Scroll Area
        self.scroll_area = SmoothScrollArea(self)
        self.scroll_area.setWidgetResizable(True)
        self.scroll_area.setFrameShape(QFrame.Shape.NoFrame)
        self.scroll_area.enableTransparentBackground()
        
        self.results_widget = QWidget()
        self.results_layout = QVBoxLayout(self.results_widget)
        self.results_layout.setContentsMargins(0, 0, 10, 0)
        self.results_layout.setSpacing(10)
        
        self.scroll_area.setWidget(self.results_widget)
        main_layout.addWidget(self.scroll_area, 1)
        
        I18n.add_listener(self.update_i18n)
        
        # Initial search with popular hubs
        self._render_results(STATIONS)

    def _set_coords(self, lat: float, lon: float):
        self.lat_edit.setText(str(lat))
        self.lon_edit.setText(str(lon))
        self.find_nearby()

    def search_by_name(self):
        query = self.search_edit.text().strip()
        if not query:
            self._render_results(STATIONS)
            return
            
        self.progress_bar.setVisible(True)
        self.search_btn.setEnabled(False)
        
        if self._current_worker is not None and self._current_worker.isRunning():
            try:
                self._current_worker.finished.disconnect()
                self._current_worker.failed.disconnect()
            except Exception:
                pass
                
        worker = StationSearchThread(query)
        self._current_worker = worker
        self._active_workers.add(worker)
        
        def on_finished(results, is_mock, err_msg):
            self._active_workers.discard(worker)
            worker.deleteLater()
            if self._current_worker is worker:
                self._current_worker = None
                self._on_search_finished(results, is_mock, err_msg)
                
        def on_failed(err):
            self._active_workers.discard(worker)
            worker.deleteLater()
            if self._current_worker is worker:
                self._current_worker = None
                self._on_search_failed(err)
                
        worker.finished.connect(on_finished)
        worker.failed.connect(on_failed)
        worker.start()

    def find_nearby(self):
        try:
            lat = float(self.lat_edit.text().strip())
            lon = float(self.lon_edit.text().strip())
        except ValueError:
            InfoBar.warning(
                title=t("error"),
                content="Please enter valid numeric latitude and longitude coordinates.",
                position=InfoBarPosition.TOP,
                parent=self.window()
            )
            return
            
        self.progress_bar.setVisible(True)
        
        if self._current_worker is not None and self._current_worker.isRunning():
            try:
                self._current_worker.finished.disconnect()
                self._current_worker.failed.disconnect()
            except Exception:
                pass
                
        worker = NearbyStopsThread(lat, lon)
        self._current_worker = worker
        self._active_workers.add(worker)
        
        def on_finished(results, is_mock, err_msg):
            self._active_workers.discard(worker)
            worker.deleteLater()
            if self._current_worker is worker:
                self._current_worker = None
                self._on_search_finished(results, is_mock, err_msg)
                
        def on_failed(err):
            self._active_workers.discard(worker)
            worker.deleteLater()
            if self._current_worker is worker:
                self._current_worker = None
                self._on_search_failed(err)
                
        worker.finished.connect(on_finished)
        worker.failed.connect(on_failed)
        worker.start()

    def _on_search_finished(self, results: list, is_mock: bool, err_msg: Optional[str] = None):
        self.progress_bar.setVisible(False)
        self.search_btn.setEnabled(True)
        if not results and err_msg:
            InfoBar.error(
                title=t("error"),
                content=f"搜索站点失败: {err_msg}",
                position=InfoBarPosition.TOP,
                duration=4000,
                parent=self.window()
            )
        self._render_results(results)

    def _on_search_failed(self, err: str):
        self.progress_bar.setVisible(False)
        self.search_btn.setEnabled(True)
        InfoBar.error(
            title=t("error"),
            content=err,
            position=InfoBarPosition.TOP,
            parent=self.window()
        )

    def _render_results(self, stations: list):
        while self.results_layout.count():
            item = self.results_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
                
        if not stations:
            empty_lbl = BodyLabel("No matching stations found.")
            empty_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            self.results_layout.addWidget(empty_lbl)
            return
            
        for s in stations:
            card = StationCard(s, self.results_widget)
            card.viewBoardRequested.connect(self._on_view_board)
            card.planTripRequested.connect(self._on_plan_trip)
            self.results_layout.addWidget(card)
        self.results_layout.addStretch()

    def _on_view_board(self, sid: str, sname: str):
        self.jumpToBoard.emit(sid, sname)

    def _on_plan_trip(self, sid: str, sname: str):
        self.jumpToTrip.emit({"id": sid, "name": sname})

    def update_i18n(self):
        self.title_lbl.setText(t("station_title"))
        self.search_edit.setPlaceholderText(t("station_search_placeholder"))
        self.search_btn.setText(t("station_search_btn"))
        self.nearby_lbl.setText(t("station_nearby_title"))
        self.nearby_btn.setText(t("station_find_nearby"))
        self.cph_chip.setText(t("station_preset_cph"))
        self.aarhus_chip.setText(t("station_preset_aarhus"))
        
        # Update existing station cards
        for i in range(self.results_layout.count()):
            item = self.results_layout.itemAt(i)
            w = item.widget() if item else None
            if isinstance(w, StationCard):
                w.update_i18n()

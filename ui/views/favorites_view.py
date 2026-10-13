from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QFrame
)
from PyQt6.QtCore import Qt, pyqtSignal
from qfluentwidgets import (
    TitleLabel, CaptionLabel, SubtitleLabel, StrongBodyLabel, BodyLabel,
    CardWidget, PushButton, PrimaryPushButton, TransparentToolButton,
    FluentIcon as FIF, InfoBar, InfoBarPosition, SmoothScrollArea
)
from config import config
from i18n import t, I18n

class FavoritesView(QWidget):
    """WinUI 3 Favorites and History View."""
    jumpToBoard = pyqtSignal(str, str) # station_id, station_name
    jumpToTrip = pyqtSignal(dict, dict) # origin_dict, dest_dict

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("FavoritesView")
        
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(28, 20, 28, 20)
        main_layout.setSpacing(16)
        
        # Header
        self.title_lbl = TitleLabel(t("fav_title"))
        main_layout.addWidget(self.title_lbl)
        
        # Scroll Area for all favorite sections
        scroll_area = SmoothScrollArea(self)
        scroll_area.setWidgetResizable(True)
        scroll_area.setFrameShape(QFrame.Shape.NoFrame)
        scroll_area.enableTransparentBackground()
        
        content = QWidget()
        self.content_layout = QVBoxLayout(content)
        self.content_layout.setContentsMargins(0, 0, 10, 0)
        self.content_layout.setSpacing(20)
        
        # Section 1: Favorite Stations
        self.sec1_title = SubtitleLabel(t("fav_stations_title"))
        self.content_layout.addWidget(self.sec1_title)
        self.stations_container = QVBoxLayout()
        self.stations_container.setSpacing(8)
        self.content_layout.addLayout(self.stations_container)
        
        # Section 2: Favorite Routes
        self.sec2_title = SubtitleLabel(t("fav_trips_title"))
        self.content_layout.addWidget(self.sec2_title)
        self.trips_container = QVBoxLayout()
        self.trips_container.setSpacing(8)
        self.content_layout.addLayout(self.trips_container)
        
        # Section 3: Recent Searches
        rec_header = QHBoxLayout()
        self.sec3_title = SubtitleLabel(t("fav_history_title"))
        rec_header.addWidget(self.sec3_title)
        rec_header.addStretch()
        self.clear_hist_btn = PushButton(FIF.DELETE, t("fav_clear_history"), self)
        self.clear_hist_btn.clicked.connect(self._clear_history)
        rec_header.addWidget(self.clear_hist_btn)
        self.content_layout.addLayout(rec_header)
        
        self.history_container = QVBoxLayout()
        self.history_container.setSpacing(8)
        self.content_layout.addLayout(self.history_container)
        
        self.content_layout.addStretch()
        scroll_area.setWidget(content)
        main_layout.addWidget(scroll_area, 1)
        
        I18n.add_listener(self.update_i18n)
        self.refresh_favorites()

    def refresh_favorites(self):
        # 1. Stations
        while self.stations_container.count():
            item = self.stations_container.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
                
        fav_stations = config.favorite_stations
        if not fav_stations:
            lbl = CaptionLabel(t("fav_empty"))
            lbl.setStyleSheet("color: gray;")
            self.stations_container.addWidget(lbl)
        else:
            for st in fav_stations:
                card = CardWidget()
                card_l = QHBoxLayout(card)
                card_l.setContentsMargins(16, 10, 16, 10)
                
                name_lbl = StrongBodyLabel(st.get("name", ""))
                card_l.addWidget(name_lbl)
                card_l.addStretch()
                
                go_btn = PushButton(FIF.BUS, t("station_action_dep"), card)
                go_btn.setFixedHeight(28)
                go_btn.clicked.connect(lambda ch, s=st: self.jumpToBoard.emit(s.get("id"), s.get("name")))
                card_l.addWidget(go_btn)
                
                del_btn = TransparentToolButton(FIF.DELETE, card)
                del_btn.setToolTip(t("fav_remove"))
                del_btn.clicked.connect(lambda ch, sid=st.get("id"): self._remove_station(sid))
                card_l.addWidget(del_btn)
                
                self.stations_container.addWidget(card)

        # 2. Trips
        while self.trips_container.count():
            item = self.trips_container.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
                
        fav_trips = config.favorite_trips
        if not fav_trips:
            lbl = CaptionLabel(t("fav_empty"))
            lbl.setStyleSheet("color: gray;")
            self.trips_container.addWidget(lbl)
        else:
            for trip in fav_trips:
                orig = trip.get("origin", {})
                dest = trip.get("dest", {})
                
                card = CardWidget()
                card_l = QHBoxLayout(card)
                card_l.setContentsMargins(16, 10, 16, 10)
                
                route_lbl = StrongBodyLabel(f"{orig.get('name')}  ➔  {dest.get('name')}")
                card_l.addWidget(route_lbl)
                card_l.addStretch()
                
                go_btn = PrimaryPushButton(FIF.SEARCH, t("fav_go"), card)
                go_btn.setFixedHeight(28)
                go_btn.clicked.connect(lambda ch, o=orig, d=dest: self.jumpToTrip.emit(o, d))
                card_l.addWidget(go_btn)
                
                del_btn = TransparentToolButton(FIF.DELETE, card)
                del_btn.setToolTip(t("fav_remove"))
                del_btn.clicked.connect(lambda ch, oid=orig.get("id"), did=dest.get("id"): self._remove_trip(oid, did))
                card_l.addWidget(del_btn)
                
                self.trips_container.addWidget(card)

        # 3. History
        while self.history_container.count():
            item = self.history_container.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
                
        recents = config.get("recent_searches", [])
        if not recents:
            lbl = CaptionLabel(t("fav_history_empty"))
            lbl.setStyleSheet("color: gray;")
            self.history_container.addWidget(lbl)
        else:
            for rec in recents[:10]:
                card = CardWidget()
                card_l = QHBoxLayout(card)
                card_l.setContentsMargins(16, 10, 16, 10)
                
                t_lbl = BodyLabel(rec.get("title", ""))
                card_l.addWidget(t_lbl)
                
                time_lbl = CaptionLabel(f"{rec.get('date', '')} {rec.get('time', '')}")
                time_lbl.setStyleSheet("color: gray;")
                card_l.addWidget(time_lbl)
                card_l.addStretch()
                
                go_btn = PushButton(FIF.SEARCH, t("fav_go"), card)
                go_btn.setFixedHeight(28)
                go_btn.clicked.connect(lambda ch, r=rec: self.jumpToTrip.emit(r.get("origin"), r.get("dest")))
                card_l.addWidget(go_btn)
                
                self.history_container.addWidget(card)

    def _remove_station(self, sid: str):
        config.remove_favorite_station(sid)
        self.refresh_favorites()

    def _remove_trip(self, oid: str, did: str):
        config.remove_favorite_trip(oid, did)
        self.refresh_favorites()

    def _clear_history(self):
        config.set("recent_searches", [])
        self.refresh_favorites()

    def update_i18n(self):
        self.title_lbl.setText(t("fav_title"))
        self.sec1_title.setText(t("fav_stations_title"))
        self.sec2_title.setText(t("fav_trips_title"))
        self.sec3_title.setText(t("fav_history_title"))
        self.clear_hist_btn.setText(t("fav_clear_history"))
        self.refresh_favorites()

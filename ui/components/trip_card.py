from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QFrame
)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QFont
from qfluentwidgets import (
    CardWidget, TransparentToolButton, FluentIcon as FIF,
    BodyLabel, StrongBodyLabel, CaptionLabel, InfoBar, InfoBarPosition
)
from ui.components.badge import TransitBadge
from config import config
from i18n import t

class TripLegWidget(QWidget):
    """Visual step-by-step leg representation within a journey card."""
    def __init__(self, leg: dict, is_last: bool = False, parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 4, 16, 4)
        layout.setSpacing(6)
        
        orig = leg.get("origin", {})
        dest = leg.get("destination", {})
        leg_type = leg.get("type", "TOG")
        leg_name = leg.get("name", "Transit")
        direction = leg.get("direction", "")
        notes = leg.get("notes", "")
        
        self.orig_track = orig.get("track", "")
        self.dest_track = dest.get("track", "")
        self.orig_track_lbl = None
        self.dest_track_lbl = None
        
        # Origin Line
        orig_row = QHBoxLayout()
        orig_time = orig.get("time", "")
        orig_name = orig.get("name", "")
        
        orig_time_lbl = StrongBodyLabel(f"{orig_time}  ")
        orig_time_lbl.setFixedWidth(55)
        orig_name_lbl = BodyLabel(orig_name)
        orig_name_lbl.setStyleSheet("font-weight: 600;")
        
        orig_row.addWidget(orig_time_lbl)
        orig_row.addWidget(orig_name_lbl)
        orig_row.addStretch()
        if self.orig_track and self.orig_track != "-":
            self.orig_track_lbl = CaptionLabel(f"{t('trip_platform')} {self.orig_track}")
            self.orig_track_lbl.setStyleSheet("background: rgba(128,128,128,0.12); padding: 2px 6px; border-radius: 4px; font-weight: 600;")
            orig_row.addWidget(self.orig_track_lbl)
        layout.addLayout(orig_row)
        
        # Intermediate Transit Line Info
        mid_row = QHBoxLayout()
        mid_row.setSpacing(8)
        spacer_lbl = QLabel()
        spacer_lbl.setFixedWidth(55)
        mid_row.addWidget(spacer_lbl)
        
        badge = TransitBadge(leg_name, type_code=leg_type)
        mid_row.addWidget(badge)
        
        if direction:
            dir_lbl = CaptionLabel(f"→ {direction}")
            dir_lbl.setStyleSheet("color: gray;")
            mid_row.addWidget(dir_lbl)
            
        mid_row.addStretch()
        layout.addLayout(mid_row)
        
        if notes:
            note_row = QHBoxLayout()
            spacer2 = QLabel()
            spacer2.setFixedWidth(55)
            note_row.addWidget(spacer2)
            note_lbl = CaptionLabel(f"ℹ️ {notes}")
            note_lbl.setStyleSheet("color: #0284C7; font-style: italic;")
            note_row.addWidget(note_lbl)
            note_row.addStretch()
            layout.addLayout(note_row)
            
        # Destination Line
        dest_row = QHBoxLayout()
        dest_time = dest.get("time", "")
        dest_name = dest.get("name", "")
        
        dest_time_lbl = StrongBodyLabel(f"{dest_time}  ")
        dest_time_lbl.setFixedWidth(55)
        dest_name_lbl = BodyLabel(dest_name)
        
        dest_row.addWidget(dest_time_lbl)
        dest_row.addWidget(dest_name_lbl)
        dest_row.addStretch()
        if self.dest_track and self.dest_track != "-":
            self.dest_track_lbl = CaptionLabel(f"{t('trip_platform')} {self.dest_track}")
            self.dest_track_lbl.setStyleSheet("background: rgba(128,128,128,0.12); padding: 2px 6px; border-radius: 4px; font-weight: 600;")
            dest_row.addWidget(self.dest_track_lbl)
        layout.addLayout(dest_row)
        
        if not is_last:
            sep = QFrame()
            sep.setFrameShape(QFrame.Shape.HLine)
            sep.setStyleSheet("color: rgba(128,128,128,0.15); margin: 6px 0;")
            layout.addWidget(sep)

    def update_i18n(self):
        if self.orig_track_lbl is not None and self.orig_track and self.orig_track != "-":
            self.orig_track_lbl.setText(f"{t('trip_platform')} {self.orig_track}")
        if self.dest_track_lbl is not None and self.dest_track and self.dest_track != "-":
            self.dest_track_lbl.setText(f"{t('trip_platform')} {self.dest_track}")

class TripCard(CardWidget):
    """WinUI 3 Trip Overview Card with expandable itinerary steps."""
    favoriteClicked = pyqtSignal(dict)

    def __init__(self, trip_data: dict, parent=None):
        super().__init__(parent)
        self.trip_data = trip_data
        self._is_expanded = False
        self._leg_widgets = []
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(18, 14, 18, 14)
        layout.setSpacing(10)
        
        # Summary Header Row
        header_row = QHBoxLayout()
        header_row.setSpacing(10)
        
        # Departure -> Arrival time
        dep_time = trip_data.get("dep_time", "00:00")
        arr_time = trip_data.get("arr_time", "00:00")
        time_text = f"{dep_time}  →  {arr_time}"
        self.time_label = QLabel(time_text)
        self.time_label.setFont(QFont("Segoe UI", 13, QFont.Weight.Bold))
        header_row.addWidget(self.time_label)
        
        # Duration badge
        dur_min = trip_data.get("duration_min", 0)
        self.dur_lbl = CaptionLabel(f"⏱ {dur_min} min")
        self.dur_lbl.setStyleSheet("background: rgba(0, 120, 212, 0.08); color: #0078D4; font-weight: 600; padding: 3px 8px; border-radius: 4px;")
        header_row.addWidget(self.dur_lbl)
        
        # Transfers badge
        self.changes = trip_data.get("changes", 0)
        self.changes_lbl = CaptionLabel("")
        self._update_changes_text()
        self.changes_lbl.setStyleSheet("background: rgba(128, 128, 128, 0.1); padding: 3px 8px; border-radius: 4px; font-weight: 600;")
        header_row.addWidget(self.changes_lbl)
        
        # Badges for all transit legs
        legs = trip_data.get("legs", [])
        for leg in legs:
            name = leg.get("name", "Tog")
            ltype = leg.get("type", "TOG")
            if ltype != "WALK":
                badge = TransitBadge(name, type_code=ltype)
                header_row.addWidget(badge)
                
        header_row.addStretch()
        
        # Favorite button
        self.fav_btn = TransparentToolButton(FIF.HEART, self)
        self.fav_btn.setToolTip(t("trip_save_fav"))
        self.fav_btn.clicked.connect(self._on_fav_clicked)
        header_row.addWidget(self.fav_btn)
        
        # Expand toggle button
        self.expand_btn = TransparentToolButton(FIF.CARE_DOWN_SOLID, self)
        self.expand_btn.setToolTip(t("trip_step_by_step"))
        self.expand_btn.clicked.connect(self.toggle_expand)
        header_row.addWidget(self.expand_btn)
        
        layout.addLayout(header_row)
        
        # Expandable Leg Container
        self.legs_container = QWidget(self)
        self.legs_layout = QVBoxLayout(self.legs_container)
        self.legs_layout.setContentsMargins(0, 8, 0, 0)
        self.legs_layout.setSpacing(6)
        
        for idx, leg in enumerate(legs):
            is_last = (idx == len(legs) - 1)
            leg_widget = TripLegWidget(leg, is_last=is_last)
            self._leg_widgets.append(leg_widget)
            self.legs_layout.addWidget(leg_widget)
            
        self.legs_container.setVisible(False)
        layout.addWidget(self.legs_container)

    def _update_changes_text(self):
        if self.changes == 0:
            self.changes_lbl.setText(t("trip_direct"))
        else:
            self.changes_lbl.setText(f"{self.changes} {t('trip_changes')}")

    def update_i18n(self):
        self._update_changes_text()
        self.fav_btn.setToolTip(t("trip_save_fav"))
        self.expand_btn.setToolTip(t("trip_step_by_step"))
        for lw in self._leg_widgets:
            lw.update_i18n()

    def toggle_expand(self):
        self._is_expanded = not self._is_expanded
        self.legs_container.setVisible(self._is_expanded)
        icon = FIF.CARE_UP_SOLID if self._is_expanded else FIF.CARE_DOWN_SOLID
        self.expand_btn.setIcon(icon)

    def _on_fav_clicked(self):
        legs = self.trip_data.get("legs", [])
        if legs:
            first_orig = legs[0].get("origin", {})
            last_dest = legs[-1].get("destination", {})
            origin_info = {"id": first_orig.get("id", first_orig.get("name")), "name": first_orig.get("name")}
            dest_info = {"id": last_dest.get("id", last_dest.get("name")), "name": last_dest.get("name")}
            
            added = config.add_favorite_trip(origin_info, dest_info)
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

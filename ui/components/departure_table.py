from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QTableWidgetItem, QHeaderView, QLabel, QHBoxLayout
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFont, QColor
from qfluentwidgets import TableWidget
from ui.components.badge import TransitBadge, StatusBadge
from i18n import t

class DepartureTable(QWidget):
    """WinUI 3 styled Table displaying departures or arrivals with real-time tracking."""
    def __init__(self, is_arrival: bool = False, parent=None):
        super().__init__(parent)
        self.is_arrival = is_arrival
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        
        self.table = TableWidget(self)
        self.table.setColumnCount(6)
        self.table.verticalHeader().setVisible(False)
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(TableWidget.SelectionBehavior.SelectRows)
        self.table.setEditTriggers(TableWidget.EditTrigger.NoEditTriggers)
        
        self._current_items = []
        self.update_headers()
        
        # Configure column widths and stretching
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents) # Line badge
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)          # Destination/Origin
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents) # Scheduled
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents) # Real-Time
        header.setSectionResizeMode(4, QHeaderView.ResizeMode.ResizeToContents) # Track
        header.setSectionResizeMode(5, QHeaderView.ResizeMode.ResizeToContents) # Status
        
        layout.addWidget(self.table)

    def update_headers(self):
        dir_col = t("board_col_dir")
        self.table.setHorizontalHeaderLabels([
            t("board_col_line"),
            dir_col,
            t("board_col_time"),
            t("board_col_realtime"),
            t("board_col_track"),
            t("board_col_status")
        ])

    def update_i18n(self):
        self.update_headers()
        if self._current_items:
            self.set_data(self._current_items)

    def set_data(self, items: list):
        self._current_items = list(items or [])
        self.table.clearContents()
        self.table.setRowCount(len(items))
        
        base_font = QFont("Segoe UI", 10)
        bold_font = QFont("Segoe UI", 10)
        bold_font.setBold(True)
        
        for row, item in enumerate(items):
            self.table.setRowHeight(row, 46)
            
            # Col 0: Line / Vehicle Badge
            badge_widget = QWidget()
            badge_layout = QHBoxLayout(badge_widget)
            badge_layout.setContentsMargins(8, 6, 8, 6)
            badge = TransitBadge(item.get("name", "Transit"), type_code=item.get("type", "TOG"))
            badge_layout.addWidget(badge)
            badge_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
            
            c0_item = QTableWidgetItem()
            c0_item.setFont(base_font)
            self.table.setItem(row, 0, c0_item)
            self.table.setCellWidget(row, 0, badge_widget)
            
            # Col 1: Destination / Origin
            target = item.get("origin") if self.is_arrival else item.get("direction")
            target_item = QTableWidgetItem(target or item.get("stop", ""))
            target_item.setFont(base_font)
            target_item.setTextAlignment(Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft)
            self.table.setItem(row, 1, target_item)
            
            # Col 2: Scheduled Time
            sched_time = item.get("time", "")
            time_item = QTableWidgetItem(sched_time)
            time_item.setFont(bold_font)
            time_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.table.setItem(row, 2, time_item)
            
            # Col 3: Real-Time / Delay
            rt_time = item.get("rtTime", sched_time)
            delay = item.get("delay", 0)
            if delay > 0:
                rt_text = f"{rt_time}  (+{delay}m)"
            else:
                rt_text = rt_time
            rt_item = QTableWidgetItem(rt_text)
            rt_item.setFont(bold_font if delay > 0 else base_font)
            if delay >= 5:
                rt_item.setForeground(QColor("#EF4444"))
            elif delay > 0:
                rt_item.setForeground(QColor("#F59E0B"))
            else:
                rt_item.setForeground(QColor("#10B981"))
            rt_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.table.setItem(row, 3, rt_item)
            
            # Col 4: Platform / Track
            track = item.get("rtTrack") or item.get("track", "-")
            track_text = f"{t('trip_platform')} {track}" if str(track).isdigit() else str(track)
            track_item = QTableWidgetItem(track_text)
            track_item.setFont(base_font)
            track_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.table.setItem(row, 4, track_item)
            
            # Col 5: Status Badge
            status_str = item.get("status", "normal")
            if status_str == "cancelled":
                badge_text = t("status_cancelled")
            elif status_str in ("delayed", "minor_delay"):
                badge_text = f"{t('status_delayed')} {delay}m"
            else:
                badge_text = t("status_ontime")
                
            status_widget = QWidget()
            status_layout = QHBoxLayout(status_widget)
            status_layout.setContentsMargins(6, 6, 6, 6)
            s_badge = StatusBadge(badge_text, status=status_str)
            status_layout.addWidget(s_badge)
            status_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
            
            c5_item = QTableWidgetItem()
            c5_item.setFont(base_font)
            self.table.setItem(row, 5, c5_item)
            self.table.setCellWidget(row, 5, status_widget)

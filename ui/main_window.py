from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt, QSize
from PyQt6.QtGui import QIcon
from qfluentwidgets import (
    MSFluentWindow, NavigationItemPosition, FluentIcon as FIF,
    setTheme, Theme
)
from ui.views.trip_view import TripView
from ui.views.board_view import BoardView
from ui.views.station_view import StationView
from ui.views.favorites_view import FavoritesView
from ui.views.settings_view import SettingsView
from config import config
from i18n import t, I18n

class MainWindow(MSFluentWindow):
    """WinUI 3 Main Window for Spor Desktop Client."""
    def __init__(self):
        super().__init__()
        self.init_window()
        self.init_navigation()
        self.connect_inter_view_signals()
        
        I18n.add_listener(self.update_i18n)
        self.update_i18n()

    def init_window(self):
        self.setWindowTitle(t("app_title"))
        self.resize(1120, 760)
        self.setMinimumSize(QSize(900, 620))
        
        # Center on screen
        desktop = QApplication.primaryScreen().availableGeometry()
        w, h = desktop.width(), desktop.height()
        self.move(int((w - self.width()) / 2), int((h - self.height()) / 2))
        
        # Apply initial theme
        th = config.theme
        if th == "Light":
            setTheme(Theme.LIGHT)
        elif th == "Dark":
            setTheme(Theme.DARK)
        else:
            setTheme(Theme.AUTO)

    def init_navigation(self):
        # 1. Journey Planner View
        self.trip_view = TripView(self)
        self.addSubInterface(self.trip_view, FIF.TRAIN, t("nav_trip"))
        
        # 2. Live Departure Board View
        self.board_view = BoardView(self)
        self.addSubInterface(self.board_view, FIF.BUS, t("nav_board"))
        
        # 3. Stations & Stops Explorer View
        self.station_view = StationView(self)
        self.addSubInterface(self.station_view, FIF.PIN, t("nav_station"))
        
        # 4. Favorites & History View
        self.fav_view = FavoritesView(self)
        self.addSubInterface(self.fav_view, FIF.HEART, t("nav_favorites"))
        
        # 5. Settings View (Anchored to bottom)
        self.settings_view = SettingsView(self)
        self.addSubInterface(
            self.settings_view,
            FIF.SETTING,
            t("nav_settings"),
            position=NavigationItemPosition.BOTTOM
        )

    def connect_inter_view_signals(self):
        # From Station Explorer -> Board View
        self.station_view.jumpToBoard.connect(self.on_jump_to_board)
        # From Station Explorer -> Trip View
        self.station_view.jumpToTrip.connect(self.on_jump_to_trip_origin)
        # From Favorites -> Board View
        self.fav_view.jumpToBoard.connect(self.on_jump_to_board)
        # From Favorites -> Trip View
        self.fav_view.jumpToTrip.connect(self.on_jump_to_trip_route)

    def on_jump_to_board(self, station_id: str, station_name: str):
        self.switchTo(self.board_view)
        self.board_view.select_station(station_id, station_name)

    def on_jump_to_trip_origin(self, station: dict):
        self.switchTo(self.trip_view)
        self.trip_view.orig_picker.set_station(station)

    def on_jump_to_trip_route(self, origin: dict, dest: dict):
        self.switchTo(self.trip_view)
        self.trip_view.set_route(origin, dest)

    def update_i18n(self):
        self.setWindowTitle(t("app_title"))
        
        # Update navigation item labels
        nav = self.navigationInterface
        try:
            item = nav.widget(self.trip_view.objectName())
            if item:
                item.setText(t("nav_trip"))
            item = nav.widget(self.board_view.objectName())
            if item:
                item.setText(t("nav_board"))
            item = nav.widget(self.station_view.objectName())
            if item:
                item.setText(t("nav_station"))
            item = nav.widget(self.fav_view.objectName())
            if item:
                item.setText(t("nav_favorites"))
            item = nav.widget(self.settings_view.objectName())
            if item:
                item.setText(t("nav_settings"))
        except Exception as e:
            print(f"[MainWindow] update_i18n navigation update error: {e}")

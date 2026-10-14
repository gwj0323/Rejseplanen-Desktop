from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QCompleter
)
from PyQt6.QtCore import pyqtSignal, QStringListModel, Qt, QTimer, QThread
from qfluentwidgets import SearchLineEdit
from api.client import api_client
from api.mock_data import STATIONS
from i18n import t

class StationSearchThread(QThread):
    """Runs the location search off the UI thread; a synchronous call here
    would freeze the whole window for up to the request timeout."""
    resultsReady = pyqtSignal(str, list)  # query, results

    def __init__(self, query: str, parent=None):
        super().__init__(parent)
        self.query = query

    def run(self):
        try:
            results, _, _ = api_client.search_locations(self.query)
        except Exception:
            results = []
        self.resultsReady.emit(self.query, results or [])

class StationPicker(QWidget):
    """WinUI 3 styled Station Picker with dynamic autocomplete and quick selection."""
    stationSelected = pyqtSignal(dict)  # emits {"id": str, "name": str}

    def __init__(self, placeholder: str = "", parent=None):
        super().__init__(parent)
        self._current_station = None
        self._station_cache = {s["name"]: s for s in STATIONS}
        self._worker = None
        self._pending_return_query = None

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        # Search input
        self.search_edit = SearchLineEdit(self)
        self.search_edit.setPlaceholderText(placeholder)
        self.search_edit.setClearButtonEnabled(True)

        # Autocomplete
        self.model = QStringListModel([s["name"] for s in STATIONS], self)
        self.completer = QCompleter(self.model, self)
        self.completer.setCaseSensitivity(Qt.CaseSensitivity.CaseInsensitive)
        self.completer.setFilterMode(Qt.MatchFlag.MatchContains)
        self.completer.activated.connect(self._on_completer_activated)
        self.search_edit.setCompleter(self.completer)

        self.search_edit.textEdited.connect(self._on_text_edited)
        self.search_edit.returnPressed.connect(self._on_return_pressed)

        layout.addWidget(self.search_edit)

        # Debounce timer for API searches
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.setInterval(300)
        self._timer.timeout.connect(self._do_api_search)

    def _on_text_edited(self, text: str):
        if len(text.strip()) >= 2:
            self._timer.start()

    def _start_search(self, query: str, select_first: bool = False):
        # Drop the previous worker's signals so stale results are ignored.
        if self._worker is not None and self._worker.isRunning():
            try:
                self._worker.resultsReady.disconnect()
            except Exception:
                pass

        worker = StationSearchThread(query)
        self._worker = worker

        def on_results(result_query: str, results: list):
            worker.deleteLater()
            if self._worker is worker:
                self._worker = None
                self._on_search_results(result_query, results, select_first)

        worker.resultsReady.connect(on_results)
        worker.start()

    def _on_search_results(self, query: str, results: list, select_first: bool):
        names = []
        for r in results:
            name = r.get("name")
            if name:
                names.append(name)
                self._station_cache[name] = r

        # Merge with base stations
        current_names = list(names)
        for s in STATIONS:
            if s["name"] not in current_names:
                current_names.append(s["name"])
        self.model.setStringList(current_names)

        if select_first and results:
            # Only auto-select if the user has not typed something else meanwhile.
            if self.search_edit.text().strip() == query:
                station = results[0]
                self._station_cache[station["name"]] = station
                self.search_edit.setText(station["name"])
                self._current_station = station
                self.stationSelected.emit(station)
            return

    def _do_api_search(self):
        query = self.search_edit.text().strip()
        if len(query) < 2:
            return
        self._start_search(query)

    def _on_completer_activated(self, text: str):
        station = self._station_cache.get(text)
        if station:
            self._current_station = station
            self.stationSelected.emit(station)

    def _on_return_pressed(self):
        text = self.search_edit.text().strip()
        if not text:
            return
        if text in self._station_cache:
            station = self._station_cache[text]
            self._current_station = station
            self.stationSelected.emit(station)
        else:
            # Look up the typed text asynchronously and pick the first hit.
            self._start_search(text, select_first=True)

    def get_station(self) -> dict:
        text = self.search_edit.text().strip()
        if not text:
            return {}
        if self._current_station and self._current_station.get("name") == text:
            return self._current_station
        if text in self._station_cache:
            return self._station_cache[text]
        # Fallback to text as custom stop
        return {"id": text, "name": text}

    def set_station(self, station: dict, emit_signal: bool = False):
        if not station:
            self.search_edit.clear()
            self._current_station = None
            return
        self._current_station = station
        name = station.get("name", "")
        self.search_edit.setText(name)
        if name:
            self._station_cache[name] = station
        if emit_signal:
            self.stationSelected.emit(station)

    def set_placeholder(self, placeholder: str):
        self.search_edit.setPlaceholderText(placeholder)

    def clear(self):
        self.search_edit.clear()
        self._current_station = None

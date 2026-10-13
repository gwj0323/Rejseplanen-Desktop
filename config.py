import json
import os
import sys
from typing import Dict, Any, List

if getattr(sys, "frozen", False):
    BASE_DIR = os.path.dirname(sys.executable)
    RESOURCE_DIR = getattr(sys, "_MEIPASS", BASE_DIR)
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    RESOURCE_DIR = BASE_DIR

CONFIG_FILE = os.path.join(BASE_DIR, "settings.json")
EXAMPLE_FILE = os.path.join(RESOURCE_DIR, "settings.example.json")

DEFAULT_SETTINGS: Dict[str, Any] = {
    "api_key": "",
    "base_url": "https://www.rejseplanen.dk/api",
    "mock_fallback": True,
    "language": "zh_CN",  # "zh_CN", "en_US", "da_DK"
    "theme": "Auto",       # "Auto", "Light", "Dark"
    "auto_refresh_interval": 30,  # seconds
    "favorite_stations": [
        {"id": "8600626", "name": "København H", "type": "ST"},
        {"id": "8600646", "name": "Nørreport St.", "type": "ST"},
        {"id": "8600858", "name": "CPH Lufthavn", "type": "ST"},
        {"id": "8600053", "name": "Aarhus H", "type": "ST"}
    ],
    "favorite_trips": [
        {
            "origin": {"id": "8600626", "name": "København H"},
            "dest": {"id": "8600646", "name": "Nørreport St."}
        },
        {
            "origin": {"id": "8600626", "name": "København H"},
            "dest": {"id": "8600858", "name": "CPH Lufthavn"}
        }
    ],
    "recent_searches": []
}

class AppConfig:
    """Manages application settings persisted in settings.json."""
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(AppConfig, cls).__new__(cls)
            cls._instance._data = dict(DEFAULT_SETTINGS)
            cls._instance.load()
        return cls._instance

    def load(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    saved = json.load(f)
                    self._data.update(saved)
            except Exception as e:
                print(f"[Config] Error loading settings: {e}")
        elif os.path.exists(EXAMPLE_FILE):
            try:
                with open(EXAMPLE_FILE, "r", encoding="utf-8") as f:
                    saved = json.load(f)
                    self._data.update(saved)
                self.save()
            except Exception as e:
                pass
        else:
            self.save()

    def save(self):
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(self._data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"[Config] Error saving settings: {e}")

    def get(self, key: str, default: Any = None) -> Any:
        return self._data.get(key, default)

    def set(self, key: str, value: Any):
        self._data[key] = value
        self.save()

    @property
    def api_key(self) -> str:
        return self._data.get("api_key", "").strip()

    @api_key.setter
    def api_key(self, val: str):
        self.set("api_key", val.strip())

    @property
    def base_url(self) -> str:
        return self._data.get("base_url", "https://www.rejseplanen.dk/api").rstrip("/")

    @base_url.setter
    def base_url(self, val: str):
        self.set("base_url", val.strip().rstrip("/"))

    @property
    def mock_fallback(self) -> bool:
        return self._data.get("mock_fallback", True)

    @mock_fallback.setter
    def mock_fallback(self, val: bool):
        self.set("mock_fallback", bool(val))

    @property
    def language(self) -> str:
        return self._data.get("language", "zh_CN")

    @language.setter
    def language(self, val: str):
        self.set("language", val)

    @property
    def theme(self) -> str:
        return self._data.get("theme", "Auto")

    @theme.setter
    def theme(self, val: str):
        self.set("theme", val)

    @property
    def favorite_stations(self) -> List[Dict[str, str]]:
        return self._data.get("favorite_stations", [])

    def add_favorite_station(self, station: Dict[str, str]) -> bool:
        favs = self.favorite_stations
        if not any(f.get("id") == station.get("id") for f in favs):
            favs.append(station)
            self.set("favorite_stations", favs)
            return True
        return False

    def remove_favorite_station(self, station_id: str):
        favs = [f for f in self.favorite_stations if f.get("id") != station_id]
        self.set("favorite_stations", favs)

    def is_station_favorite(self, station_id: str) -> bool:
        return any(f.get("id") == station_id for f in self.favorite_stations)

    @property
    def favorite_trips(self) -> List[Dict[str, Any]]:
        return self._data.get("favorite_trips", [])

    def add_favorite_trip(self, origin: Dict[str, str], dest: Dict[str, str]) -> bool:
        trips = self.favorite_trips
        for t in trips:
            if t.get("origin", {}).get("id") == origin.get("id") and t.get("dest", {}).get("id") == dest.get("id"):
                return False
        trips.append({"origin": origin, "dest": dest})
        self.set("favorite_trips", trips)
        return True

    def remove_favorite_trip(self, origin_id: str, dest_id: str):
        trips = [t for t in self.favorite_trips if not (
            t.get("origin", {}).get("id") == origin_id and t.get("dest", {}).get("id") == dest_id
        )]
        self.set("favorite_trips", trips)

    def add_recent_search(self, search: Dict[str, Any]):
        recents = self._data.get("recent_searches", [])
        # filter duplicates
        recents = [r for r in recents if r.get("title") != search.get("title")]
        recents.insert(0, search)
        if len(recents) > 20:
            recents = recents[:20]
        self.set("recent_searches", recents)

config = AppConfig()

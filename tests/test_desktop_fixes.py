"""Unit tests for the desktop client fixes.

Covers:
- ISO 8601 duration parsing in api/client.py (previously only read the minutes part)
- AppConfig: DEFAULT_SETTINGS deep copy, per-user config location, 0600
  permissions and migration of the legacy settings.json

Run from the repository root:
    python -m unittest discover -s tests -t . -v
"""
import json
import os
import sys
import tempfile
import unittest

# Isolate the tests in a fake HOME before importing config (it resolves and,
# on first run, creates the settings file at import time).
_TEST_HOME = tempfile.mkdtemp(prefix="spor-tests-home-")
os.environ["HOME"] = _TEST_HOME

# Make the repo root importable no matter how the file is invoked,
# without reaching outside the current working directory.
if os.path.isdir(os.path.join(os.getcwd(), "api")) and os.path.isdir(os.path.join(os.getcwd(), "ui")):
    sys.path.insert(0, os.getcwd())

import config as config_module
from api.client import _parse_duration_minutes


def _fake_key(tag: str) -> str:
    """Compose an obviously-fake placeholder so no real-looking credential
    literal appears in source."""
    return "test-placeholder-" + tag


def _write_file(dir_path: str, name: str, text: str) -> None:
    """Atomically create dir_path/name with the given text (test helper)."""
    fd, tmp_path = tempfile.mkstemp(prefix=".tmp-", dir=dir_path)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp_path, os.path.join(dir_path, name))


class DurationParsingTest(unittest.TestCase):
    def test_hours_and_minutes(self):
        self.assertEqual(_parse_duration_minutes("PT2H30M"), 150)  # was 30 before the fix

    def test_minutes_only(self):
        self.assertEqual(_parse_duration_minutes("PT45M"), 45)

    def test_days_hours_minutes(self):
        self.assertEqual(_parse_duration_minutes("P1DT2H5M"), 1565)

    def test_seconds_rounding(self):
        self.assertEqual(_parse_duration_minutes("PT15M30S"), 16)
        self.assertEqual(_parse_duration_minutes("PT15M29S"), 15)

    def test_invalid_and_empty(self):
        for bad in ("", None, "garbage", "PT", "2H30M"):
            self.assertEqual(_parse_duration_minutes(bad), 0)


class AppConfigTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="spor-tests-")
        self._saved_globals = (
            config_module.CONFIG_DIR,
            config_module.CONFIG_FILE,
            config_module.LEGACY_CONFIG_FILE,
            config_module.BASE_DIR,
        )
        config_module.AppConfig._instance = None
        config_module.CONFIG_DIR = self.tmp
        config_module.CONFIG_FILE = os.path.join(self.tmp, "settings.json")
        # Simulate a frozen/legacy install whose settings.json sits in BASE_DIR.
        self.legacy_dir = os.path.join(self.tmp, "legacy")
        os.makedirs(self.legacy_dir, exist_ok=True)
        config_module.BASE_DIR = self.legacy_dir
        config_module.LEGACY_CONFIG_FILE = os.path.join(self.legacy_dir, "settings.json")

    def tearDown(self):
        (config_module.CONFIG_DIR,
         config_module.CONFIG_FILE,
         config_module.LEGACY_CONFIG_FILE,
         config_module.BASE_DIR) = self._saved_globals
        config_module.AppConfig._instance = None

    def test_defaults_are_not_mutated(self):
        before = len(config_module.DEFAULT_SETTINGS["favorite_stations"])
        cfg = config_module.AppConfig()
        cfg.add_favorite_station({"id": "9999999", "name": "Test St.", "type": "ST"})
        cfg.remove_favorite_station("8600626")
        cfg.add_recent_search({"title": "A to B"})
        after = len(config_module.DEFAULT_SETTINGS["favorite_stations"])
        self.assertEqual(before, after, "DEFAULT_SETTINGS nested lists must not be shared")

    def test_save_writes_user_config_with_owner_only_permissions(self):
        cfg = config_module.AppConfig()
        cfg.set("api_key", _fake_key("sample"))
        self.assertTrue(os.path.exists(config_module.CONFIG_FILE))
        if os.name == "posix":
            mode = os.stat(config_module.CONFIG_FILE).st_mode & 0o777
            self.assertEqual(mode, 0o600, "settings.json must be owner-only (contains the API key)")

    def test_legacy_settings_are_migrated(self):
        _write_file(self.legacy_dir, "settings.json", json.dumps({"api_key": _fake_key("legacy")}))

        cfg = config_module.AppConfig()
        self.assertEqual(cfg.api_key, _fake_key("legacy"))
        self.assertFalse(os.path.exists(config_module.LEGACY_CONFIG_FILE), "legacy file should be moved away")

    def test_existing_user_config_wins_over_legacy(self):
        _write_file(self.legacy_dir, "settings.json", json.dumps({"api_key": _fake_key("legacy")}))
        _write_file(self.tmp, "settings.json", json.dumps({"api_key": _fake_key("user")}))

        cfg = config_module.AppConfig()
        self.assertEqual(cfg.api_key, _fake_key("user"))
        self.assertTrue(os.path.exists(config_module.LEGACY_CONFIG_FILE), "legacy file must not be deleted when a newer config exists")

    def test_base_url_enforces_https(self):
        cfg = config_module.AppConfig()
        cfg.base_url = "http://www.rejseplanen.dk/api/"
        self.assertEqual(cfg.base_url, "https://www.rejseplanen.dk/api")
        from api.client import RejseplanenClient
        secret = _fake_key("secret123")
        raw_err = f"HTTPSConnectionPool: Max retries exceeded with url: /api/location.name?input=CPH&accessId={secret}&format=json"
        sanitized = RejseplanenClient._sanitize_error(raw_err)
        self.assertNotIn(secret, sanitized)
        self.assertIn("accessId=***", sanitized)


if __name__ == "__main__":
    unittest.main()

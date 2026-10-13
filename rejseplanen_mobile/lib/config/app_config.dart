import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station.dart';

class AppConfig extends ChangeNotifier {
  static const String _keySettings = 'rejseplanen_settings';

  String _apiKey = '';
  String _baseUrl = 'https://www.rejseplanen.dk/api';
  bool _mockFallback = true;
  String _language = 'zh_CN'; // 'zh_CN', 'en_US', 'da_DK'
  ThemeMode _themeMode = ThemeMode.system;
  String _accentColor = 'system'; // 'system' (Material You) or hex like '#C72027'
  int _autoRefreshInterval = 30;

  List<Station> _favoriteStations = [
    Station(id: "8600626", name: "København H", types: ["ST"]),
    Station(id: "8600646", name: "Nørreport St.", types: ["ST"]),
    Station(id: "8600858", name: "CPH Lufthavn", types: ["ST"]),
    Station(id: "8600053", name: "Aarhus H", types: ["ST"]),
  ];

  List<Map<String, Station>> _favoriteTrips = [
    {
      "origin": Station(id: "8600626", name: "København H"),
      "dest": Station(id: "8600646", name: "Nørreport St."),
    },
    {
      "origin": Station(id: "8600626", name: "København H"),
      "dest": Station(id: "8600858", name: "CPH Lufthavn"),
    },
  ];

  List<String> _recentSearches = [];

  // Getters
  String get apiKey => _apiKey;
  String get baseUrl => _baseUrl;
  bool get mockFallback => _mockFallback;
  String get language => _language;
  ThemeMode get themeMode => _themeMode;
  String get accentColor => _accentColor;
  bool get isSystemAccentColor => _accentColor == 'system';

  Color get customAccentColor {
    if (_accentColor == 'system') {
      return const Color(0xFFC72027);
    }
    try {
      String hex = _accentColor.replaceAll('#', '').trim();
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFC72027);
    }
  }

  int get autoRefreshInterval => _autoRefreshInterval;
  List<Station> get favoriteStations => _favoriteStations;
  List<Map<String, Station>> get favoriteTrips => _favoriteTrips;
  List<String> get recentSearches => _recentSearches;

  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  AppConfig() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_keySettings);
      if (dataStr != null) {
        final data = jsonDecode(dataStr) as Map<String, dynamic>;
        _apiKey = data['api_key'] ?? '';
        _baseUrl = data['base_url'] ?? 'https://www.rejseplanen.dk/api';
        _mockFallback = data['mock_fallback'] ?? true;
        _language = data['language'] ?? 'zh_CN';
        _autoRefreshInterval = data['auto_refresh_interval'] ?? 30;
        _accentColor = data['accent_color'] ?? 'system';

        final themeStr = data['theme'] ?? 'Auto';
        if (themeStr == 'Light') {
          _themeMode = ThemeMode.light;
        } else if (themeStr == 'Dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }

        if (data['favorite_stations'] != null) {
          _favoriteStations = (data['favorite_stations'] as List)
              .map((item) => Station.fromJson(item))
              .toList();
        }

        if (data['favorite_trips'] != null) {
          _favoriteTrips = (data['favorite_trips'] as List).map((item) {
            return {
              "origin": Station.fromJson(item['origin']),
              "dest": Station.fromJson(item['dest']),
            };
          }).toList();
        }

        if (data['recent_searches'] != null) {
          _recentSearches = List<String>.from(data['recent_searches']);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppConfig] Error loading settings: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeStr = 'Auto';
      if (_themeMode == ThemeMode.light) themeStr = 'Light';
      if (_themeMode == ThemeMode.dark) themeStr = 'Dark';

      final data = {
        'api_key': _apiKey,
        'base_url': _baseUrl,
        'mock_fallback': _mockFallback,
        'language': _language,
        'theme': themeStr,
        'accent_color': _accentColor,
        'auto_refresh_interval': _autoRefreshInterval,
        'favorite_stations': _favoriteStations.map((s) => s.toJson()).toList(),
        'favorite_trips': _favoriteTrips.map((t) => {
          'origin': t['origin']!.toJson(),
          'dest': t['dest']!.toJson(),
        }).toList(),
        'recent_searches': _recentSearches,
      };
      await prefs.setString(_keySettings, jsonEncode(data));
      notifyListeners();
    } catch (e) {
      debugPrint('[AppConfig] Error saving settings: $e');
    }
  }

  void setApiKey(String key) {
    _apiKey = key;
    saveSettings();
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    saveSettings();
  }

  void setMockFallback(bool fallback) {
    _mockFallback = fallback;
    saveSettings();
  }

  void setLanguage(String lang) {
    _language = lang;
    saveSettings();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    saveSettings();
  }

  void setAccentColor(String color) {
    _accentColor = color;
    saveSettings();
  }

  void setAutoRefreshInterval(int interval) {
    _autoRefreshInterval = interval;
    saveSettings();
  }

  void addFavoriteStation(Station station) {
    if (!_favoriteStations.any((s) => s.id == station.id || s.name == station.name)) {
      _favoriteStations.add(station);
      saveSettings();
    }
  }

  void removeFavoriteStation(String stationId) {
    _favoriteStations.removeWhere((s) => s.id == stationId);
    saveSettings();
  }

  bool isFavoriteStation(String stationId) {
    return _favoriteStations.any((s) => s.id == stationId);
  }

  void addFavoriteTrip(Station origin, Station dest) {
    bool exists = _favoriteTrips.any((t) =>
        t['origin']?.name == origin.name && t['dest']?.name == dest.name);
    if (!exists) {
      _favoriteTrips.add({"origin": origin, "dest": dest});
      saveSettings();
    }
  }

  void removeFavoriteTrip(int index) {
    if (index >= 0 && index < _favoriteTrips.length) {
      _favoriteTrips.removeAt(index);
      saveSettings();
    }
  }

  void addRecentSearch(String query) {
    query = query.trim();
    if (query.isEmpty) return;
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 20) {
      _recentSearches = _recentSearches.sublist(0, 20);
    }
    saveSettings();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    saveSettings();
  }
}

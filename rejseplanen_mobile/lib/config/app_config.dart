import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station.dart';
import '../models/trip.dart';
import '../services/notification_service.dart';
import '../services/smart_transit_service.dart';

class AppConfig extends ChangeNotifier {
  static const String appVersion = '1.2.4';
  static const int appBuildNumber = 25;
  static const String androidPackageName = 'com.spor.mobile';
  static const String googlePlayUrl = 'https://play.google.com/store/apps/details?id=$androidPackageName';
  static const String googlePlayMarketUri = 'market://details?id=$androidPackageName';
  static const String privacyPolicyUrl = 'https://github.com/gwj0323/spor-app/blob/main/PRIVACY_POLICY.md';

  static const String _keySettings = 'rejseplanen_settings';
  static const String _keyApiKey = 'rejseplanen_api_key';
  static const String _keyBaseUrl = 'rejseplanen_base_url';

  final SmartTransitService smartService = SmartTransitService();

  String _apiKey = '';
  String _baseUrl = 'https://www.rejseplanen.dk/api';
  bool _mockFallback = true;
  String _language = 'system'; // 'system' (Follow system), 'zh_CN', 'en_US', 'da_DK'
  ThemeMode _themeMode = ThemeMode.system;
  String _accentColor = 'system'; // 'system' (Material You) or hex like '#C72027'
  String _navBarStyle = 'liquid_glass'; // 'liquid_glass' (iOS 27 Fluid Blur) or 'material3' (Classic Docked)
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
  List<Station> _recentStations = [];

  // Getters
  String get apiKey => _apiKey;
  String get baseUrl => _baseUrl;
  bool get mockFallback => _mockFallback;
  String get language => _language;
  List<Station> get recentStations => _recentStations;

  /// Effective language code ('zh_CN', 'en_US', 'da_DK') resolving 'system' to device locale
  String get effectiveLanguage {
    if (_language != 'system') return _language;
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final code = locale.languageCode.toLowerCase();
      if (code == 'zh') return 'zh_CN';
      if (code == 'da') return 'da_DK';
    } catch (_) {}
    return 'en_US';
  }

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
  String get navBarStyle => _navBarStyle;
  List<Station> get favoriteStations => _favoriteStations;
  List<Map<String, Station>> get favoriteTrips => _favoriteTrips;
  List<String> get recentSearches => _recentSearches;

  final Set<String> _activeTripReminderIds = {};
  bool isTripReminderActive(String tripIdx) => _activeTripReminderIds.contains(tripIdx);
  void setTripReminderActive(String tripIdx, bool active) {
    if (active) {
      _activeTripReminderIds.add(tripIdx);
    } else {
      _activeTripReminderIds.remove(tripIdx);
    }
    notifyListeners();
  }

  final Set<String> _activeArrivalAlarmIds = {};
  bool isArrivalAlarmActive(String tripIdx) => _activeArrivalAlarmIds.contains(tripIdx);
  void setArrivalAlarmActive(String tripIdx, bool active) {
    if (active) {
      _activeArrivalAlarmIds.add(tripIdx);
    } else {
      _activeArrivalAlarmIds.remove(tripIdx);
    }
    notifyListeners();
  }

  void recordRouteSearch(Station origin, Station dest) {
    smartService.recordCommuteAction(origin, dest, weight: 1.0);
    saveSettings();
  }

  void recordTripChoice(
    Station origin,
    Station dest,
    TripProposal chosen,
    List<TripProposal> candidates,
  ) {
    smartService.recordCommuteAction(origin, dest, weight: 2.5);
    smartService.learnFromTripSelection(chosen, candidates);
    saveSettings();
  }

  void recordBoardStationView(Station station) {
    smartService.recordBoardStationView(station);
    saveSettings();
  }

  void resetMlModel({bool clearHistory = false}) {
    smartService.resetMlState(clearHistory: clearHistory);
    saveSettings();
    notifyListeners();
  }

  String? _activeOngoingTripIdx;
  TripProposal? _activeOngoingTrip;
  Station? _activeOngoingOrigin;
  Station? _activeOngoingDest;
  Timer? _ongoingTripTimer;

  String? get activeOngoingTripIdx => _activeOngoingTripIdx;
  TripProposal? get activeOngoingTrip => _activeOngoingTrip;
  Station? get activeOngoingOrigin => _activeOngoingOrigin;
  Station? get activeOngoingDest => _activeOngoingDest;
  bool isOngoingTripActive(String tripIdx) => _activeOngoingTripIdx == tripIdx;
  bool get hasActiveOngoingTrip => _activeOngoingTripIdx != null;

  void startOngoingTrip(TripProposal trip, Station origin, Station dest) {
    _activeOngoingTripIdx = trip.idx;
    _activeOngoingTrip = trip;
    _activeOngoingOrigin = origin;
    _activeOngoingDest = dest;
    _ongoingTripTimer?.cancel();
    _ongoingTripTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_activeOngoingTrip != null && _activeOngoingOrigin != null && _activeOngoingDest != null) {
        NotificationService().showOngoingTripNotification(
          trip: _activeOngoingTrip!,
          origin: _activeOngoingOrigin!,
          destination: _activeOngoingDest!,
          lang: effectiveLanguage,
        );
      }
    });
    notifyListeners();
  }

  void stopOngoingTrip() {
    _ongoingTripTimer?.cancel();
    _ongoingTripTimer = null;
    _activeOngoingTripIdx = null;
    _activeOngoingTrip = null;
    _activeOngoingOrigin = null;
    _activeOngoingDest = null;
    notifyListeners();
  }

  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  Future<void>? _loadFuture;

  AppConfig() {
    loadSettings();
  }

  Future<void> loadSettings() {
    _loadFuture ??= _doLoadSettings();
    return _loadFuture!;
  }

  Future<void> _doLoadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final standaloneKey = prefs.getString(_keyApiKey);
      final standaloneUrl = prefs.getString(_keyBaseUrl);

      final dataStr = prefs.getString(_keySettings);
      if (dataStr != null) {
        final data = jsonDecode(dataStr) as Map<String, dynamic>;
        _apiKey = standaloneKey ?? (data['api_key'] ?? '');
        _baseUrl = standaloneUrl ?? (data['base_url'] ?? 'https://www.rejseplanen.dk/api');
        _mockFallback = data['mock_fallback'] ?? true;
        _language = data['language'] ?? 'system';
        _autoRefreshInterval = data['auto_refresh_interval'] ?? 30;
        _accentColor = data['accent_color'] ?? 'system';
        _navBarStyle = data['nav_bar_style'] ?? 'liquid_glass';

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

        if (data['recent_stations'] != null) {
          _recentStations = (data['recent_stations'] as List)
              .map((s) => Station.fromJson(Map<String, dynamic>.from(s)))
              .toList();
        }

        if (data['recent_searches'] != null) {
          _recentSearches = List<String>.from(data['recent_searches']);
          if (_recentStations.isEmpty) {
            _recentStations = _recentSearches
                .map((name) => Station(id: name, name: name))
                .toList();
          }
        }
      } else {
        if (standaloneKey != null) _apiKey = standaloneKey;
        if (standaloneUrl != null) _baseUrl = standaloneUrl;
      }
      await smartService.loadFromPrefs(prefs);
      debugPrint('[AppConfig] Loaded settings. apiKey: ${_apiKey.isNotEmpty ? "SET (${_apiKey.length} chars)" : "EMPTY"}, language: $_language');
      notifyListeners();
    } catch (e) {
      debugPrint('[AppConfig] Error loading settings: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyApiKey, _apiKey);
      await prefs.setString(_keyBaseUrl, _baseUrl);

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
        'nav_bar_style': _navBarStyle,
        'auto_refresh_interval': _autoRefreshInterval,
        'favorite_stations': _favoriteStations.map((s) => s.toJson()).toList(),
        'favorite_trips': _favoriteTrips.map((t) => {
          'origin': t['origin']!.toJson(),
          'dest': t['dest']!.toJson(),
        }).toList(),
        'recent_stations': _recentStations.map((s) => s.toJson()).toList(),
        'recent_searches': _recentSearches,
      };
      await prefs.setString(_keySettings, jsonEncode(data));
      await smartService.saveToPrefs(prefs);
      debugPrint('[AppConfig] Saved settings to disk. apiKey length: ${_apiKey.length}');
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

  void setNavBarStyle(String style) {
    if (_navBarStyle != style) {
      _navBarStyle = style;
      saveSettings();
    }
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

  void addRecentStation(Station station) {
    if (station.name.trim().isEmpty) return;
    _recentStations.removeWhere((s) =>
        s.id == station.id || s.name.trim().toLowerCase() == station.name.trim().toLowerCase());
    _recentStations.insert(0, station);
    if (_recentStations.length > 20) {
      _recentStations = _recentStations.sublist(0, 20);
    }

    _recentSearches.removeWhere(
        (name) => name.trim().toLowerCase() == station.name.trim().toLowerCase());
    _recentSearches.insert(0, station.name);
    if (_recentSearches.length > 20) {
      _recentSearches = _recentSearches.sublist(0, 20);
    }
    saveSettings();
  }

  void removeRecentStation(String stationId) {
    _recentStations.removeWhere((s) => s.id == stationId || s.name == stationId);
    _recentSearches.removeWhere((name) => name == stationId);
    saveSettings();
  }

  void clearRecentStations() {
    _recentStations.clear();
    _recentSearches.clear();
    saveSettings();
  }

  void addRecentSearch(String query) {
    query = query.trim();
    if (query.isEmpty) return;
    addRecentStation(Station(id: query, name: query));
  }

  void clearRecentSearches() {
    clearRecentStations();
  }
}

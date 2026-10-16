import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../models/departure.dart';
import '../models/trip.dart';
import '../i18n/translations.dart';
import 'mock_data.dart';
import 'location_service.dart';

class ApiResult<T> {
  final T data;
  final bool isMock;
  final String? error;

  ApiResult({required this.data, required this.isMock, this.error});
}

class RejseplanenApiClient {
  final AppConfig config;
  static final http.Client _client = http.Client();

  static final Map<String, String> _stationIdCache = {
    "8600626": "A=1@O=København H@X=12565562@Y=55673063@U=86@L=8600626@p=1791796388@",
    "København H": "A=1@O=København H@X=12565562@Y=55673063@U=86@L=8600626@p=1791796388@",
    "8600646": "A=1@O=Nørreport St.@X=12571801@Y=55683455@U=86@L=8600646@p=1791796388@",
    "8600030": "A=1@O=Nørreport St.@X=12571801@Y=55683455@U=86@L=8600646@p=1791796388@",
    "Nørreport St.": "A=1@O=Nørreport St.@X=12571801@Y=55683455@U=86@L=8600646@p=1791796388@",
    "8603308": "A=1@O=Kongens Nytorv St. (Metro)@X=12585231@Y=55679185@U=86@L=8603308@p=1791796388@",
    "Kongens Nytorv": "A=1@O=Kongens Nytorv St. (Metro)@X=12585231@Y=55679185@U=86@L=8603308@p=1791796388@",
    "Kongens Nytorv St. (Metro)": "A=1@O=Kongens Nytorv St. (Metro)@X=12585231@Y=55679185@U=86@L=8603308@p=1791796388@",
    "8600858": "A=1@O=CPH Lufthavn@X=12649162@Y=55629439@U=86@L=8600858@p=1791796388@",
    "CPH Lufthavn": "A=1@O=CPH Lufthavn@X=12649162@Y=55629439@U=86@L=8600858@p=1791796388@",
    "8600650": "A=1@O=Østerport St.@X=12587784@Y=55692498@U=86@L=8600650@p=1791796388@",
    "Østerport St.": "A=1@O=Østerport St.@X=12587784@Y=55692498@U=86@L=8600650@p=1791796388@",
    "8600053": "A=1@O=Aarhus H@X=10204761@Y=56150444@U=86@L=8600053@p=1791796388@",
    "Aarhus H": "A=1@O=Aarhus H@X=10204761@Y=56150444@U=86@L=8600053@p=1791796388@",
    "8600512": "A=1@O=Odense St.@X=10386739@Y=55401778@U=86@L=8600512@p=1791796388@",
    "Odense St.": "A=1@O=Odense St.@X=10386739@Y=55401778@U=86@L=8600512@p=1791796388@",
    "8600020": "A=1@O=Aalborg St.@X=9917044@Y=57043037@U=86@L=8600020@p=1791796388@",
    "Aalborg St.": "A=1@O=Aalborg St.@X=9917044@Y=57043037@U=86@L=8600020@p=1791796388@",
    "8600617": "A=1@O=Roskilde St.@X=12088550@Y=55639093@U=86@L=8600617@p=1791796388@",
    "Roskilde St.": "A=1@O=Roskilde St.@X=12088550@Y=55639093@U=86@L=8600617@p=1791796388@",
    "8600669": "A=1@O=Helsingør St.@X=12614167@Y=56033621@U=86@L=8600669@p=1791796388@",
    "Helsingør St.": "A=1@O=Helsingør St.@X=12614167@Y=56033621@U=86@L=8600669@p=1791796388@"
  };

  RejseplanenApiClient(this.config);

  String _formatTimeStr(String tStr) {
    if (tStr.isEmpty) return "";
    final parts = tStr.trim().split(":");
    if (parts.length >= 2) {
      return "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}";
    }
    return tStr;
  }

  String? _normalizeDateStr(String? dStr) {
    if (dStr == null || dStr.trim().isEmpty) return null;
    dStr = dStr.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dStr)) return dStr;
    final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{2,4})$').firstMatch(dStr);
    if (m != null) {
      String day = m.group(1)!.padLeft(2, '0');
      String month = m.group(2)!.padLeft(2, '0');
      String year = m.group(3)!;
      if (year.length == 2) year = "20$year";
      return "$year-$month-$day";
    }
    return dStr;
  }

  int _parseTimeDiffMin(String timeStr, String rtTimeStr) {
    if (timeStr.isEmpty || rtTimeStr.isEmpty) return 0;
    final t1S = _formatTimeStr(timeStr);
    final t2S = _formatTimeStr(rtTimeStr);
    if (t1S == t2S) return 0;
    try {
      final p1 = t1S.split(':').map(int.parse).toList();
      final p2 = t2S.split(':').map(int.parse).toList();
      int m1 = p1[0] * 60 + p1[1];
      int m2 = p2[0] * 60 + p2[1];
      int diff = m2 - m1;
      if (diff < -720) diff += 1440;
      if (diff > 720) diff -= 1440;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Parse an ISO 8601 duration such as 'PT1H30M', 'P1DT2H5M' or 'PT45M'
  /// into total minutes. Returns 0 for empty or unparseable input.
  int _parseIsoDurationMinutes(String durationStr) {
    if (durationStr.isEmpty) return 0;
    final m = RegExp(
      r'^P(?!$)(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
      caseSensitive: false,
    ).firstMatch(durationStr.trim());
    if (m == null) return 0;
    final days = int.tryParse(m.group(1) ?? '') ?? 0;
    final hours = int.tryParse(m.group(2) ?? '') ?? 0;
    final minutes = int.tryParse(m.group(3) ?? '') ?? 0;
    final seconds = int.tryParse(m.group(4) ?? '') ?? 0;
    return days * 1440 + hours * 60 + minutes + (seconds >= 30 ? 1 : 0);
  }

  List<dynamic> _ensureList(dynamic item) {
    if (item == null) return [];
    if (item is List) return item;
    return [item];
  }

  Future<String> _resolveStationHafasId(String query) async {
    if (query.isEmpty || query.startsWith("A=")) return query;
    if (_stationIdCache.containsKey(query)) return _stationIdCache[query]!;

    final key = config.apiKey.trim();
    if (key.isEmpty) return query;

    try {
      final uri = Uri.parse("${config.baseUrl}/location.name").replace(queryParameters: {
        "input": query,
        "accessId": key,
        "format": "json"
      });
      final resp = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final rawItems = data["stopLocationOrCoordLocation"] as List? ?? [];
        for (var item in rawItems) {
          final stop = item["StopLocation"] ?? item["CoordLocation"];
          if (stop != null && stop["id"] != null) {
            String fullId = stop["id"].toString();
            _stationIdCache[query] = fullId;
            if (stop["extId"] != null) {
              _stationIdCache[stop["extId"].toString()] = fullId;
            }
            if (stop["name"] != null) {
              _stationIdCache[stop["name"].toString()] = fullId;
            }
            return fullId;
          }
        }
      }
    } catch (_) {}
    return query;
  }

  Future<Map<String, dynamic>> testConnection({String? apiKey, String? baseUrl}) async {
    final key = (apiKey ?? config.apiKey).trim();
    final url = (baseUrl ?? config.baseUrl).replaceAll(RegExp(r'/+$'), '');
    final lang = config.effectiveLanguage;

    if (key.isEmpty) {
      return {"success": false, "message": I18n.tr("conn_test_empty_key", lang)};
    }

    final uri = Uri.parse("$url/location.name").replace(queryParameters: {
      "input": "København H",
      "accessId": key,
      "format": "json"
    });

    try {
      final resp = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        try {
          final data = jsonDecode(resp.body);
          final rawItems = data["stopLocationOrCoordLocation"] as List? ?? [];
          if (rawItems.isNotEmpty) {
            final firstStop = rawItems[0]["StopLocation"] ?? rawItems[0]["CoordLocation"] ?? {};
            final sampleName = firstStop["name"]?.toString() ?? "København H";
            return {
              "success": true,
              "message": I18n.tr("conn_test_success", lang, {
                "count": "${rawItems.length}",
                "sample": sampleName,
              })
            };
          }
        } catch (_) {}
        return {
          "success": true,
          "message": I18n.tr("conn_ok", lang)
        };
      } else {
        return {
          "success": false,
          "message": I18n.tr("conn_test_http_err", lang, {
            "code": "${resp.statusCode}",
            "reason": resp.reasonPhrase ?? resp.body,
          })
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": I18n.tr("conn_test_net_err", lang, {"error": "$e"})
      };
    }
  }

  Future<ApiResult<List<Station>>> searchLocations(String query) async {
    final key = config.apiKey.trim();
    final lang = config.effectiveLanguage;
    if (key.isEmpty) {
      if (config.mockFallback) {
        return ApiResult(data: MockData.searchStations(query), isMock: true);
      }
      return ApiResult(data: [], isMock: false, error: I18n.tr("api_err_no_key_no_mock", lang));
    }

    try {
      final uri = Uri.parse("${config.baseUrl}/location.name").replace(queryParameters: {
        "input": query,
        "accessId": key,
        "format": "json"
      });
      final resp = await _client.get(uri).timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        List<Station> results = [];
        final rawItems = data["stopLocationOrCoordLocation"] as List? ?? [];
        for (var item in rawItems) {
          final stop = item["StopLocation"] ?? item["CoordLocation"];
          if (stop != null) {
            String fullId = stop["id"]?.toString() ?? "";
            String extId = stop["extId"]?.toString() ?? "";
            String name = stop["name"]?.toString() ?? "";
            if (fullId.isNotEmpty && extId.isNotEmpty) {
              _stationIdCache[extId] = fullId;
            }
            if (fullId.isNotEmpty && name.isNotEmpty) {
              _stationIdCache[name] = fullId;
            }
            results.add(Station(
              id: fullId.isNotEmpty ? fullId : extId,
              extId: extId,
              name: name,
              lat: (stop["lat"] ?? stop["y"] ?? 0.0).toDouble(),
              lon: (stop["lon"] ?? stop["x"] ?? 0.0).toDouble(),
              types: const ["ST"],
            ));
          }
        }
        if (results.isNotEmpty) {
          return ApiResult(data: results, isMock: false);
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] searchLocations error: $e');
    }

    if (config.mockFallback) {
      return ApiResult(data: MockData.searchStations(query), isMock: true);
    }
    return ApiResult(data: [], isMock: false, error: I18n.tr("api_err_no_stations", lang));
  }

  Future<ApiResult<List<Station>>> nearbyStops(double lat, double lon, {int maxNo = 15, int radiusMeters = 10000}) async {
    final bool userInDenmark = LocationService.isInDenmark(lat, lon);
    final lang = config.effectiveLanguage;

    // If user is clearly outside Denmark (e.g. testing from China or outside Nordic region)
    if (!userInDenmark) {
      if (config.mockFallback) {
        final mock = List<Station>.from(MockData.stations);
        mock.sort((a, b) =>
            ((a.lat - lat) * (a.lat - lat) + (a.lon - lon) * (a.lon - lon))
                .compareTo((b.lat - lat) * (b.lat - lat) + (b.lon - lon) * (b.lon - lon)));
        final withDist = mock.take(maxNo).map((s) {
          return Station(
            id: s.id,
            extId: s.extId,
            name: s.name,
            lat: s.lat,
            lon: s.lon,
            types: s.types,
            desc: s.desc,
            distance: LocationService.formatDistance(lat, lon, s.lat, s.lon),
          );
        }).toList();
        return ApiResult(
          data: withDist,
          isMock: true,
          error: "OUTSIDE_DENMARK",
        );
      }
      return ApiResult(data: [], isMock: false, error: "OUTSIDE_DENMARK");
    }

    final key = config.apiKey.trim();
    if (key.isEmpty) {
      if (config.mockFallback) {
        final mock = List<Station>.from(MockData.stations);
        mock.sort((a, b) =>
            ((a.lat - lat) * (a.lat - lat) + (a.lon - lon) * (a.lon - lon))
                .compareTo((b.lat - lat) * (b.lat - lat) + (b.lon - lon) * (b.lon - lon)));
        final withDist = mock.take(maxNo).map((s) {
          return Station(
            id: s.id,
            extId: s.extId,
            name: s.name,
            lat: s.lat,
            lon: s.lon,
            types: s.types,
            desc: s.desc,
            distance: LocationService.formatDistance(lat, lon, s.lat, s.lon),
          );
        }).toList();
        return ApiResult(data: withDist, isMock: true);
      }
      return ApiResult(data: [], isMock: false, error: I18n.tr("api_err_no_key_no_mock", lang));
    }

    try {
      final uri = Uri.parse("${config.baseUrl}/location.nearbystops").replace(queryParameters: {
        "originCoordLat": lat.toString(),
        "originCoordLong": lon.toString(),
        "maxNo": maxNo.toString(),
        "r": radiusMeters.toString(),
        "accessId": key,
        "format": "json"
      });
      final resp = await _client.get(uri).timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        List<Station> results = [];
        final rawItems = data["stopLocationOrCoordLocation"] as List? ?? [];
        for (var item in rawItems) {
          final stop = item["StopLocation"] ?? item["CoordLocation"];
          if (stop != null) {
            String? distStr = stop["dist"]?.toString();
            if (distStr != null && RegExp(r'^\d+$').hasMatch(distStr)) {
              distStr = "$distStr m";
            }
            double sLat = (stop["lat"] ?? stop["y"] ?? 0.0).toDouble();
            double sLon = (stop["lon"] ?? stop["x"] ?? 0.0).toDouble();
            if (distStr == null && sLat != 0.0) {
              distStr = LocationService.formatDistance(lat, lon, sLat, sLon);
            }
            results.add(Station(
              id: (stop["id"] ?? stop["extId"] ?? "").toString(),
              extId: (stop["extId"] ?? "").toString(),
              name: stop["name"]?.toString() ?? "",
              lat: sLat,
              lon: sLon,
              distance: distStr,
            ));
          }
        }
        if (results.isNotEmpty) {
          return ApiResult(data: results, isMock: false);
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] nearbyStops error: $e');
    }

    if (config.mockFallback) {
      final mock = List<Station>.from(MockData.stations);
      mock.sort((a, b) =>
          ((a.lat - lat) * (a.lat - lat) + (a.lon - lon) * (a.lon - lon))
              .compareTo((b.lat - lat) * (b.lat - lat) + (b.lon - lon) * (b.lon - lon)));
      final withDist = mock.take(maxNo).map((s) {
        return Station(
          id: s.id,
          extId: s.extId,
          name: s.name,
          lat: s.lat,
          lon: s.lon,
          types: s.types,
          desc: s.desc,
          distance: LocationService.formatDistance(lat, lon, s.lat, s.lon),
        );
      }).toList();
      return ApiResult(data: withDist, isMock: true);
    }
    return ApiResult(data: [], isMock: false, error: I18n.tr("station_empty_nearby", lang));
  }

  Future<ApiResult<List<Departure>>> getDepartureBoard(
    String stationId, {
    String? dateStr,
    String? timeStr,
    bool useBus = true,
    bool useTrain = true,
    bool useMetro = true,
  }) async {
    final key = config.apiKey.trim();
    final lang = config.effectiveLanguage;
    if (key.isEmpty) {
      if (config.mockFallback) {
        return ApiResult(data: MockData.getDepartures(stationId), isMock: true);
      }
      return ApiResult(data: [], isMock: false, error: I18n.tr("api_err_no_key_no_mock", lang));
    }

    try {
      final resolvedId = await _resolveStationHafasId(stationId);
      final params = <String, String>{
        "id": resolvedId,
        "accessId": key,
        "format": "json",
        "useBus": useBus ? "1" : "0",
        "useTrain": useTrain ? "1" : "0",
        "useMetro": useMetro ? "1" : "0",
      };
      if (dateStr != null) {
        final d = _normalizeDateStr(dateStr);
        if (d != null) params["date"] = d;
      }
      if (timeStr != null) {
        params["time"] = _formatTimeStr(timeStr);
      }

      final uri = Uri.parse("${config.baseUrl}/departureBoard").replace(queryParameters: params);
      final resp = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        var rawDeps = data["Departure"];
        if (rawDeps == null) {
          final board = data["DepartureBoard"] ?? data["departureBoard"] ?? {};
          rawDeps = board["Departure"] ?? board["departure"] ?? [];
        }
        final list = _ensureList(rawDeps);
        List<Departure> departures = [];

        for (var d in list) {
          String schedTime = _formatTimeStr(d["time"]?.toString() ?? "");
          String rtTime = _formatTimeStr(d["rtTime"]?.toString() ?? schedTime);
          int delayMin = _parseTimeDiffMin(schedTime, rtTime);

          String status = "normal";
          if (d["cancelled"] == true || d["cancelled"] == "true" || d["cancelled"] == "1") {
            status = "cancelled";
          } else if (delayMin >= 5) {
            status = "delayed";
          } else if (delayMin > 0) {
            status = "minor_delay";
          }

          final prod = d["ProductAtStop"] ?? {};
          String cat = prod["catOut"]?.toString() ?? d["type"]?.toString() ?? "TOG";

          String track = d["rtTrack"]?.toString() ?? d["track"]?.toString() ?? "";
          if (track.isEmpty && d["rtPlatform"] is Map) {
            track = d["rtPlatform"]["text"]?.toString() ?? "";
          }
          if (track.isEmpty) track = "-";

          String? jRef;
          final jObj = d["JourneyDetailRef"] ?? d["journeyDetailRef"];
          if (jObj is Map) {
            jRef = jObj["ref"]?.toString();
          } else if (jObj is String) {
            jRef = jObj;
          }

          departures.add(Departure(
            name: d["name"]?.toString() ?? prod["name"]?.toString() ?? "Transit",
            type: cat,
            stop: d["stop"]?.toString() ?? "",
            direction: d["direction"]?.toString() ?? d["stop"]?.toString() ?? "",
            time: schedTime,
            date: d["date"]?.toString() ?? "",
            rtTime: rtTime,
            rtDate: d["rtDate"]?.toString() ?? d["date"]?.toString() ?? "",
            track: track,
            delay: delayMin,
            status: status,
            messages: d["messages"]?.toString() ?? "",
            journeyDetailRef: jRef,
          ));
        }

        if (departures.isNotEmpty) {
          return ApiResult(data: departures, isMock: false);
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] getDepartureBoard error: $e');
    }

    if (config.mockFallback) {
      return ApiResult(data: MockData.getDepartures(stationId), isMock: true);
    }
    return ApiResult(data: [], isMock: false, error: I18n.tr("api_err_no_departures", lang));
  }

  Future<ApiResult<List<Departure>>> getArrivalBoard(
    String stationId, {
    String? dateStr,
    String? timeStr,
    bool useBus = true,
    bool useTrain = true,
    bool useMetro = true,
  }) async {
    final key = config.apiKey.trim();
    final lang = config.effectiveLanguage;
    if (key.isEmpty) {
      if (config.mockFallback) {
        return ApiResult(data: MockData.getArrivals(stationId), isMock: true);
      }
      return ApiResult(data: [], isMock: false, error: I18n.tr("api_err_no_key_no_mock", lang));
    }

    try {
      final resolvedId = await _resolveStationHafasId(stationId);
      final params = <String, String>{
        "id": resolvedId,
        "accessId": key,
        "format": "json",
        "useBus": useBus ? "1" : "0",
        "useTrain": useTrain ? "1" : "0",
        "useMetro": useMetro ? "1" : "0",
      };
      if (dateStr != null) {
        final d = _normalizeDateStr(dateStr);
        if (d != null) params["date"] = d;
      }
      if (timeStr != null) {
        params["time"] = _formatTimeStr(timeStr);
      }

      final uri = Uri.parse("${config.baseUrl}/arrivalBoard").replace(queryParameters: params);
      final resp = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        var rawArrs = data["Arrival"];
        if (rawArrs == null) {
          final board = data["ArrivalBoard"] ?? data["arrivalBoard"] ?? {};
          rawArrs = board["Arrival"] ?? board["arrival"] ?? [];
        }
        final list = _ensureList(rawArrs);
        List<Departure> arrivals = [];

        for (var a in list) {
          String schedTime = _formatTimeStr(a["time"]?.toString() ?? "");
          String rtTime = _formatTimeStr(a["rtTime"]?.toString() ?? schedTime);
          int delayMin = _parseTimeDiffMin(schedTime, rtTime);

          String status = "normal";
          if (a["cancelled"] == true || a["cancelled"] == "true" || a["cancelled"] == "1") {
            status = "cancelled";
          } else if (delayMin >= 5) {
            status = "delayed";
          } else if (delayMin > 0) {
            status = "minor_delay";
          }

          final prod = a["ProductAtStop"] ?? {};
          String cat = prod["catOut"]?.toString() ?? a["type"]?.toString() ?? "TOG";

          String track = a["rtTrack"]?.toString() ?? a["track"]?.toString() ?? "";
          if (track.isEmpty && a["rtPlatform"] is Map) {
            track = a["rtPlatform"]["text"]?.toString() ?? "";
          }
          if (track.isEmpty) track = "-";

          String? jRef;
          final jObj = a["JourneyDetailRef"] ?? a["journeyDetailRef"];
          if (jObj is Map) {
            jRef = jObj["ref"]?.toString();
          } else if (jObj is String) {
            jRef = jObj;
          }

          arrivals.add(Departure(
            name: a["name"]?.toString() ?? prod["name"]?.toString() ?? "Transit",
            type: cat,
            stop: a["stop"]?.toString() ?? "",
            direction: a["origin"]?.toString() ?? a["stop"]?.toString() ?? "",
            time: schedTime,
            date: a["date"]?.toString() ?? "",
            rtTime: rtTime,
            rtDate: a["rtDate"]?.toString() ?? a["date"]?.toString() ?? "",
            track: track,
            delay: delayMin,
            status: status,
            messages: a["messages"]?.toString() ?? "",
            journeyDetailRef: jRef,
          ));
        }

        if (arrivals.isNotEmpty) {
          return ApiResult(data: arrivals, isMock: false);
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] getArrivalBoard error: $e');
    }

    if (config.mockFallback) {
      return ApiResult(data: MockData.getArrivals(stationId), isMock: true);
    }
    return ApiResult(data: [], isMock: false, error: I18n.tr("api_err_no_arrivals", lang));
  }

  Future<ApiResult<List<TripProposal>>> getTrips(
    String originId,
    String destId, {
    String? dateStr,
    String? timeStr,
    bool searchForArrival = false,
    bool useBus = true,
    bool useTrain = true,
    bool useMetro = true,
  }) async {
    final key = config.apiKey.trim();
    final lang = config.effectiveLanguage;
    if (key.isEmpty) {
      if (config.mockFallback) {
        return ApiResult(data: MockData.getTrips(originId, destId), isMock: true);
      }
      return ApiResult(data: [], isMock: false, error: I18n.tr("api_err_no_key_no_mock", lang));
    }

    try {
      final origResolved = await _resolveStationHafasId(originId);
      final destResolved = await _resolveStationHafasId(destId);

      final params = <String, String>{
        "originId": origResolved,
        "destId": destResolved,
        "accessId": key,
        "format": "json",
        "searchForArrival": searchForArrival ? "1" : "0",
        "useBus": useBus ? "1" : "0",
        "useTrain": useTrain ? "1" : "0",
        "useMetro": useMetro ? "1" : "0",
      };

      if (dateStr != null) {
        final d = _normalizeDateStr(dateStr);
        if (d != null) params["date"] = d;
      }
      if (timeStr != null) {
        params["time"] = _formatTimeStr(timeStr);
      }

      final uri = Uri.parse("${config.baseUrl}/trip").replace(queryParameters: params);
      final resp = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        var rawTrips = data["Trip"];
        if (rawTrips == null) {
          final tripList = data["TripList"] ?? data["tripList"] ?? {};
          rawTrips = tripList["Trip"] ?? tripList["trip"] ?? [];
        }
        final list = _ensureList(rawTrips);
        List<TripProposal> trips = [];

        int idx = 1;
        for (var t in list) {
          final legList = t["LegList"] ?? {};
          final legsRaw = _ensureList(legList["Leg"] ?? t["Leg"] ?? []);
          List<TripLeg> parsedLegs = [];

          Map<String, dynamic>? firstOrigin;
          Map<String, dynamic>? lastDest;
          int changesCount = 0;

          for (var leg in legsRaw) {
            String legType = leg["type"]?.toString() ?? "TOG";
            if (legType.toUpperCase() != "WALK") {
              changesCount++;
            }

            final prods = _ensureList(leg["Product"]);
            String cat = prods.isNotEmpty && prods[0]["catOut"] != null
                ? prods[0]["catOut"].toString()
                : (leg["category"]?.toString() ?? legType);

            final orig = leg["Origin"] ?? leg["origin"] ?? {};
            final dest = leg["Destination"] ?? leg["destination"] ?? {};

            firstOrigin ??= orig;
            lastDest = dest;

            String? jRef;
            final jObj = leg["JourneyDetailRef"] ?? leg["journeyDetailRef"];
            if (jObj is Map) {
              jRef = jObj["ref"]?.toString();
            } else if (jObj is String) {
              jRef = jObj;
            }

            final stopsRaw = _ensureList(leg["Stops"]?["Stop"] ?? leg["stops"] ?? leg["Stop"]);
            List<TripStop>? preloadedStops;
            if (stopsRaw.isNotEmpty) {
              preloadedStops = [];
              for (var s in stopsRaw) {
                preloadedStops.add(TripStop(
                  name: s["name"]?.toString() ?? "",
                  time: _formatTimeStr(s["depTime"]?.toString() ?? s["time"]?.toString() ?? s["arrTime"]?.toString() ?? ""),
                  date: s["depDate"]?.toString() ?? s["date"]?.toString() ?? s["arrDate"]?.toString() ?? "",
                  track: s["rtTrack"]?.toString() ?? s["track"]?.toString() ?? "-",
                  rtTime: _formatTimeStr(s["rtDepTime"]?.toString() ?? s["rtTime"]?.toString() ?? s["rtArrTime"]?.toString() ?? ""),
                ));
              }
            }

            parsedLegs.add(TripLeg(
              type: legType.toUpperCase() == "WALK" ? "WALK" : cat,
              name: leg["name"]?.toString() ?? "Leg",
              direction: leg["direction"]?.toString() ?? "",
              origin: TripStop(
                name: orig["name"]?.toString() ?? "",
                time: _formatTimeStr(orig["time"]?.toString() ?? ""),
                date: orig["date"]?.toString() ?? "",
                track: orig["rtTrack"]?.toString() ?? orig["track"]?.toString() ?? "-",
                rtTime: _formatTimeStr(orig["rtTime"]?.toString() ?? orig["time"]?.toString() ?? ""),
              ),
              destination: TripStop(
                name: dest["name"]?.toString() ?? "",
                time: _formatTimeStr(dest["time"]?.toString() ?? ""),
                date: dest["date"]?.toString() ?? "",
                track: dest["rtTrack"]?.toString() ?? dest["track"]?.toString() ?? "-",
                rtTime: _formatTimeStr(dest["rtTime"]?.toString() ?? dest["time"]?.toString() ?? ""),
              ),
              notes: (leg["Notes"] is Map) ? (leg["Notes"]["text"]?.toString() ?? "") : "",
              journeyDetailRef: jRef,
              stops: preloadedStops,
            ));
          }

          String depTime = _formatTimeStr(firstOrigin?["time"]?.toString() ?? "00:00");
          String arrTime = _formatTimeStr(lastDest?["time"]?.toString() ?? "00:00");
          String depDate = firstOrigin?["date"]?.toString() ?? dateStr ?? "";
          int durationMin = _parseTimeDiffMin(depTime, arrTime);

          if (durationMin == 0 && t["duration"] != null) {
            durationMin = _parseIsoDurationMinutes(t["duration"].toString());
          }

          trips.add(TripProposal(
            idx: "${originId}_${destId}_${depDate}_${depTime}_${arrTime}_${idx++}",
            durationMin: durationMin,
            depTime: depTime,
            arrTime: arrTime,
            changes: changesCount > 0 ? changesCount - 1 : 0,
            legs: parsedLegs,
          ));
        }

        if (trips.isNotEmpty) {
          return ApiResult(data: trips, isMock: false);
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] getTrips error: $e');
    }

    if (config.mockFallback) {
      return ApiResult(data: MockData.getTrips(originId, destId), isMock: true);
    }
    return ApiResult(data: [], isMock: false, error: I18n.tr("api_err_no_trips", lang));
  }

  /// Query intermediate stops and timetable for a specific vehicle journey (journeyDetail)
  Future<ApiResult<List<TripStop>>> getJourneyDetail(
    String refUrlOrParam, {
    String? legName,
    String? originName,
    String? destName,
    String? timeStr,
    String? dateStr,
  }) async {
    final key = config.apiKey.trim();
    String? fetchError;

    if (key.isNotEmpty && refUrlOrParam.trim().isNotEmpty && !refUrlOrParam.startsWith("mock")) {
      try {
        // Extract raw ref string from any format:
        // 1) Full URL: "https://www.rejseplanen.dk/api/journeyDetail?id=..." or "ref=..."
        // 2) Partial param: "journeyDetail?ref=..." or "ref=..." or "id=..."
        // 3) Pure ref token: "2|#VN#1#ST#..."
        String cleanRef = refUrlOrParam.trim();
        if (cleanRef.contains("id=")) {
          final m = RegExp(r'[?&]id=([^&]+)').firstMatch(cleanRef);
          if (m != null) {
            cleanRef = m.group(1)!;
          }
        } else if (cleanRef.contains("ref=")) {
          final m = RegExp(r'[?&]ref=([^&]+)').firstMatch(cleanRef);
          if (m != null) {
            cleanRef = m.group(1)!;
          } else if (cleanRef.startsWith("ref=")) {
            cleanRef = cleanRef.substring(4);
          }
        } else if (cleanRef.startsWith("journeyDetail?")) {
          cleanRef = cleanRef.substring("journeyDetail?".length);
        }

        // Decode if it was already percent-encoded so Uri.replace doesn't double-encode
        try {
          if (cleanRef.contains("%")) {
            cleanRef = Uri.decodeQueryComponent(cleanRef);
          }
        } catch (_) {}

        final base = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
        // In Rejseplanen API 2.0, the parameter is "id", while legacy API 1.0 used "ref".
        // Providing both ensures 100% compatibility across all Rejseplanen backend dialects.
        final uri = Uri.parse("$base/journeyDetail").replace(queryParameters: {
          "id": cleanRef,
          "ref": cleanRef,
          "accessId": key,
          "format": "json",
        });

        debugPrint('[ApiClient] Fetching journeyDetail: $uri');
        final resp = await _client.get(uri).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          if (data is Map<String, dynamic>) {
            final journeyObj = data["JourneyDetail"] ?? data["journeyDetail"] ?? data;

            dynamic rawStops = journeyObj["Stops"]?["Stop"] ??
                journeyObj["stops"]?["stop"] ??
                journeyObj["Stops"] ??
                journeyObj["stops"] ??
                journeyObj["Stop"] ??
                journeyObj["stop"] ??
                data["Stop"] ??
                data["stop"];

            if (rawStops is Map && rawStops.containsKey("Stop")) {
              rawStops = rawStops["Stop"];
            } else if (rawStops is Map && rawStops.containsKey("stop")) {
              rawStops = rawStops["stop"];
            }

            final list = _ensureList(rawStops);
            List<TripStop> stops = [];
            for (var s in list) {
              if (s is! Map) continue;
              String stopName = s["name"]?.toString() ?? s["stop"]?.toString() ?? "";
              if (stopName.trim().isEmpty) continue;

              String depT = _formatTimeStr(s["depTime"]?.toString() ?? s["time"]?.toString() ?? "");
              String arrT = _formatTimeStr(s["arrTime"]?.toString() ?? "");
              String bestTime = depT.isNotEmpty ? depT : arrT;

              String rtDepT = _formatTimeStr(s["rtDepTime"]?.toString() ?? s["rtTime"]?.toString() ?? "");
              String rtArrT = _formatTimeStr(s["rtArrTime"]?.toString() ?? "");
              String bestRtTime = rtDepT.isNotEmpty ? rtDepT : (rtArrT.isNotEmpty ? rtArrT : bestTime);

              String track = s["rtTrack"]?.toString() ?? s["track"]?.toString() ?? "";
              if (track.isEmpty) {
                track = s["rtDepTrack"]?.toString() ?? s["depTrack"]?.toString() ?? s["rtArrTrack"]?.toString() ?? s["arrTrack"]?.toString() ?? "";
              }
              if (track.isEmpty && s["rtPlatform"] is Map) {
                track = s["rtPlatform"]["text"]?.toString() ?? "";
              }
              if (track.isEmpty && s["platform"] is Map) {
                track = s["platform"]["text"]?.toString() ?? "";
              }
              if (track.isEmpty && s["rtDepPlatform"] is Map) {
                track = s["rtDepPlatform"]["text"]?.toString() ?? "";
              }
              if (track.isEmpty && s["depPlatform"] is Map) {
                track = s["depPlatform"]["text"]?.toString() ?? "";
              }
              if (track.isEmpty && s["rtArrPlatform"] is Map) {
                track = s["rtArrPlatform"]["text"]?.toString() ?? "";
              }
              if (track.isEmpty && s["arrPlatform"] is Map) {
                track = s["arrPlatform"]["text"]?.toString() ?? "";
              }
              if (track.isEmpty) track = "-";

              stops.add(TripStop(
                name: stopName,
                time: bestTime,
                date: s["depDate"]?.toString() ?? s["arrDate"]?.toString() ?? s["date"]?.toString() ?? "",
                track: track,
                rtTime: bestRtTime,
              ));
            }
            if (stops.isNotEmpty) {
              return ApiResult(data: stops, isMock: false);
            }
          }
        } else {
          fetchError = "接口请求失败 (HTTP ${resp.statusCode})";
          debugPrint('[ApiClient] getJourneyDetail HTTP error ${resp.statusCode}: ${resp.body}');
        }
      } catch (e) {
        fetchError = "网络请求异常: $e";
        debugPrint('[ApiClient] getJourneyDetail error: $e');
      }
    } else if (key.isEmpty) {
      fetchError = "未配置 API Key，无法查询经停站点";
    } else if (refUrlOrParam.trim().isEmpty) {
      fetchError = "该车次未提供经停站信息";
    }

    if (config.mockFallback) {
      final mockStops = MockData.getJourneyStops(
        legName: legName,
        originName: originName,
        destName: destName,
        timeStr: timeStr,
        dateStr: dateStr,
      );
      return ApiResult(data: mockStops, isMock: true);
    }
    return ApiResult(data: [], isMock: false, error: fetchError ?? "未获取到经停站信息");
  }
}

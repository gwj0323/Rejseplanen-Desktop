import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../models/departure.dart';
import '../models/trip.dart';
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

  final Map<String, String> _stationIdCache = {
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
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
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

    if (key.isEmpty) {
      return {"success": false, "message": "API Key (accessId) 为空，请先输入密钥！"};
    }

    final uri = Uri.parse("$url/location.name").replace(queryParameters: {
      "input": "København H",
      "accessId": key,
      "format": "json"
    });

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return {
          "success": true,
          "message": "API 认证成功！Rejseplanen 官方服务器响应正常 (HTTP 200 OK)。"
        };
      } else {
        String msg = "HTTP ${resp.statusCode}: ${resp.body}";
        if (resp.statusCode == 401) {
          msg += "\n\n提示：401 权限拒绝。请确认 accessId 是否正确，或账号是否已激活 API 2.0。";
        }
        return {"success": false, "message": msg};
      }
    } catch (e) {
      return {"success": false, "message": "网络请求失败: $e"};
    }
  }

  Future<ApiResult<List<Station>>> searchLocations(String query) async {
    final key = config.apiKey.trim();
    if (key.isEmpty) {
      return ApiResult(data: MockData.searchStations(query), isMock: true);
    }

    try {
      final uri = Uri.parse("${config.baseUrl}/location.name").replace(queryParameters: {
        "input": query,
        "accessId": key,
        "format": "json"
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 7));
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
    return ApiResult(data: [], isMock: false, error: "未找到相关站点");
  }

  Future<ApiResult<List<Station>>> nearbyStops(double lat, double lon, {int maxNo = 10}) async {
    final key = config.apiKey.trim();
    if (key.isEmpty) {
      final mock = List<Station>.from(MockData.stations);
      mock.sort((a, b) =>
          ((a.lat - lat) * (a.lat - lat) + (a.lon - lon) * (a.lon - lon))
              .compareTo((b.lat - lat) * (b.lat - lat) + (b.lon - lon) * (b.lon - lon)));
      return ApiResult(data: mock.take(maxNo).toList(), isMock: true);
    }

    try {
      final uri = Uri.parse("${config.baseUrl}/location.nearbystops").replace(queryParameters: {
        "originCoordLat": lat.toString(),
        "originCoordLong": lon.toString(),
        "maxNo": maxNo.toString(),
        "accessId": key,
        "format": "json"
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 7));
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
    return ApiResult(data: [], isMock: false, error: "未找到周边站点");

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
    if (key.isEmpty) {
      return ApiResult(data: MockData.getDepartures(stationId), isMock: true);
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
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));

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
    return ApiResult(data: [], isMock: false, error: "暂无发车信息");
  }

  Future<ApiResult<List<Departure>>> getArrivalBoard(
    String stationId, {
    String? dateStr,
    String? timeStr,
  }) async {
    final key = config.apiKey.trim();
    if (key.isEmpty) {
      return ApiResult(data: MockData.getArrivals(stationId), isMock: true);
    }

    try {
      final resolvedId = await _resolveStationHafasId(stationId);
      final params = <String, String>{
        "id": resolvedId,
        "accessId": key,
        "format": "json",
      };
      if (dateStr != null) {
        final d = _normalizeDateStr(dateStr);
        if (d != null) params["date"] = d;
      }
      if (timeStr != null) {
        params["time"] = _formatTimeStr(timeStr);
      }

      final uri = Uri.parse("${config.baseUrl}/arrivalBoard").replace(queryParameters: params);
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));

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

          final prod = a["ProductAtStop"] ?? {};
          String cat = prod["catOut"]?.toString() ?? a["type"]?.toString() ?? "TOG";

          String track = a["rtTrack"]?.toString() ?? a["track"]?.toString() ?? "";
          if (track.isEmpty && a["rtPlatform"] is Map) {
            track = a["rtPlatform"]["text"]?.toString() ?? "";
          }
          if (track.isEmpty) track = "-";

          arrivals.add(Departure(
            name: a["name"]?.toString() ?? prod["name"]?.toString() ?? "Transit",
            type: cat,
            stop: a["stop"]?.toString() ?? "",
            direction: a["stop"]?.toString() ?? "",
            time: schedTime,
            date: a["date"]?.toString() ?? "",
            rtTime: rtTime,
            rtDate: a["date"]?.toString() ?? "",
            track: track,
            delay: delayMin,
            status: delayMin >= 5 ? "delayed" : (delayMin > 0 ? "minor_delay" : "normal"),
            messages: a["messages"]?.toString() ?? "",
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
    return ApiResult(data: [], isMock: false, error: "暂无到达信息");
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
    if (key.isEmpty) {
      return ApiResult(data: MockData.getTrips(originId, destId), isMock: true);
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
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));

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
            ));
          }

          String depTime = _formatTimeStr(firstOrigin?["time"]?.toString() ?? "00:00");
          String arrTime = _formatTimeStr(lastDest?["time"]?.toString() ?? "00:00");
          int durationMin = _parseTimeDiffMin(depTime, arrTime);

          if (durationMin == 0 && t["duration"] != null) {
            final m = RegExp(r'(\d+)M').firstMatch(t["duration"].toString());
            if (m != null) durationMin = int.parse(m.group(1)!);
          }

          trips.add(TripProposal(
            idx: (idx++).toString(),
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
    return ApiResult(data: [], isMock: false, error: "未找到推荐路线");
  }
}

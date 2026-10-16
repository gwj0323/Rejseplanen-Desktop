import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station.dart';
import '../models/trip.dart';
import '../widgets/transit_badge.dart';
import '../i18n/translations.dart';

/// Represents a recorded route search or trip selection event for on-device ML
class CommuteEvent {
  final Station origin;
  final Station dest;
  final int timestampMs;
  final double hourOfDay; // 0.0 .. 24.0
  final int weekday; // 1 (Mon) .. 7 (Sun)
  final double weight; // 1.0 = search, 2.5 = selected/reminded/tracked

  CommuteEvent({
    required this.origin,
    required this.dest,
    required this.timestampMs,
    required this.hourOfDay,
    required this.weekday,
    this.weight = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'dest': dest.toJson(),
        'timestampMs': timestampMs,
        'hourOfDay': hourOfDay,
        'weekday': weekday,
        'weight': weight,
      };

  factory CommuteEvent.fromJson(Map<String, dynamic> json) {
    return CommuteEvent(
      origin: Station.fromJson(Map<String, dynamic>.from(json['origin'] ?? {})),
      dest: Station.fromJson(Map<String, dynamic>.from(json['dest'] ?? {})),
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
      hourOfDay: (json['hourOfDay'] as num?)?.toDouble() ?? 8.0,
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Represents a recorded station board view for Smart Station Board prediction
class BoardViewEvent {
  final Station station;
  final int timestampMs;
  final double hourOfDay;
  final int weekday;

  BoardViewEvent({
    required this.station,
    required this.timestampMs,
    required this.hourOfDay,
    required this.weekday,
  });

  Map<String, dynamic> toJson() => {
        'station': station.toJson(),
        'timestampMs': timestampMs,
        'hourOfDay': hourOfDay,
        'weekday': weekday,
      };

  factory BoardViewEvent.fromJson(Map<String, dynamic> json) {
    return BoardViewEvent(
      station: Station.fromJson(Map<String, dynamic>.from(json['station'] ?? {})),
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
      hourOfDay: (json['hourOfDay'] as num?)?.toDouble() ?? 8.0,
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Predicted route with confidence and contextual explanation key
class RoutePrediction {
  final Station origin;
  final Station dest;
  final double score;
  final double confidence; // 0.0 .. 1.0
  final String reasonKey;
  final Map<String, String> reasonParams;

  RoutePrediction({
    required this.origin,
    required this.dest,
    required this.score,
    required this.confidence,
    required this.reasonKey,
    this.reasonParams = const {},
  });
}

/// Predicted station for Smart Board switching
class StationPrediction {
  final Station station;
  final double confidence;
  final String reasonKey;

  StationPrediction({
    required this.station,
    required this.confidence,
    required this.reasonKey,
  });
}

enum TransferRiskLevel {
  none,
  low,
  medium,
  high,
}

class LegTransferRisk {
  final int fromLegIndex;
  final int toLegIndex;
  final String stationName;
  final int scheduledBufferMin;
  final int effectiveBufferMin;
  final int incomingDelayMin;
  final int walkMin;
  final bool samePlatform;
  final TransferRiskLevel level;

  LegTransferRisk({
    required this.fromLegIndex,
    required this.toLegIndex,
    required this.stationName,
    required this.scheduledBufferMin,
    required this.effectiveBufferMin,
    required this.incomingDelayMin,
    required this.walkMin,
    required this.samePlatform,
    required this.level,
  });
}

class TransferRiskSummary {
  final TransferRiskLevel overallLevel;
  final int minEffectiveBufferMin;
  final int maxIncomingDelayMin;
  final List<LegTransferRisk> transfers;

  TransferRiskSummary({
    required this.overallLevel,
    required this.minEffectiveBufferMin,
    required this.maxIncomingDelayMin,
    required this.transfers,
  });
}

class ScoredTripProposal {
  final TripProposal trip;
  final double score;
  final bool isSmartPick;
  final String? reasonKey;
  final TransferRiskSummary transferRisk;

  ScoredTripProposal({
    required this.trip,
    required this.score,
    required this.isSmartPick,
    this.reasonKey,
    required this.transferRisk,
  });
}

class LegSegmentShare {
  final TripLeg leg;
  final int durationMin;
  final double ratio;
  final Color color;
  final Color textColor;
  final String label;
  final bool isWalk;

  LegSegmentShare({
    required this.leg,
    required this.durationMin,
    required this.ratio,
    required this.color,
    required this.textColor,
    required this.label,
    required this.isWalk,
  });
}

/// On-device Machine Learning & Commute Intelligence Engine
class SmartTransitService {
  static const String _keyCommuteEvents = 'spor_ml_commute_events_v1';
  static const String _keyBoardEvents = 'spor_ml_board_events_v1';
  static const String _keyPreferenceWeights = 'spor_ml_pref_weights_v1';

  List<CommuteEvent> _commuteEvents = [];
  List<BoardViewEvent> _boardEvents = [];

  /// Online Learning-to-Rank weight vector:
  /// [0] normDuration   (prior: -1.25)
  /// [1] transfers      (prior: -0.80)
  /// [2] walkRatio      (prior: -0.45)
  /// [3] metroRatio     (prior: +0.25)
  /// [4] stogRatio      (prior: +0.20)
  /// [5] trainRatio     (prior: +0.15)
  /// [6] busRatio       (prior: -0.10)
  /// [7] riskPenalty    (prior: -0.95)
  List<double> _weights = [
    -1.25,
    -0.80,
    -0.45,
    0.25,
    0.20,
    0.15,
    -0.10,
    -0.95,
  ];

  int _learnedSamplesCount = 0;
  int get learnedSamplesCount => _learnedSamplesCount;
  int get commuteHistoryCount => _commuteEvents.length;

  List<double> get weights => List.unmodifiable(_weights);

  Future<void> loadFromPrefs(SharedPreferences prefs) async {
    try {
      final commuteStr = prefs.getString(_keyCommuteEvents);
      if (commuteStr != null && commuteStr.isNotEmpty) {
        final list = jsonDecode(commuteStr) as List;
        _commuteEvents = list
            .map((e) => CommuteEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      final boardStr = prefs.getString(_keyBoardEvents);
      if (boardStr != null && boardStr.isNotEmpty) {
        final list = jsonDecode(boardStr) as List;
        _boardEvents = list
            .map((e) => BoardViewEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      final weightsStr = prefs.getString(_keyPreferenceWeights);
      if (weightsStr != null && weightsStr.isNotEmpty) {
        final map = jsonDecode(weightsStr) as Map<String, dynamic>;
        if (map['weights'] is List) {
          final loaded = (map['weights'] as List)
              .map((v) => (v as num).toDouble())
              .toList();
          if (loaded.length == 8) {
            _weights = loaded;
          }
        }
        _learnedSamplesCount = (map['samples'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('[SmartTransitService] Error loading ML state: $e');
    }
  }

  Future<void> saveToPrefs(SharedPreferences prefs) async {
    try {
      await prefs.setString(
        _keyCommuteEvents,
        jsonEncode(_commuteEvents.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _keyBoardEvents,
        jsonEncode(_boardEvents.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _keyPreferenceWeights,
        jsonEncode({
          'weights': _weights,
          'samples': _learnedSamplesCount,
        }),
      );
    } catch (e) {
      debugPrint('[SmartTransitService] Error saving ML state: $e');
    }
  }

  /// Record a route search or strong positive action (reminder/live tracker/detail selection)
  void recordCommuteAction(
    Station origin,
    Station dest, {
    double weight = 1.0,
    DateTime? timestamp,
  }) {
    if (origin.name.trim().isEmpty || dest.name.trim().isEmpty) return;
    if (origin.name.trim().toLowerCase() == dest.name.trim().toLowerCase()) return;

    final now = timestamp ?? DateTime.now();
    final hour = now.hour + now.minute / 60.0;
    _commuteEvents.insert(
      0,
      CommuteEvent(
        origin: origin,
        dest: dest,
        timestampMs: now.millisecondsSinceEpoch,
        hourOfDay: hour,
        weekday: now.weekday,
        weight: weight,
      ),
    );
    if (_commuteEvents.length > 250) {
      _commuteEvents = _commuteEvents.sublist(0, 250);
    }
  }

  /// Record viewing a station departure/arrival board
  void recordBoardStationView(Station station, {DateTime? timestamp}) {
    if (station.name.trim().isEmpty) return;
    final now = timestamp ?? DateTime.now();
    final hour = now.hour + now.minute / 60.0;
    _boardEvents.insert(
      0,
      BoardViewEvent(
        station: station,
        timestampMs: now.millisecondsSinceEpoch,
        hourOfDay: hour,
        weekday: now.weekday,
      ),
    );
    if (_boardEvents.length > 200) {
      _boardEvents = _boardEvents.sublist(0, 200);
    }
  }

  /// Online Pairwise Learning-to-Rank update when user picks a specific trip proposal
  void learnFromTripSelection(
    TripProposal chosen,
    List<TripProposal> candidates,
  ) {
    if (candidates.length <= 1) return;

    int minDur = candidates.first.durationMin;
    int maxDur = candidates.first.durationMin;
    for (final c in candidates) {
      if (c.durationMin < minDur) minDur = c.durationMin;
      if (c.durationMin > maxDur) maxDur = c.durationMin;
    }

    final chosenFeat = _extractFeatures(chosen, minDur, maxDur);
    final List<double> avgOtherFeat = List.filled(8, 0.0);
    int otherCount = 0;

    for (final c in candidates) {
      if (c.idx == chosen.idx) continue;
      final f = _extractFeatures(c, minDur, maxDur);
      for (int i = 0; i < 8; i++) {
        avgOtherFeat[i] += f[i];
      }
      otherCount++;
    }
    if (otherCount == 0) return;
    for (int i = 0; i < 8; i++) {
      avgOtherFeat[i] /= otherCount;
    }

    // Online perceptron / gradient step with gentle L2 anchor to priors
    const double lr = 0.08;
    const List<double> priors = [-1.25, -0.80, -0.45, 0.25, 0.20, 0.15, -0.10, -0.95];
    const List<double> minBounds = [-3.0, -2.5, -2.0, -1.0, -1.0, -1.0, -1.2, -2.5];
    const List<double> maxBounds = [-0.2, -0.1, 0.2, 1.5, 1.5, 1.5, 1.2, -0.1];

    for (int i = 0; i < 8; i++) {
      final delta = chosenFeat[i] - avgOtherFeat[i];
      final reg = 0.02 * (priors[i] - _weights[i]);
      _weights[i] = (_weights[i] + lr * delta + reg).clamp(minBounds[i], maxBounds[i]);
    }
    _learnedSamplesCount++;
  }

  /// Predict top likely routes right now using Spatio-Temporal Circular Kernel + Return-Trip Inference
  List<RoutePrediction> predictRoutes({
    required List<Map<String, Station>> favoriteTrips,
    DateTime? nowOverride,
    double? currentLat,
    double? currentLon,
    int limit = 4,
  }) {
    final now = nowOverride ?? DateTime.now();
    final currentHour = now.hour + now.minute / 60.0;
    final currentWeekday = now.weekday;
    final isWeekend = currentWeekday >= 6;

    final Map<String, _RouteCandidateAccumulator> map = {};

    String routeKey(Station a, Station b) =>
        '${a.name.trim().toLowerCase()}__${b.name.trim().toLowerCase()}';

    // 1. Accumulate historical commute events with Spatio-Temporal Gaussian Kernel
    for (final ev in _commuteEvents) {
      final key = routeKey(ev.origin, ev.dest);
      final acc = map.putIfAbsent(
        key,
        () => _RouteCandidateAccumulator(origin: ev.origin, dest: ev.dest),
      );

      // Circular hour difference (0..12)
      final rawDiff = (currentHour - ev.hourOfDay).abs();
      final circularDiff = rawDiff > 12.0 ? 24.0 - rawDiff : rawDiff;

      // Gaussian time kernel (sigma = 1.8 hours)
      final timeKernel = 0.18 + 0.82 * math.exp(-(circularDiff * circularDiff) / (2 * 1.8 * 1.8));

      // Weekday / weekend kernel
      final evWeekend = ev.weekday >= 6;
      double dayKernel = 1.0;
      if (ev.weekday == currentWeekday) {
        dayKernel = 1.35;
      } else if (evWeekend == isWeekend) {
        dayKernel = 1.05;
      } else {
        dayKernel = 0.45;
      }

      // Exponential recency decay (half-life ~ 18 days)
      final daysAgo = math.max(0.0, (now.millisecondsSinceEpoch - ev.timestampMs) / 86400000.0);
      final recencyKernel = math.exp(-0.038 * daysAgo);

      final eventScore = ev.weight * timeKernel * dayKernel * recencyKernel;
      acc.totalScore += eventScore;
      acc.count++;
      if (circularDiff <= 2.0) {
        acc.timeMatchedCount++;
        acc.bestMatchedHour = ev.hourOfDay;
      }

      // Return-trip synthesis: if user traveled A -> B earlier (e.g. morning),
      // synthesize a return candidate B -> A for opposite time of day or when near B
      final revKey = routeKey(ev.dest, ev.origin);
      final revAcc = map.putIfAbsent(
        revKey,
        () => _RouteCandidateAccumulator(
          origin: ev.dest,
          dest: ev.origin,
          isSynthesizedReturn: true,
        ),
      );
      // If current time is 6..11 hours after the recorded outbound trip, boost return trip
      final hoursSinceOutbound = (currentHour - ev.hourOfDay + 24.0) % 24.0;
      if (hoursSinceOutbound >= 5.0 && hoursSinceOutbound <= 12.0) {
        revAcc.totalScore += ev.weight * 0.55 * dayKernel * recencyKernel;
        revAcc.returnMatched = true;
      }
    }

    // 2. Fold in Favorite Trips as Bayesian priors
    for (final fav in favoriteTrips) {
      final orig = fav['origin'];
      final dest = fav['dest'];
      if (orig == null || dest == null) continue;
      final key = routeKey(orig, dest);
      final acc = map.putIfAbsent(
        key,
        () => _RouteCandidateAccumulator(origin: orig, dest: dest, isFavorite: true),
      );
      acc.isFavorite = true;
      acc.totalScore += 0.85;

      // Also add reverse of favorite trip as a gentle return candidate
      final revKey = routeKey(dest, orig);
      final revAcc = map.putIfAbsent(
        revKey,
        () => _RouteCandidateAccumulator(
          origin: dest,
          dest: orig,
          isSynthesizedReturn: true,
        ),
      );
      revAcc.totalScore += 0.35;
    }

    // 3. Apply Spatial GPS Kernel if current coordinates are known
    if (currentLat != null && currentLon != null) {
      for (final acc in map.values) {
        if (acc.origin.lat != null && acc.origin.lon != null) {
          final distKm = _haversineKm(
            currentLat,
            currentLon,
            acc.origin.lat!,
            acc.origin.lon!,
          );
          if (distKm <= 3.0) {
            final spatialBoost = 1.0 + 1.6 * math.exp(-(distKm * distKm) / 1.5);
            acc.totalScore *= spatialBoost;
            acc.nearOrigin = true;
          }
        }
      }
    }

    if (map.isEmpty) return [];

    final sorted = map.values.toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final maxScore = sorted.first.totalScore;
    final List<RoutePrediction> results = [];

    for (final acc in sorted.take(limit)) {
      if (acc.totalScore <= 0.1) continue;
      // Map raw score into a calibrated 0.35 .. 0.98 confidence
      final norm = (acc.totalScore / math.max(maxScore, 1.5)).clamp(0.0, 1.0);
      final confidence = (0.38 + 0.58 * (1.0 - math.exp(-0.9 * acc.totalScore)) * norm)
          .clamp(0.35, 0.98);

      String reasonKey = 'smart_reason_fav_commute';
      Map<String, String> params = {};

      if (acc.nearOrigin && acc.returnMatched) {
        reasonKey = 'smart_reason_return_trip';
      } else if (acc.nearOrigin) {
        reasonKey = 'smart_reason_near_origin';
      } else if (acc.timeMatchedCount > 0 && acc.bestMatchedHour != null) {
        reasonKey = 'smart_reason_time_habit';
        final h = acc.bestMatchedHour!.floor();
        final m = ((acc.bestMatchedHour! - h) * 60).round();
        params = {
          'time': '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
        };
      } else if (acc.returnMatched) {
        reasonKey = 'smart_reason_return_trip';
      } else if (acc.count >= 2) {
        reasonKey = 'smart_reason_frequent';
        params = {'count': '${acc.count}'};
      }

      results.add(
        RoutePrediction(
          origin: acc.origin,
          dest: acc.dest,
          score: acc.totalScore,
          confidence: confidence,
          reasonKey: reasonKey,
          reasonParams: params,
        ),
      );
    }

    return results;
  }

  /// Predict top stations for Live Board based on current time, history, and GPS
  List<StationPrediction> predictBoardStations({
    required List<Station> favoriteStations,
    required List<Station> recentStations,
    DateTime? nowOverride,
    double? currentLat,
    double? currentLon,
    int limit = 4,
  }) {
    final now = nowOverride ?? DateTime.now();
    final currentHour = now.hour + now.minute / 60.0;
    final Map<String, _StationAccumulator> map = {};

    String stKey(Station s) => s.name.trim().toLowerCase();

    for (final ev in _boardEvents) {
      final k = stKey(ev.station);
      final acc = map.putIfAbsent(k, () => _StationAccumulator(ev.station));
      final rawDiff = (currentHour - ev.hourOfDay).abs();
      final circularDiff = rawDiff > 12.0 ? 24.0 - rawDiff : rawDiff;
      final timeKernel = 0.2 + 0.8 * math.exp(-(circularDiff * circularDiff) / (2 * 2.0 * 2.0));
      final daysAgo = math.max(0.0, (now.millisecondsSinceEpoch - ev.timestampMs) / 86400000.0);
      acc.score += timeKernel * math.exp(-0.04 * daysAgo);
      if (circularDiff <= 2.0) acc.timeMatched = true;
    }

    // Also include trip origins from commute history
    for (final ev in _commuteEvents) {
      final k = stKey(ev.origin);
      final acc = map.putIfAbsent(k, () => _StationAccumulator(ev.origin));
      final rawDiff = (currentHour - ev.hourOfDay).abs();
      final circularDiff = rawDiff > 12.0 ? 24.0 - rawDiff : rawDiff;
      final timeKernel = 0.2 + 0.8 * math.exp(-(circularDiff * circularDiff) / (2 * 2.0 * 2.0));
      acc.score += 0.7 * timeKernel;
      if (circularDiff <= 2.0) acc.timeMatched = true;
    }

    for (final s in favoriteStations) {
      final k = stKey(s);
      final acc = map.putIfAbsent(k, () => _StationAccumulator(s));
      acc.score += 0.65;
    }

    for (int i = 0; i < recentStations.length && i < 5; i++) {
      final s = recentStations[i];
      final k = stKey(s);
      final acc = map.putIfAbsent(k, () => _StationAccumulator(s));
      acc.score += 0.35 * (1.0 - i * 0.15);
    }

    if (currentLat != null && currentLon != null) {
      for (final acc in map.values) {
        if (acc.station.lat != null && acc.station.lon != null) {
          final d = _haversineKm(currentLat, currentLon, acc.station.lat!, acc.station.lon!);
          if (d <= 2.5) {
            acc.score *= (1.0 + 1.5 * math.exp(-(d * d) / 1.2));
            acc.nearMe = true;
          }
        }
      }
    }

    final sorted = map.values.toList()..sort((a, b) => b.score.compareTo(a.score));
    return sorted.take(limit).map((acc) {
      String reason = 'smart_reason_fav_commute';
      if (acc.nearMe) {
        reason = 'smart_reason_near_origin';
      } else if (acc.timeMatched) {
        reason = 'smart_reason_time_habit';
      }
      return StationPrediction(
        station: acc.station,
        confidence: (0.45 + 0.5 * (1.0 - math.exp(-acc.score))).clamp(0.4, 0.96),
        reasonKey: reason,
      );
    }).toList();
  }

  /// Score a batch of trip proposals and identify the #1 Smart Pick + Transfer Risk
  List<ScoredTripProposal> scoreProposals(List<TripProposal> proposals) {
    if (proposals.isEmpty) return [];

    int minDur = proposals.first.durationMin;
    int maxDur = proposals.first.durationMin;
    for (final p in proposals) {
      if (p.durationMin < minDur) minDur = p.durationMin;
      if (p.durationMin > maxDur) maxDur = p.durationMin;
    }

    final List<ScoredTripProposal> temp = [];
    int bestIndex = 0;
    double bestScore = -999999.0;

    for (int i = 0; i < proposals.length; i++) {
      final p = proposals[i];
      final risk = analyzeTransferRisk(p);
      final feat = _extractFeatures(p, minDur, maxDur, precomputedRisk: risk);
      double s = 0.0;
      for (int j = 0; j < 8; j++) {
        s += _weights[j] * feat[j];
      }
      if (s > bestScore) {
        bestScore = s;
        bestIndex = i;
      }
      temp.add(
        ScoredTripProposal(
          trip: p,
          score: s,
          isSmartPick: false,
          transferRisk: risk,
        ),
      );
    }

    // Determine the human-readable reason for the top pick
    final winner = proposals[bestIndex];
    final winnerFeat = _extractFeatures(
      winner,
      minDur,
      maxDur,
      precomputedRisk: temp[bestIndex].transferRisk,
    );

    String reasonKey = 'smart_pick_balanced';
    if (winner.changes == 0 && proposals.any((p) => p.changes > 0)) {
      reasonKey = 'smart_pick_direct';
    } else if (winner.durationMin == minDur && proposals.length > 1) {
      reasonKey = 'smart_pick_fastest';
    } else if (winnerFeat[3] > 0.5 && _weights[3] > 0.3) {
      reasonKey = 'smart_pick_metro';
    } else if (winnerFeat[4] > 0.5 && _weights[4] > 0.25) {
      reasonKey = 'smart_pick_stog';
    } else if (winnerFeat[5] > 0.5 && _weights[5] > 0.2) {
      reasonKey = 'smart_pick_train';
    } else if (temp[bestIndex].transferRisk.overallLevel == TransferRiskLevel.low) {
      reasonKey = 'smart_pick_safe_transfer';
    }

    final List<ScoredTripProposal> result = [];
    for (int i = 0; i < temp.length; i++) {
      result.add(
        ScoredTripProposal(
          trip: temp[i].trip,
          score: temp[i].score,
          isSmartPick: i == bestIndex,
          reasonKey: i == bestIndex ? reasonKey : null,
          transferRisk: temp[i].transferRisk,
        ),
      );
    }
    return result;
  }

  /// Analyze transfer buffers, delays, and platform changes across all legs of a trip
  static TransferRiskSummary analyzeTransferRisk(TripProposal trip) {
    final transitIndices = <int>[];
    for (int i = 0; i < trip.legs.length; i++) {
      if (!trip.legs[i].isWalk) {
        transitIndices.add(i);
      }
    }

    if (transitIndices.length <= 1) {
      return TransferRiskSummary(
        overallLevel: TransferRiskLevel.none,
        minEffectiveBufferMin: 99,
        maxIncomingDelayMin: 0,
        transfers: const [],
      );
    }

    final List<LegTransferRisk> transfers = [];
    int minBuffer = 999;
    int maxDelay = 0;
    TransferRiskLevel worstLevel = TransferRiskLevel.low;

    for (int k = 0; k < transitIndices.length - 1; k++) {
      final fromIdx = transitIndices[k];
      final toIdx = transitIndices[k + 1];
      final fromLeg = trip.legs[fromIdx];
      final toLeg = trip.legs[toIdx];

      int walkMin = 0;
      for (int w = fromIdx + 1; w < toIdx; w++) {
        walkMin += estimateLegDurationMin(trip.legs[w]);
      }

      final schedArr = _parseMinutesOfDay(fromLeg.destination.time);
      final rtArr = _parseMinutesOfDay(
        fromLeg.destination.rtTime.isNotEmpty
            ? fromLeg.destination.rtTime
            : fromLeg.destination.time,
      );
      final schedDep = _parseMinutesOfDay(toLeg.origin.time);
      final rtDep = _parseMinutesOfDay(
        toLeg.origin.rtTime.isNotEmpty ? toLeg.origin.rtTime : toLeg.origin.time,
      );

      int incomingDelay = 0;
      if (schedArr != null && rtArr != null) {
        incomingDelay = _diffMinutes(schedArr, rtArr);
        if (incomingDelay < 0) incomingDelay = 0;
      }

      int schedBuffer = 5;
      if (schedArr != null && schedDep != null) {
        schedBuffer = math.max(0, _diffMinutes(schedArr, schedDep));
      }

      int effectiveBuffer = schedBuffer;
      if (rtArr != null && rtDep != null) {
        effectiveBuffer = math.max(0, _diffMinutes(rtArr, rtDep) - walkMin);
      } else {
        effectiveBuffer = math.max(0, schedBuffer - incomingDelay - walkMin);
      }

      final samePlatform = fromLeg.destination.track.isNotEmpty &&
          fromLeg.destination.track != '-' &&
          fromLeg.destination.track == toLeg.origin.track;

      TransferRiskLevel level = TransferRiskLevel.low;
      if (effectiveBuffer < 2 || (incomingDelay >= 2 && effectiveBuffer <= 3 && !samePlatform)) {
        level = TransferRiskLevel.high;
      } else if (effectiveBuffer <= 4 || (walkMin > 0 && effectiveBuffer <= 5)) {
        level = TransferRiskLevel.medium;
      }

      if (effectiveBuffer < minBuffer) minBuffer = effectiveBuffer;
      if (incomingDelay > maxDelay) maxDelay = incomingDelay;
      if (level.index > worstLevel.index) worstLevel = level;

      transfers.add(
        LegTransferRisk(
          fromLegIndex: fromIdx,
          toLegIndex: toIdx,
          stationName: fromLeg.destination.name,
          scheduledBufferMin: schedBuffer,
          effectiveBufferMin: effectiveBuffer,
          incomingDelayMin: incomingDelay,
          walkMin: walkMin,
          samePlatform: samePlatform,
          level: level,
        ),
      );
    }

    return TransferRiskSummary(
      overallLevel: worstLevel,
      minEffectiveBufferMin: minBuffer == 999 ? 0 : minBuffer,
      maxIncomingDelayMin: maxDelay,
      transfers: transfers,
    );
  }

  /// Compute visual leg proportion segments for TripCard's proportion bar
  static List<LegSegmentShare> computeLegSegments(TripProposal trip) {
    if (trip.legs.isEmpty) return [];

    final List<int> durations = [];
    int sumDurations = 0;
    for (final leg in trip.legs) {
      final d = math.max(2, estimateLegDurationMin(leg));
      durations.add(d);
      sumDurations += d;
    }
    if (sumDurations <= 0) sumDurations = 1;

    final List<LegSegmentShare> segments = [];
    for (int i = 0; i < trip.legs.length; i++) {
      final leg = trip.legs[i];
      final d = durations[i];
      final ratio = d / sumDurations;

      if (leg.isWalk) {
        segments.add(
          LegSegmentShare(
            leg: leg,
            durationMin: d,
            ratio: ratio,
            color: const Color(0xFF94A3B8),
            textColor: Colors.white,
            label: '${d}m',
            isWalk: true,
          ),
        );
      } else {
        final info = TransitBadgeHelper.parse(leg.name, leg.type);
        segments.add(
          LegSegmentShare(
            leg: leg,
            durationMin: d,
            ratio: ratio,
            color: info.bg,
            textColor: info.fg,
            label: '${info.display} (${d}m)',
            isWalk: false,
          ),
        );
      }
    }
    return segments;
  }

  /// Format a trip proposal into a clean shareable text summary
  static String formatTripShareText({
    required BuildContext context,
    required TripProposal trip,
    required Station origin,
    required Station destination,
  }) {
    final sb = StringBuffer();
    sb.writeln(
      '🚆 ${origin.name} ➔ ${destination.name} (${trip.depTime} - ${trip.arrTime}, ${trip.durationMin} min)',
    );
    for (final leg in trip.legs) {
      if (leg.isWalk) {
        final dur = estimateLegDurationMin(leg);
        sb.writeln(
          '  🚶 ${I18n.t(context, "trip_walk")}: ${leg.origin.name} ➔ ${leg.destination.name} (~${dur}m)',
        );
      } else {
        final origTrack = (leg.origin.track.isNotEmpty && leg.origin.track != '-')
            ? ' (${I18n.t(context, "board_col_track")} ${leg.origin.track})'
            : '';
        final destTrack = (leg.destination.track.isNotEmpty && leg.destination.track != '-')
            ? ' (${I18n.t(context, "board_col_track")} ${leg.destination.track})'
            : '';
        sb.writeln(
          '  • ${leg.origin.time} ${leg.origin.name}$origTrack ➔ [${leg.name}] ➔ ${leg.destination.time} ${leg.destination.name}$destTrack',
        );
      }
    }
    return sb.toString().trimRight();
  }

  static int estimateLegDurationMin(TripLeg leg) {
    final start = _parseMinutesOfDay(
      leg.origin.rtTime.isNotEmpty ? leg.origin.rtTime : leg.origin.time,
    );
    final end = _parseMinutesOfDay(
      leg.destination.rtTime.isNotEmpty ? leg.destination.rtTime : leg.destination.time,
    );
    if (start != null && end != null) {
      final diff = _diffMinutes(start, end);
      if (diff > 0 && diff < 720) return diff;
    }
    return leg.isWalk ? 4 : 10;
  }

  static int? _parseMinutesOfDay(String timeStr) {
    final s = timeStr.trim();
    if (s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static int _diffMinutes(int startMin, int endMin) {
    int diff = endMin - startMin;
    if (diff < -180) {
      // Crossed midnight
      diff += 1440;
    }
    return diff;
  }

  List<double> _extractFeatures(
    TripProposal p,
    int minDur,
    int maxDur, {
    TransferRiskSummary? precomputedRisk,
  }) {
    final normDur = (p.durationMin - minDur) / math.max(1, maxDur - minDur);
    final transfers = p.changes.toDouble();

    int totalMin = 0;
    int walkMin = 0;
    int metroMin = 0;
    int stogMin = 0;
    int trainMin = 0;
    int busMin = 0;

    for (final leg in p.legs) {
      final d = math.max(1, estimateLegDurationMin(leg));
      totalMin += d;
      if (leg.isWalk) {
        walkMin += d;
        continue;
      }
      final info = TransitBadgeHelper.parse(leg.name, leg.type);
      final cat = info.category.toUpperCase();
      if (cat == 'METRO') {
        metroMin += d;
      } else if (cat == 'S-TOG') {
        stogMin += d;
      } else if (cat == 'BUS') {
        busMin += d;
      } else {
        trainMin += d;
      }
    }
    if (totalMin <= 0) totalMin = 1;

    final risk = precomputedRisk ?? analyzeTransferRisk(p);
    double riskPenalty = 0.0;
    if (risk.overallLevel == TransferRiskLevel.high) {
      riskPenalty = 1.0;
    } else if (risk.overallLevel == TransferRiskLevel.medium) {
      riskPenalty = 0.45;
    }

    return [
      normDur,
      transfers,
      walkMin / totalMin,
      metroMin / totalMin,
      stogMin / totalMin,
      trainMin / totalMin,
      busMin / totalMin,
      riskPenalty,
    ];
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}

class _RouteCandidateAccumulator {
  final Station origin;
  final Station dest;
  double totalScore = 0.0;
  int count = 0;
  int timeMatchedCount = 0;
  double? bestMatchedHour;
  bool isFavorite;
  bool isSynthesizedReturn;
  bool returnMatched = false;
  bool nearOrigin = false;

  _RouteCandidateAccumulator({
    required this.origin,
    required this.dest,
    this.isFavorite = false,
    this.isSynthesizedReturn = false,
  });
}

class _StationAccumulator {
  final Station station;
  double score = 0.0;
  bool timeMatched = false;
  bool nearMe = false;

  _StationAccumulator(this.station);
}

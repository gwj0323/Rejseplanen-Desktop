class TripStop {
  final String name;
  final String time;
  final String date;
  final String track;
  final String rtTime;

  TripStop({
    required this.name,
    required this.time,
    required this.date,
    required this.track,
    required this.rtTime,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      name: json['name']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      track: json['track']?.toString() ?? json['rtTrack']?.toString() ?? '-',
      rtTime: json['rtTime']?.toString() ?? json['time']?.toString() ?? '',
    );
  }
}

class TripLeg {
  final String type;
  final String name;
  final String direction;
  final TripStop origin;
  final TripStop destination;
  final String notes;
  final String? journeyDetailRef;
  final List<TripStop>? stops;

  TripLeg({
    required this.type,
    required this.name,
    required this.direction,
    required this.origin,
    required this.destination,
    required this.notes,
    this.journeyDetailRef,
    this.stops,
  });

  factory TripLeg.fromJson(Map<String, dynamic> json) {
    String? jRef;
    if (json['journeyDetailRef'] != null) {
      jRef = json['journeyDetailRef']?.toString();
    } else if (json['JourneyDetailRef'] != null) {
      if (json['JourneyDetailRef'] is Map) {
        jRef = json['JourneyDetailRef']['ref']?.toString();
      } else {
        jRef = json['JourneyDetailRef']?.toString();
      }
    }

    List<TripStop>? parsedStops;
    if (json['stops'] != null && json['stops'] is List) {
      parsedStops = (json['stops'] as List)
          .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return TripLeg(
      type: json['type']?.toString() ?? 'TOG',
      name: json['name']?.toString() ?? 'Leg',
      direction: json['direction']?.toString() ?? '',
      origin: TripStop.fromJson(json['origin'] is Map<String, dynamic> ? json['origin'] : {}),
      destination: TripStop.fromJson(json['destination'] is Map<String, dynamic> ? json['destination'] : {}),
      notes: json['notes']?.toString() ?? '',
      journeyDetailRef: jRef,
      stops: parsedStops,
    );
  }

  bool get isWalk => type.toUpperCase() == 'WALK';
}

class TripProposal {
  final String idx;
  final int durationMin;
  final String depTime;
  final String arrTime;
  final int changes;
  final List<TripLeg> legs;

  TripProposal({
    required this.idx,
    required this.durationMin,
    required this.depTime,
    required this.arrTime,
    required this.changes,
    required this.legs,
  });

  factory TripProposal.fromJson(Map<String, dynamic> json) {
    List<TripLeg> parsedLegs = [];
    if (json['legs'] != null && json['legs'] is List) {
      parsedLegs = (json['legs'] as List)
          .map((item) => TripLeg.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return TripProposal(
      idx: json['idx']?.toString() ?? '1',
      durationMin: (json['duration_min'] is num) ? (json['duration_min'] as num).toInt() : 0,
      depTime: json['dep_time']?.toString() ?? '',
      arrTime: json['arr_time']?.toString() ?? '',
      changes: (json['changes'] is num) ? (json['changes'] as num).toInt() : 0,
      legs: parsedLegs,
    );
  }
}

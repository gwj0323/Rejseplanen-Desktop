class Departure {
  final String name;
  final String type;
  final String stop;
  final String direction;
  final String time;
  final String date;
  final String rtTime;
  final String rtDate;
  final String track;
  final int delay;
  final String status; // 'normal', 'delayed', 'minor_delay', 'cancelled'
  final String messages;

  Departure({
    required this.name,
    required this.type,
    required this.stop,
    required this.direction,
    required this.time,
    required this.date,
    required this.rtTime,
    required this.rtDate,
    required this.track,
    required this.delay,
    required this.status,
    required this.messages,
  });

  factory Departure.fromJson(Map<String, dynamic> json) {
    return Departure(
      name: json['name']?.toString() ?? 'Transit',
      type: json['type']?.toString() ?? 'TOG',
      stop: json['stop']?.toString() ?? '',
      direction: json['direction']?.toString() ?? json['stop']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      rtTime: json['rtTime']?.toString() ?? json['time']?.toString() ?? '',
      rtDate: json['rtDate']?.toString() ?? json['date']?.toString() ?? '',
      track: json['track']?.toString() ?? json['rtTrack']?.toString() ?? '-',
      delay: (json['delay'] is num) ? (json['delay'] as num).toInt() : 0,
      status: json['status']?.toString() ?? 'normal',
      messages: json['messages']?.toString() ?? '',
    );
  }

  bool get isDelayed => delay >= 5;
  bool get isCancelled => status == 'cancelled';
  bool get isOnTime => delay <= 0 && !isCancelled;
}

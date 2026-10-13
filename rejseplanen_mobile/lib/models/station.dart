class Station {
  final String id;
  final String extId;
  final String name;
  final double lat;
  final double lon;
  final List<String> types;
  final String? desc;
  final String? distance;

  Station({
    required this.id,
    this.extId = '',
    required this.name,
    this.lat = 0.0,
    this.lon = 0.0,
    this.types = const ['ST'],
    this.desc,
    this.distance,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    List<String> typesList = ['ST'];
    if (json['types'] != null) {
      if (json['types'] is List) {
        typesList = (json['types'] as List).map((e) => e.toString()).toList();
      }
    }
    return Station(
      id: json['id']?.toString() ?? '',
      extId: json['extId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : 0.0,
      lon: (json['lon'] is num) ? (json['lon'] as num).toDouble() : 0.0,
      types: typesList,
      desc: json['desc']?.toString(),
      distance: json['distance']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'extId': extId,
      'name': name,
      'lat': lat,
      'lon': lon,
      'types': types,
      if (desc != null) 'desc': desc,
      if (distance != null) 'distance': distance,
    };
  }

  @override
  String toString() => name;
}

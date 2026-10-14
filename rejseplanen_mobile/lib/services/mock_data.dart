import 'package:intl/intl.dart';
import '../models/station.dart';
import '../models/departure.dart';
import '../models/trip.dart';

class MockData {
  static final List<Station> stations = [
    Station(
      id: "8600626",
      name: "København H",
      lat: 55.673063,
      lon: 12.565562,
      types: ["IC", "REG", "S", "MET", "BUS"],
      desc: "Copenhagen Central Station",
    ),
    Station(
      id: "8600646",
      name: "Nørreport St.",
      lat: 55.683455,
      lon: 12.571801,
      types: ["S", "MET", "REG", "BUS"],
      desc: "Denmark's busiest transport hub",
    ),
    Station(
      id: "8603308",
      name: "Kongens Nytorv St. (Metro)",
      lat: 55.679185,
      lon: 12.585231,
      types: ["MET", "BUS"],
      desc: "Metro hub: M1, M2, M3, M4",
    ),
    Station(
      id: "8600858",
      name: "CPH Lufthavn",
      lat: 55.629439,
      lon: 12.649162,
      types: ["MET", "IC", "REG", "BUS"],
      desc: "Copenhagen Airport Terminal 3",
    ),
    Station(
      id: "8600650",
      name: "Østerport St.",
      lat: 55.692498,
      lon: 12.587784,
      types: ["S", "MET", "REG", "IC", "BUS"],
      desc: "Major interchange in Østerbro",
    ),
    Station(
      id: "8600053",
      name: "Aarhus H",
      lat: 56.150444,
      lon: 10.204761,
      types: ["IC", "REG", "BUS"],
      desc: "Aarhus Central Station",
    ),
    Station(
      id: "8600512",
      name: "Odense St.",
      lat: 55.401778,
      lon: 10.386739,
      types: ["IC", "REG", "BUS"],
      desc: "Funen transport hub",
    ),
    Station(
      id: "8600020",
      name: "Aalborg St.",
      lat: 57.043037,
      lon: 9.917044,
      types: ["IC", "REG", "BUS"],
      desc: "North Jutland main station",
    ),
    Station(
      id: "8600617",
      name: "Roskilde St.",
      lat: 55.639093,
      lon: 12.088550,
      types: ["IC", "REG", "BUS"],
      desc: "Historic cathedral city station",
    ),
    Station(
      id: "8600669",
      name: "Helsingør St.",
      lat: 56.033621,
      lon: 12.614167,
      types: ["REG", "BUS", "FER"],
      desc: "Hamlet's Elsinore & ferry terminal",
    ),
  ];

  static List<Station> searchStations(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return stations.take(6).toList();
    }
    return stations.where((s) {
      return s.name.toLowerCase().contains(q) ||
          (s.desc != null && s.desc!.toLowerCase().contains(q)) ||
          s.id.contains(q);
    }).toList();
  }

  static Station? getStationById(String id) {
    try {
      return stations.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<Departure> getDepartures(String stationId) {
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('yyyy-MM-dd');

    String t(int addMinutes) {
      return timeFormat.format(now.add(Duration(minutes: addMinutes)));
    }

    final dStr = dateFormat.format(now);

    return [
      Departure(
        name: "A",
        type: "S-TOG",
        stop: "Hundige",
        direction: "Hundige",
        time: t(2),
        date: dStr,
        rtTime: t(2),
        rtDate: dStr,
        track: "11",
        delay: 0,
        status: "normal",
        messages: "",
      ),
      Departure(
        name: "B",
        type: "S-TOG",
        stop: "Farum",
        direction: "Farum",
        time: t(5),
        date: dStr,
        rtTime: t(7),
        rtDate: dStr,
        track: "9",
        delay: 2,
        status: "minor_delay",
        messages: "Signalfejl ved Nørreport",
      ),
      Departure(
        name: "IC 123",
        type: "IC",
        stop: "Aalborg St.",
        direction: "Aalborg St.",
        time: t(10),
        date: dStr,
        rtTime: t(10),
        rtDate: dStr,
        track: "5",
        delay: 0,
        status: "normal",
        messages: "",
      ),
      Departure(
        name: "M2",
        type: "METRO",
        stop: "CPH Lufthavn",
        direction: "CPH Lufthavn",
        time: t(13),
        date: dStr,
        rtTime: t(13),
        rtDate: dStr,
        track: "M2",
        delay: 0,
        status: "normal",
        messages: "",
      ),
      Departure(
        name: "C",
        type: "S-TOG",
        stop: "Frederikssund",
        direction: "Frederikssund",
        time: t(18),
        date: dStr,
        rtTime: t(26),
        rtDate: dStr,
        track: "10",
        delay: 8,
        status: "delayed",
        messages: "Materielmangel",
      ),
      Departure(
        name: "5C",
        type: "BUS",
        stop: "Herlev Hospital",
        direction: "Herlev Hospital",
        time: t(21),
        date: dStr,
        rtTime: t(21),
        rtDate: dStr,
        track: "-",
        delay: 0,
        status: "normal",
        messages: "",
      ),
      Departure(
        name: "RE 1055",
        type: "RE",
        stop: "Odense St.",
        direction: "Odense St.",
        time: t(25),
        date: dStr,
        rtTime: t(25),
        rtDate: dStr,
        track: "6",
        delay: 0,
        status: "normal",
        messages: "",
      ),
    ];
  }

  static List<Departure> getArrivals(String stationId) {
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('yyyy-MM-dd');

    String t(int addMinutes) {
      return timeFormat.format(now.add(Duration(minutes: addMinutes)));
    }

    final dStr = dateFormat.format(now);

    return [
      Departure(
        name: "M1",
        type: "METRO",
        stop: "Vanløse St.",
        direction: "København H",
        time: t(1),
        date: dStr,
        rtTime: t(1),
        rtDate: dStr,
        track: "M1",
        delay: 0,
        status: "normal",
        messages: "",
      ),
      Departure(
        name: "E",
        type: "S-TOG",
        stop: "Køge",
        direction: "Holte",
        time: t(4),
        date: dStr,
        rtTime: t(4),
        rtDate: dStr,
        track: "12",
        delay: 0,
        status: "normal",
        messages: "",
      ),
      Departure(
        name: "IC 834",
        type: "IC",
        stop: "Esbjerg St.",
        direction: "København H",
        time: t(8),
        date: dStr,
        rtTime: t(14),
        rtDate: dStr,
        track: "4",
        delay: 6,
        status: "delayed",
        messages: "Forsinket fra Fyn",
      ),
      Departure(
        name: "A",
        type: "S-TOG",
        stop: "Hillerød",
        direction: "Hundige",
        time: t(12),
        date: dStr,
        rtTime: t(12),
        rtDate: dStr,
        track: "11",
        delay: 0,
        status: "normal",
        messages: "",
      ),
      Departure(
        name: "2A",
        type: "BUS",
        stop: "Tingbjerg",
        direction: "Kastrup St.",
        time: t(16),
        date: dStr,
        rtTime: t(16),
        rtDate: dStr,
        track: "-",
        delay: 0,
        status: "normal",
        messages: "",
      ),
    ];
  }

  static List<TripProposal> getTrips(String originId, String destId) {
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('yyyy-MM-dd');

    String t(int addMinutes) {
      return timeFormat.format(now.add(Duration(minutes: addMinutes)));
    }

    final dStr = dateFormat.format(now);

    return [
      TripProposal(
        idx: "1",
        durationMin: 18,
        depTime: t(5),
        arrTime: t(23),
        changes: 0,
        legs: [
          TripLeg(
            type: "S-TOG",
            name: "A",
            direction: "Hillerød",
            origin: TripStop(
              name: "København H",
              time: t(5),
              date: dStr,
              track: "9",
              rtTime: t(5),
            ),
            destination: TripStop(
              name: "Nørreport St.",
              time: t(9),
              date: dStr,
              track: "1",
              rtTime: t(9),
            ),
            notes: "",
          ),
          TripLeg(
            type: "METRO",
            name: "M2",
            direction: "CPH Lufthavn",
            origin: TripStop(
              name: "Nørreport St.",
              time: t(11),
              date: dStr,
              track: "M2",
              rtTime: t(11),
            ),
            destination: TripStop(
              name: "CPH Lufthavn",
              time: t(23),
              date: dStr,
              track: "M2",
              rtTime: t(23),
            ),
            notes: "Hurtig forbindelse til lufthavnen",
          ),
        ],
      ),
      TripProposal(
        idx: "2",
        durationMin: 22,
        depTime: t(15),
        arrTime: t(37),
        changes: 0,
        legs: [
          TripLeg(
            type: "RE",
            name: "RE 1342",
            direction: "Østerport St.",
            origin: TripStop(
              name: "København H",
              time: t(15),
              date: dStr,
              track: "5",
              rtTime: t(15),
            ),
            destination: TripStop(
              name: "Østerport St.",
              time: t(21),
              date: dStr,
              track: "2",
              rtTime: t(21),
            ),
            notes: "",
          ),
        ],
      ),
      TripProposal(
        idx: "3",
        durationMin: 26,
        depTime: t(28),
        arrTime: t(54),
        changes: 1,
        legs: [
          TripLeg(
            type: "S-TOG",
            name: "B",
            direction: "Farum",
            origin: TripStop(
              name: "København H",
              time: t(28),
              date: dStr,
              track: "10",
              rtTime: t(30),
            ),
            destination: TripStop(
              name: "Nørreport St.",
              time: t(34),
              date: dStr,
              track: "2",
              rtTime: t(36),
            ),
            notes: "2 min forsinkelse",
          ),
          TripLeg(
            type: "BUS",
            name: "5C",
            direction: "Sundbyvester Plads",
            origin: TripStop(
              name: "Nørreport St.",
              time: t(40),
              date: dStr,
              track: "-",
              rtTime: t(40),
            ),
            destination: TripStop(
              name: "Kongens Nytorv St.",
              time: t(54),
              date: dStr,
              track: "-",
              rtTime: t(54),
            ),
            notes: "",
            journeyDetailRef: "mock_5c",
          ),
        ],
      ),
    ];
  }

  /// Generate mock intermediate stop timetable for journeyDetail
  static List<TripStop> getJourneyStops({
    String? legName,
    String? originName,
    String? destName,
    String? timeStr,
    String? dateStr,
  }) {
    final now = DateTime.now();
    final dStr = dateStr ?? DateFormat('yyyy-MM-dd').format(now);
    final baseTime = (timeStr != null && timeStr.contains(':'))
        ? timeStr
        : DateFormat('HH:mm').format(now);

    int startHour = 12, startMin = 0;
    try {
      final tp = baseTime.split(':');
      startHour = int.parse(tp[0]);
      startMin = int.parse(tp[1]);
    } catch (_) {}

    String addMin(int delta) {
      int total = startHour * 60 + startMin + delta;
      int h = (total ~/ 60) % 24;
      int m = total % 60;
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    }

    final orig = originName?.trim() ?? "København H";
    final dest = destName?.trim() ?? "Nørreport St.";
    final name = (legName ?? "").toUpperCase();

    // 1. S-tog (A, B, C, E, F, H)
    if (name.contains("S-TOG") || name.contains("TOG A") || name.contains("TOG B") || name.contains("TOG C") || name.contains("TOG E") || name.contains("TOG F") || name.contains("TOG H") || (orig.contains("København") && dest.contains("Nørreport"))) {
      return [
        TripStop(name: "København H", time: addMin(0), date: dStr, track: "9", rtTime: addMin(0)),
        TripStop(name: "Vesterport St.", time: addMin(2), date: dStr, track: "1", rtTime: addMin(2)),
        TripStop(name: "Nørreport St.", time: addMin(4), date: dStr, track: "1", rtTime: addMin(4)),
        TripStop(name: "Østerport St.", time: addMin(7), date: dStr, track: "1", rtTime: addMin(7)),
        TripStop(name: "Nordhavn St.", time: addMin(9), date: dStr, track: "1", rtTime: addMin(9)),
        TripStop(name: "Svanemøllen St.", time: addMin(11), date: dStr, track: "1", rtTime: addMin(11)),
        TripStop(name: "Hellerup St.", time: addMin(14), date: dStr, track: "2", rtTime: addMin(14)),
      ];
    }

    // 2. Metro (M1, M2, M3, M4)
    if (name.contains("M1") || name.contains("M2") || name.contains("M3") || name.contains("M4") || name.contains("METRO") || dest.contains("Lufthavn")) {
      return [
        TripStop(name: orig.isNotEmpty ? orig : "Nørreport St.", time: addMin(0), date: dStr, track: "M", rtTime: addMin(0)),
        TripStop(name: "Kongens Nytorv St.", time: addMin(2), date: dStr, track: "M", rtTime: addMin(2)),
        TripStop(name: "Christianshavn St.", time: addMin(4), date: dStr, track: "M", rtTime: addMin(4)),
        TripStop(name: "Amagerbro St.", time: addMin(6), date: dStr, track: "M", rtTime: addMin(6)),
        TripStop(name: "Lergravsparken St.", time: addMin(8), date: dStr, track: "M", rtTime: addMin(8)),
        TripStop(name: "Øresund St.", time: addMin(10), date: dStr, track: "M", rtTime: addMin(10)),
        TripStop(name: "CPH Lufthavn", time: addMin(15), date: dStr, track: "M", rtTime: addMin(15)),
      ];
    }

    // 3. Regionaltog / IC (København H - Aarhus / Odense)
    if (name.contains("IC") || name.contains("RE") || dest.contains("Aarhus") || dest.contains("Odense") || dest.contains("Østerport")) {
      return [
        TripStop(name: "København H", time: addMin(0), date: dStr, track: "5", rtTime: addMin(0)),
        TripStop(name: "Vesterport St.", time: addMin(2), date: dStr, track: "2", rtTime: addMin(2)),
        TripStop(name: "Nørreport St.", time: addMin(4), date: dStr, track: "2", rtTime: addMin(4)),
        TripStop(name: "Østerport St.", time: addMin(7), date: dStr, track: "2", rtTime: addMin(7)),
      ];
    }

    // 4. Bus 5C
    if (name.contains("5C")) {
      return [
        TripStop(name: "Nørreport St.", time: addMin(0), date: dStr, track: "-", rtTime: addMin(0)),
        TripStop(name: "Nørre Voldgade", time: addMin(2), date: dStr, track: "-", rtTime: addMin(2)),
        TripStop(name: "Rådhuspladsen", time: addMin(5), date: dStr, track: "-", rtTime: addMin(5)),
        TripStop(name: "Stormbroen, Nationalmuseet", time: addMin(8), date: dStr, track: "-", rtTime: addMin(8)),
        TripStop(name: "Kongens Nytorv St.", time: addMin(12), date: dStr, track: "-", rtTime: addMin(12)),
      ];
    }

    // Default stops
    return [
      TripStop(name: orig, time: addMin(0), date: dStr, track: "1", rtTime: addMin(0)),
      TripStop(name: "$orig C", time: addMin(3), date: dStr, track: "1", rtTime: addMin(3)),
      TripStop(name: "$dest Syd", time: addMin(7), date: dStr, track: "2", rtTime: addMin(7)),
      TripStop(name: dest, time: addMin(12), date: dStr, track: "2", rtTime: addMin(12)),
    ];
  }
}

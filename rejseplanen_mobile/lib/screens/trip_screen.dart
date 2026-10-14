import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../models/trip.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../widgets/transit_badge.dart';
import '../i18n/translations.dart';
import '../widgets/station_picker.dart';
import '../widgets/trip_card.dart';
import '../services/notification_service.dart';

class TripScreen extends StatefulWidget {
  final Station? initialOrigin;
  final Station? initialDest;

  const TripScreen({super.key, this.initialOrigin, this.initialDest});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  Station _origin = Station(id: "", name: "");
  Station _destination = Station(id: "", name: "");
  bool _locatingOrigin = false;
  bool _hasSearched = false;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _searchForArrival = false;

  bool _filterTrain = true;
  bool _filterStog = true;
  bool _filterMetro = true;
  bool _filterBus = true;

  bool _isLoading = false;
  List<TripProposal> _trips = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrigin != null) {
      _origin = widget.initialOrigin!;
    } else {
      _autoLocateOrigin();
    }
    if (widget.initialDest != null) {
      _destination = widget.initialDest!;
    }
  }

  Future<void> _autoLocateOrigin() async {
    setState(() => _locatingOrigin = true);
    final loc = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (loc.isSuccess && loc.lat != null && loc.lon != null) {
      final config = Provider.of<AppConfig>(context, listen: false);
      final client = RejseplanenApiClient(config);
      final res = await client.nearbyStops(loc.lat!, loc.lon!, maxNo: 6);
      if (mounted) {
        setState(() => _locatingOrigin = false);
        if (res.data.isNotEmpty) {
          setState(() {
            _origin = res.data.first;
          });
        } else {
          setState(() {
            _origin = Station(id: "8600626", name: "København H", lat: 55.673063, lon: 12.565562);
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _locatingOrigin = false;
          _origin = Station(id: "8600626", name: "København H", lat: 55.673063, lon: 12.565562);
        });
      }
    }
  }

  void _swapStations() {
    setState(() {
      final tmp = _origin;
      _origin = _destination;
      _destination = tmp;
    });
  }

  void _resetToNow() {
    setState(() {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _searchTrips() async {
    if (_origin.name.isEmpty || _destination.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, "trip_select_both_error"))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    final config = Provider.of<AppConfig>(context, listen: false);
    config.addRecentStation(_origin);
    config.addRecentStation(_destination);
    final client = RejseplanenApiClient(config);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeStr =
        "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";

    final res = await client.getTrips(
      _origin.id,
      _destination.id,
      dateStr: dateStr,
      timeStr: timeStr,
      searchForArrival: _searchForArrival,
      useBus: _filterBus,
      useTrain: _filterTrain || _filterStog,
      useMetro: _filterMetro,
    );

    if (mounted) {
      setState(() {
        _trips = res.data;
        _errorMessage = res.error;
        _isLoading = false;
      });
    }
  }

  bool _tripMatchesFilters(TripProposal trip) {
    for (final leg in trip.legs) {
      final t = leg.type.trim().toUpperCase();
      final n = leg.name.trim().toUpperCase();
      final info = TransitBadgeHelper.parse(leg.name, leg.type);
      final cat = info.category.toUpperCase();

      // Walking legs between platforms or stations are always allowed
      if (cat == "WALK" || t == "WALK" || t.contains("GÅ") || n.contains("WALK")) {
        continue;
      }

      if (cat == "METRO" || t.contains("MET") || RegExp(r'\bM[1-4]\b').hasMatch(n)) {
        if (!_filterMetro) return false;
      } else if (cat == "BUS" || t.contains("BUS") || RegExp(r'^\d+[A-Z]?$').hasMatch(n.replaceAll(RegExp(r'^(BUS|BYBUS)\s*', caseSensitive: false), '').trim())) {
        if (!_filterBus) return false;
      } else if (cat == "S-TOG" || t.contains("S-TOG") || t == "S" || RegExp(r'^[A-H](X)?$').hasMatch(info.display)) {
        if (!_filterStog) return false;
      } else {
        // Regionaltog, InterCity, InterCityLyn, Lokaltog, Letbane, etc.
        if (!_filterTrain) return false;
      }
    }
    return true;
  }

  Widget _buildSuggestedRoutesSection(BuildContext context) {
    final theme = Theme.of(context);
    final popularTrips = [
      {
        "orig": Station(id: "8600626", name: "København H", lat: 55.673063, lon: 12.565562),
        "dest": Station(id: "8600858", name: "CPH Lufthavn", lat: 55.6294, lon: 12.6492),
        "title": "København H ➔ CPH Lufthavn",
        "desc": "Metro M2 / Øresundstog",
        "icon": Icons.flight_takeoff,
      },
      {
        "orig": Station(id: "8600626", name: "København H", lat: 55.673063, lon: 12.565562),
        "dest": Station(id: "8600646", name: "Nørreport St.", lat: 55.6831, lon: 12.5714),
        "title": "København H ➔ Nørreport St.",
        "desc": "S-tog (A/B/C/E/H) / Metro M3",
        "icon": Icons.train,
      },
      {
        "orig": Station(id: "8600626", name: "København H", lat: 55.673063, lon: 12.565562),
        "dest": Station(id: "8600053", name: "Aarhus H", lat: 56.1504, lon: 10.2047),
        "title": "København H ➔ Aarhus H",
        "desc": "DSB InterCityLyn / IC",
        "icon": Icons.directions_railway,
      },
      {
        "orig": Station(id: "8600626", name: "København H", lat: 55.673063, lon: 12.565562),
        "dest": Station(id: "8600100", name: "Odense St.", lat: 55.4017, lon: 10.3892),
        "title": "København H ➔ Odense St.",
        "desc": "DSB InterCity / Regionaltog",
        "icon": Icons.speed,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                I18n.t(context, "station_suggested"),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in popularTrips)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  child: Icon(item["icon"] as IconData, color: theme.colorScheme.primary, size: 20),
                ),
                title: Text(
                  item["title"] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  item["desc"] as String,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () {
                  setState(() {
                    _origin = item["orig"] as Station;
                    _destination = item["dest"] as Station;
                  });
                  _searchTrips();
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = Provider.of<AppConfig>(context);
    final dateStr = DateFormat('dd.MM.yyyy').format(_selectedDate);
    final timeStr =
        "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";
    final displayedTrips = _trips.where(_tripMatchesFilters).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(context, "trip_title"), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _searchTrips,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Active Ongoing Trip Banner
            if (config.hasActiveOngoingTrip && config.activeOngoingTrip != null) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.radar, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                I18n.t(context, "trip_ongoing_banner_title"),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "LIVE",
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${config.activeOngoingOrigin?.name} ➔ ${config.activeOngoingDest?.name} (${config.activeOngoingTrip?.depTime} - ${config.activeOngoingTrip?.arrTime})",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            I18n.t(context, "trip_ongoing_banner_desc"),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: I18n.t(context, "trip_ongoing_stop"),
                      onPressed: () async {
                        await NotificationService().stopOngoingTripNotification();
                        config.stopOngoingTrip();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(I18n.t(context, "trip_ongoing_stopped_snack"))),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Search Card
            Card(
              elevation: 2,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Origin and Destination Row with Swap Button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              // Origin Picker Tile
                              InkWell(
                                onTap: () async {
                                  final s = await StationPickerModal.show(context,
                                      title: I18n.t(context, "trip_origin"));
                                  if (s != null) setState(() => _origin = s);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.trip_origin, size: 18, color: Colors.blue),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _locatingOrigin
                                            ? Row(
                                                children: [
                                                  const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      I18n.t(context, "station_locating"),
                                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                _origin.name.isNotEmpty
                                                    ? _origin.name
                                                    : I18n.t(context, "trip_origin_placeholder"),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: _origin.name.isNotEmpty
                                                      ? theme.colorScheme.onSurface
                                                      : Colors.grey.shade500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                      ),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: _locatingOrigin ? null : _autoLocateOrigin,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.my_location,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Destination Picker Tile
                              InkWell(
                                onTap: () async {
                                  final s = await StationPickerModal.show(context,
                                      title: I18n.t(context, "trip_dest"));
                                  if (s != null) setState(() => _destination = s);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 18, color: Colors.red),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _destination.name.isNotEmpty
                                              ? _destination.name
                                              : I18n.t(context, "trip_dest_placeholder"),
                                          style: TextStyle(
                                            fontWeight: _destination.name.isNotEmpty
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: _destination.name.isNotEmpty
                                                ? theme.colorScheme.onSurface
                                                : Colors.grey.shade500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_destination.name.isNotEmpty)
                                        InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () {
                                            setState(() => _destination = Station(id: "", name: ""));
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(4.0),
                                            child: Icon(Icons.clear, size: 18, color: Colors.grey),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Swap button
                        IconButton.filledTonal(
                          onPressed: _swapStations,
                          icon: const Icon(Icons.swap_vert),
                          tooltip: I18n.t(context, "trip_swap"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Date & Time pickers Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(dateStr, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(timeStr, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.restore),
                          tooltip: I18n.t(context, "trip_now"),
                          onPressed: _resetToNow,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Depart / Arrive Segment
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(I18n.t(context, "trip_mode_dep")),
                          icon: const Icon(Icons.arrow_upward, size: 16),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(I18n.t(context, "trip_mode_arr")),
                          icon: const Icon(Icons.arrow_downward, size: 16),
                        ),
                      ],
                      selected: {_searchForArrival},
                      onSelectionChanged: (val) {
                        setState(() => _searchForArrival = val.first);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Mode Filters
                    Wrap(
                      spacing: 6,
                      children: [
                        FilterChip(
                          label: Text(I18n.t(context, "filter_train")),
                          selected: _filterTrain,
                          onSelected: (val) => setState(() => _filterTrain = val),
                        ),
                        FilterChip(
                          label: Text(I18n.t(context, "filter_stog")),
                          selected: _filterStog,
                          onSelected: (val) => setState(() => _filterStog = val),
                        ),
                        FilterChip(
                          label: Text(I18n.t(context, "filter_metro")),
                          selected: _filterMetro,
                          onSelected: (val) => setState(() => _filterMetro = val),
                        ),
                        FilterChip(
                          label: Text(I18n.t(context, "filter_bus")),
                          selected: _filterBus,
                          onSelected: (val) => setState(() => _filterBus = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _searchTrips,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          _isLoading
                              ? I18n.t(context, "trip_searching")
                              : I18n.t(context, "trip_search"),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Recommendations vs Results
            if (!_hasSearched) ...[
              _buildSuggestedRoutesSection(context),
            ] else ...[
              // Results Section
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              if (displayedTrips.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        I18n.t(context, "trip_results"),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        I18n.t(context, "trip_results_count", {"count": "${displayedTrips.length}"}),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                for (var trip in displayedTrips)
                  TripCard(
                    trip: trip,
                    origin: _origin,
                    destination: _destination,
                  ),
              ] else if (!_isLoading) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(Icons.directions_subway_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          I18n.t(context, "trip_no_results"),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

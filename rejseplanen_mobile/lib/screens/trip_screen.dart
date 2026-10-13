import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../models/trip.dart';
import '../services/api_client.dart';
import '../i18n/translations.dart';
import '../widgets/station_picker.dart';
import '../widgets/trip_card.dart';

class TripScreen extends StatefulWidget {
  final Station? initialOrigin;
  final Station? initialDest;

  const TripScreen({super.key, this.initialOrigin, this.initialDest});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  Station _origin = Station(id: "8600626", name: "København H");
  Station _destination = Station(id: "8600646", name: "Nørreport St.");

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _searchForArrival = false;

  bool _filterTrain = true;
  bool _filterStog = true;
  bool _filterMetro = true;
  bool _filterBus = true;

  bool _isLoading = false;
  List<TripProposal> _trips = [];
  bool _isMock = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrigin != null) _origin = widget.initialOrigin!;
    if (widget.initialDest != null) _destination = widget.initialDest!;
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
    });

    final config = Provider.of<AppConfig>(context, listen: false);
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
      useTrain: _filterTrain,
      useMetro: _filterMetro,
    );

    if (mounted) {
      setState(() {
        _trips = res.data;
        _isMock = res.isMock;
        _errorMessage = res.error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd.MM.yyyy').format(_selectedDate);
    final timeStr =
        "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(context, "trip_title"), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isMock ? Colors.amber.withOpacity(0.2) : Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMock ? Icons.cloud_off : Icons.cloud_done,
                  size: 14,
                  color: _isMock ? Colors.orange.shade800 : Colors.green.shade800,
                ),
                const SizedBox(width: 4),
                Text(
                  _isMock ? I18n.t(context, "mock_badge") : I18n.t(context, "live_badge"),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isMock ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _searchTrips,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
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
                                        child: Text(
                                          _origin.name.isNotEmpty
                                              ? _origin.name
                                              : I18n.t(context, "trip_origin_placeholder"),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
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
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
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

            // Results Section
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            if (_trips.isNotEmpty) ...[
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
                      "${_trips.length} 条路线",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              for (var trip in _trips)
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
              )
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../models/departure.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../i18n/translations.dart';
import '../widgets/station_picker.dart';
import '../widgets/transit_badge.dart';
import '../widgets/journey_detail_sheet.dart';

class BoardScreen extends StatefulWidget {
  final Station? initialStation;

  const BoardScreen({super.key, this.initialStation});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Station _currentStation = Station(id: "8600626", name: "København H", lat: 55.673063, lon: 12.565562);

  List<Departure> _departures = [];
  List<Departure> _arrivals = [];
  bool _isLoading = false;
  bool _isMock = true;
  String? _errorMessage;
  String _selectedMode = "ALL";

  bool _autoRefresh = false;
  Timer? _refreshTimer;

  double? _currentLat;
  double? _currentLon;

  @override
  void initState() {
    super.initState();
    if (widget.initialStation != null) {
      _currentStation = widget.initialStation!;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final config = Provider.of<AppConfig>(context, listen: false);
        final preds = config.smartService.predictBoardStations(
          favoriteStations: config.favoriteStations,
          recentStations: config.recentStations,
          limit: 1,
        );
        if (preds.isNotEmpty && preds.first.station.name != _currentStation.name) {
          setState(() => _currentStation = preds.first.station);
          _fetchBoard();
        }
      });
    }
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchBoard();
      }
    });
    _fetchBoard();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _toggleAutoRefresh(bool val) {
    setState(() => _autoRefresh = val);
    _refreshTimer?.cancel();
    if (_autoRefresh) {
      final config = Provider.of<AppConfig>(context, listen: false);
      _refreshTimer = Timer.periodic(
        Duration(seconds: config.autoRefreshInterval),
        (_) => _fetchBoard(showIndicator: false),
      );
    }
  }

  bool _locatingGps = false;

  Future<void> _locateCurrentStation() async {
    setState(() => _locatingGps = true);
    final loc = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (loc.isSuccess && loc.lat != null && loc.lon != null) {
      _currentLat = loc.lat;
      _currentLon = loc.lon;
      final config = Provider.of<AppConfig>(context, listen: false);
      final client = RejseplanenApiClient(config);
      final res = await client.nearbyStops(loc.lat!, loc.lon!, maxNo: 6);
      if (mounted) {
        setState(() => _locatingGps = false);
        if (res.data.isNotEmpty) {
          final nearest = res.data.first;
          config.recordBoardStationView(nearest);
          setState(() => _currentStation = nearest);
          _fetchBoard();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${I18n.t(context, "station_get_current_location")}: ${nearest.name}"),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(I18n.t(context, "station_empty_nearby"))),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() => _locatingGps = false);
        final errKey = loc.errorKey ?? "location_error";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(context, errKey))),
        );
      }
    }
  }

  Future<void> _fetchBoard({bool showIndicator = true}) async {
    if (showIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final config = Provider.of<AppConfig>(context, listen: false);
    final client = RejseplanenApiClient(config);
    final isArrival = _tabController.index == 1;

    // Always fetch all transit modes so client-side filter chips switch instantaneously
    if (isArrival) {
      final res = await client.getArrivalBoard(
        _currentStation.id,
        useTrain: true,
        useMetro: true,
        useBus: true,
      );
      if (mounted) {
        setState(() {
          _arrivals = res.data;
          _isMock = res.isMock;
          _errorMessage = res.error;
          _isLoading = false;
        });
      }
    } else {
      final res = await client.getDepartureBoard(
        _currentStation.id,
        useTrain: true,
        useMetro: true,
        useBus: true,
      );
      if (mounted) {
        setState(() {
          _departures = res.data;
          _isMock = res.isMock;
          _errorMessage = res.error;
          _isLoading = false;
        });
      }
    }
  }

  bool _matchesMode(Departure item, String mode) {
    if (mode == "ALL") return true;
    final info = TransitBadgeHelper.parse(item.name, item.type);
    final cat = info.category.toUpperCase();
    final type = item.type.toUpperCase();
    final name = item.name.toUpperCase();

    if (mode == "METRO") {
      return cat == "METRO" || type.contains("MET") || RegExp(r'\bM[1-4]\b').hasMatch(name);
    }
    if (mode == "BUS") {
      return cat == "BUS" ||
          type.contains("BUS") ||
          RegExp(r'^\d+[A-Z]?$').hasMatch(name.replaceAll(RegExp(r'^(BUS|BYBUS)\s*', caseSensitive: false), '').trim());
    }
    if (mode == "TRAIN") {
      if (cat == "METRO" || cat == "BUS") return false;
      if (type.contains("MET") || type.contains("BUS")) return false;
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = Provider.of<AppConfig>(context);
    final isArrival = _tabController.index == 1;
    final currentList = isArrival ? _arrivals : _departures;

    int countAll = currentList.length;
    int countTrain = 0;
    int countMetro = 0;
    int countBus = 0;

    for (final d in currentList) {
      if (_matchesMode(d, "METRO")) {
        countMetro++;
      } else if (_matchesMode(d, "BUS")) {
        countBus++;
      } else {
        countTrain++;
      }
    }

    final filteredList = _selectedMode == "ALL"
        ? currentList
        : currentList.where((d) => _matchesMode(d, _selectedMode)).toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(I18n.t(context, "board_title"), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Auto refresh toggle icon
          IconButton(
            icon: Icon(
              _autoRefresh ? Icons.sync : Icons.sync_disabled,
              color: _autoRefresh ? theme.colorScheme.primary : null,
            ),
            tooltip: I18n.t(context, "board_auto_refresh"),
            onPressed: () => _toggleAutoRefresh(!_autoRefresh),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchBoard(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: I18n.t(context, "board_type_dep"), icon: const Icon(Icons.flight_takeoff, size: 20)),
            Tab(text: I18n.t(context, "board_type_arr"), icon: const Icon(Icons.flight_land, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Station Selection & Smart Station Card
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          final s = await StationPickerModal.show(context,
                              title: I18n.t(context, "board_station"));
                          if (s != null) {
                            final config = Provider.of<AppConfig>(context, listen: false);
                            config.addRecentStation(s);
                            config.recordBoardStationView(s);
                            setState(() => _currentStation = s);
                            _fetchBoard();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.train, size: 20, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentStation.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: _locatingGps
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 20),
                      tooltip: I18n.t(context, "station_get_current_location"),
                      onPressed: _locatingGps ? null : _locateCurrentStation,
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      icon: Icon(
                        config.isFavoriteStation(_currentStation.id) ? Icons.star : Icons.star_border,
                        color: config.isFavoriteStation(_currentStation.id) ? Colors.amber : null,
                      ),
                      tooltip: I18n.t(context, "board_add_fav"),
                      onPressed: () {
                        if (config.isFavoriteStation(_currentStation.id)) {
                          config.removeFavoriteStation(_currentStation.id);
                        } else {
                          config.addFavoriteStation(_currentStation);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(I18n.t(context, "saved_to_fav"))),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.map_outlined, size: 20),
                      tooltip: I18n.t(context, "station_open_in_maps"),
                      onPressed: () {
                        LocationService.openInMaps(
                          _currentStation.lat,
                          _currentStation.lon,
                          name: _currentStation.name,
                        );
                      },
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final smartStations = config.smartService.predictBoardStations(
                      favoriteStations: config.favoriteStations,
                      recentStations: config.recentStations,
                      currentLat: _currentLat,
                      currentLon: _currentLon,
                      limit: 4,
                    );
                    if (smartStations.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              "${I18n.t(context, 'board_smart_stations')}:",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            for (final pred in smartStations)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  backgroundColor: pred.station.name == _currentStation.name
                                      ? theme.colorScheme.primaryContainer
                                      : null,
                                  label: Text(
                                    pred.station.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: pred.station.name == _currentStation.name
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  onPressed: () {
                                    if (pred.station.name != _currentStation.name) {
                                      config.recordBoardStationView(pred.station);
                                      setState(() => _currentStation = pred.station);
                                      _fetchBoard();
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Transit Mode Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildModeChip(context, "ALL", I18n.t(context, "board_filter_all"), Icons.apps, countAll),
                const SizedBox(width: 8),
                _buildModeChip(context, "TRAIN", I18n.t(context, "board_filter_train"), Icons.train, countTrain),
                const SizedBox(width: 8),
                _buildModeChip(context, "METRO", I18n.t(context, "board_filter_metro"), Icons.subway, countMetro),
                const SizedBox(width: 8),
                _buildModeChip(context, "BUS", I18n.t(context, "board_filter_bus"), Icons.directions_bus, countBus),
              ],
            ),
          ),

          if (_isLoading) const LinearProgressIndicator(),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),

          // Board list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchBoard(),
              child: filteredList.isEmpty && !_isLoading
                  ? Center(
                      child: Text(
                        I18n.t(context, "board_no_departures"),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = filteredList[i];
                        return _buildBoardTile(context, item);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardTile(BuildContext context, Departure item) {
    Color statusColor = Colors.green;
    String statusText = I18n.t(context, "status_ontime");

    if (item.isCancelled) {
      statusColor = Colors.red;
      statusText = I18n.t(context, "status_cancelled");
    } else if (item.isDelayed) {
      statusColor = Colors.red;
      statusText = "+${item.delay}m";
    } else if (item.delay > 0) {
      statusColor = Colors.orange;
      statusText = "+${item.delay}m";
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () {
        JourneyDetailSheet.show(
          context,
          departure: item,
          currentStation: _currentStation.name,
        );
      },
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      leading: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 40, maxWidth: 84),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TransitBadge(
            text: item.name,
            typeCode: item.type,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.direction.isNotEmpty ? item.direction : item.stop,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.track.isNotEmpty && item.track != "-") ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${I18n.t(context, "board_col_track")} ${item.track}",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            item.time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              decoration: item.delay > 0 ? TextDecoration.lineThrough : null,
              color: item.delay > 0 ? Colors.grey : null,
            ),
          ),
          if (item.delay > 0) ...[
            const SizedBox(width: 6),
            Text(
              item.rtTime,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (item.messages.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.messages,
                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildModeChip(BuildContext context, String mode, String label, IconData icon, int count) {
    final theme = Theme.of(context);
    final isSelected = _selectedMode == mode;
    final displayLabel = count > 0 ? "$label ($count)" : label;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
      ),
      label: Text(
        displayLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.35),
      selectedColor: theme.colorScheme.primary,
      onSelected: (_) {
        setState(() => _selectedMode = mode);
      },
    );
  }
}

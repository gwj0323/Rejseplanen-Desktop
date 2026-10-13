import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../i18n/translations.dart';
import 'board_screen.dart';
import 'trip_screen.dart';

class StationScreen extends StatefulWidget {
  const StationScreen({super.key});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Station> _searchResults = [];
  bool _searching = false;

  // Nearby coordinates (default Copenhagen Central)
  double _lat = 55.6761;
  double _lon = 12.5683;
  String? _currentPositionLabel;
  List<Station> _nearbyResults = [];
  bool _loadingNearby = false;
  bool _locatingGps = false;
  LocationResult? _lastLocationResult;

  @override
  void initState() {
    super.initState();
    // Automatically request GPS location & search nearby stops when entering screen
    _locateCurrentPosition();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final config = Provider.of<AppConfig>(context, listen: false);
    config.addRecentSearch(query);

    setState(() => _searching = true);
    final client = RejseplanenApiClient(config);
    client.searchLocations(query).then((res) {
      if (mounted) {
        setState(() {
          _searchResults = res.data;
          _searching = false;
        });
      }
    });
  }

  void _loadNearby() {
    setState(() => _loadingNearby = true);
    final client = RejseplanenApiClient(Provider.of<AppConfig>(context, listen: false));
    client.nearbyStops(_lat, _lon, maxNo: 12).then((res) {
      if (mounted) {
        setState(() {
          _nearbyResults = res.data;
          _loadingNearby = false;
        });
      }
    });
  }

  Future<void> _locateCurrentPosition() async {
    setState(() => _locatingGps = true);
    final locResult = await LocationService.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _lastLocationResult = locResult;
      _locatingGps = false;
    });

    if (locResult.isSuccess && locResult.lat != null && locResult.lon != null) {
      setState(() {
        _lat = locResult.lat!;
        _lon = locResult.lon!;
        _currentPositionLabel =
            "${locResult.lat!.toStringAsFixed(4)}, ${locResult.lon!.toStringAsFixed(4)}";
      });
      _loadNearby();
    } else {
      // Fallback to load default/preset stations so user sees content
      _loadNearby();
      final errorKey = locResult.errorKey ?? "location_error";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.t(context, errorKey)),
          action: locResult.isPermissionDeniedForever
              ? SnackBarAction(
                  label: I18n.t(context, "station_go_settings"),
                  onPressed: () => LocationService.openAppSettings(),
                )
              : (locResult.isServiceDisabled
                  ? SnackBarAction(
                      label: I18n.t(context, "station_enable_gps"),
                      onPressed: () => LocationService.openLocationSettings(),
                    )
                  : null),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _setPreset(double lat, double lon, String name) {
    setState(() {
      _lat = lat;
      _lon = lon;
      _currentPositionLabel = name;
    });
    _loadNearby();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = Provider.of<AppConfig>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(context, "station_title"), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _locatingGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            tooltip: I18n.t(context, "station_get_current_location"),
            onPressed: _locatingGps ? null : _locateCurrentPosition,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Search input box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: I18n.t(context, "station_search_placeholder"),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch("");
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Recent search history chips
          if (_searchCtrl.text.isEmpty && config.recentSearches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    I18n.t(context, "station_recent_searches"),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => config.clearRecentSearches(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(I18n.t(context, "station_clear_recent")),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var query in config.recentSearches)
                    ActionChip(
                      avatar: const Icon(Icons.history, size: 14, color: Colors.grey),
                      label: Text(query, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _searchCtrl.text = query;
                        _onSearch(query);
                      },
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Divider(height: 1),
            ),
          ],

          if (_searching)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Search results
          if (_searchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                I18n.t(context, "station_search_results_count", {"count": "${_searchResults.length}"}),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            for (var station in _searchResults) _buildStationTile(context, station, config),
            const Divider(height: 24),
          ],

          // Permission warning card if denied forever
          if (_lastLocationResult?.isPermissionDeniedForever == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                color: Colors.amber.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          I18n.t(context, "location_permission_denied_forever"),
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ),
                      TextButton(
                        onPressed: () => LocationService.openAppSettings(),
                        child: Text(I18n.t(context, "station_perm_denied_btn")),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Location service disabled warning card
          if (_lastLocationResult?.isServiceDisabled == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                color: Colors.amber.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          I18n.t(context, "location_services_disabled"),
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ),
                      TextButton(
                        onPressed: () => LocationService.openLocationSettings(),
                        child: Text(I18n.t(context, "station_gps_disabled_btn")),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // GPS Location Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withOpacity(0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.my_location, color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          I18n.t(context, "station_nearby_title"),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: _locatingGps ? null : _locateCurrentPosition,
                          icon: _locatingGps
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.gps_fixed, size: 16),
                          label: Text(
                            _locatingGps
                                ? I18n.t(context, "station_locating")
                                : I18n.t(context, "station_get_current_location"),
                          ),
                        ),
                      ],
                    ),
                    if (_currentPositionLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        "${I18n.t(context, "current_location_coords")}: $_currentPositionLabel",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Quick city presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.location_city, size: 16),
                          label: Text(I18n.t(context, "station_preset_cph")),
                          onPressed: () => _setPreset(55.6761, 12.5683, I18n.t(context, "station_preset_cph")),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.flight_takeoff, size: 16),
                          label: Text(I18n.t(context, "station_preset_cph_airport")),
                          onPressed: () => _setPreset(55.6294, 12.6492, I18n.t(context, "station_preset_cph_airport")),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.location_city, size: 16),
                          label: Text(I18n.t(context, "station_preset_aarhus")),
                          onPressed: () => _setPreset(56.1504, 10.2047, I18n.t(context, "station_preset_aarhus")),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.location_city, size: 16),
                          label: Text(I18n.t(context, "station_preset_odense")),
                          onPressed: () => _setPreset(55.4018, 10.3867, I18n.t(context, "station_preset_odense")),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.location_city, size: 16),
                          label: Text(I18n.t(context, "station_preset_aalborg")),
                          onPressed: () => _setPreset(57.0425, 9.9172, I18n.t(context, "station_preset_aalborg")),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Outside Denmark notice card
          if (!LocationService.isInDenmark(_lat, _lon))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.tertiaryContainer.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.public, color: theme.colorScheme.tertiary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${I18n.t(context, "station_outside_title")} (~${LocationService.distanceToDenmarkKm(_lat, _lon).round()} km)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              I18n.t(context, "station_outside_desc"),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onTertiaryContainer.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_loadingNearby)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(),
            ),

          if (!_loadingNearby && _nearbyResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.location_off_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      I18n.t(context, "station_empty_nearby"),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      I18n.t(context, "station_empty_nearby_desc"),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadNearby,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(I18n.t(context, "board_refresh")),
                    ),
                  ],
                ),
              ),
            ),

          for (var station in _nearbyResults) _buildStationTile(context, station, config),
        ],
      ),
    );
  }

  Widget _buildStationTile(BuildContext context, Station station, AppConfig config) {
    final isFav = config.isFavoriteStation(station.id);

    final List<String> subtitleParts = [];
    if (station.distance != null && station.distance!.isNotEmpty) {
      subtitleParts.add(station.distance!);
    }
    if (station.desc != null && station.desc!.isNotEmpty) {
      subtitleParts.add(station.desc!);
    }
    if (subtitleParts.isEmpty) {
      subtitleParts.add("ID: ${station.id}");
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE2E8F0),
        child: Icon(Icons.train, color: Color(0xFF0F172A), size: 20),
      ),
      title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitleParts.join(" • "),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: () {
        config.addRecentSearch(station.name);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BoardScreen(initialStation: station)),
        );
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : null,
              size: 22,
            ),
            onPressed: () {
              if (isFav) {
                config.removeFavoriteStation(station.id);
              } else {
                config.addFavoriteStation(station);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              config.addRecentSearch(station.name);
              if (val == 'board') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BoardScreen(initialStation: station)),
                );
              } else if (val == 'plan') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TripScreen(initialOrigin: station)),
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'board',
                child: Row(
                  children: [
                    const Icon(Icons.dashboard_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(I18n.t(context, "station_action_dep")),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'plan',
                child: Row(
                  children: [
                    const Icon(Icons.navigation_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(I18n.t(context, "station_action_plan")),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

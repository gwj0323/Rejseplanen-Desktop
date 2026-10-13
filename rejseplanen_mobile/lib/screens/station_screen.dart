import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../services/api_client.dart';
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

  // Nearby coordinates
  double _lat = 55.6761;
  double _lon = 12.5683;
  List<Station> _nearbyResults = [];
  bool _loadingNearby = false;

  @override
  void initState() {
    super.initState();
    _loadNearby();
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
    setState(() => _searching = true);
    final client = RejseplanenApiClient(Provider.of<AppConfig>(context, listen: false));
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
    client.nearbyStops(_lat, _lon, maxNo: 8).then((res) {
      if (mounted) {
        setState(() {
          _nearbyResults = res.data;
          _loadingNearby = false;
        });
      }
    });
  }

  void _setPreset(double lat, double lon) {
    setState(() {
      _lat = lat;
      _lon = lon;
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
                "搜索结果 (${_searchResults.length})",
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            for (var station in _searchResults) _buildStationTile(context, station, config),
            const Divider(height: 24),
          ],

          // Nearby Stops section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      I18n.t(context, "station_nearby_title"),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_loadingNearby)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // City presets
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.location_city, size: 16),
                      label: Text(I18n.t(context, "station_preset_cph")),
                      onPressed: () => _setPreset(55.6761, 12.5683),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.location_city, size: 16),
                      label: Text(I18n.t(context, "station_preset_aarhus")),
                      onPressed: () => _setPreset(56.1504, 10.2047),
                    ),
                  ],
                ),
              ],
            ),
          ),

          for (var station in _nearbyResults) _buildStationTile(context, station, config),
        ],
      ),
    );
  }

  Widget _buildStationTile(BuildContext context, Station station, AppConfig config) {
    final isFav = config.isFavoriteStation(station.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE2E8F0),
        child: Icon(Icons.train, color: Color(0xFF0F172A), size: 20),
      ),
      title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        station.desc ??
            (station.distance != null ? "${station.distance} m" : "ID: ${station.id}"),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Favorite button
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
          // View Board Popup
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../i18n/translations.dart';

class StationPickerModal extends StatefulWidget {
  final String title;

  const StationPickerModal({super.key, required this.title});

  static Future<Station?> show(BuildContext context, {required String title}) {
    return showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StationPickerModal(title: title),
    );
  }

  @override
  State<StationPickerModal> createState() => _StationPickerModalState();
}

class _StationPickerModalState extends State<StationPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  List<Station> _suggestedResults = [];
  List<Station> _searchResults = [];
  bool _loading = false;
  bool _locatingGps = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadInitialSuggestions();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadInitialSuggestions() {
    final client = RejseplanenApiClient(Provider.of<AppConfig>(context, listen: false));
    client.searchLocations("").then((res) {
      if (mounted) {
        setState(() {
          _suggestedResults = res.data;
        });
      }
    });
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    _debounceTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final client = RejseplanenApiClient(Provider.of<AppConfig>(context, listen: false));
      client.searchLocations(q).then((res) {
        if (mounted && _searchCtrl.text.trim() == q) {
          setState(() {
            _searchResults = res.data;
            _loading = false;
          });
        }
      });
    });
  }

  Future<void> _fetchNearbyByGps() async {
    setState(() => _locatingGps = true);
    final loc = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (loc.isSuccess && loc.lat != null && loc.lon != null) {
      final client = RejseplanenApiClient(Provider.of<AppConfig>(context, listen: false));
      final res = await client.nearbyStops(loc.lat!, loc.lon!, maxNo: 15);
      if (mounted) {
        setState(() {
          _suggestedResults = res.data;
          _locatingGps = false;
        });
        if (!LocationService.isInDenmark(loc.lat!, loc.lon!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${I18n.t(context, "station_outside_title")}: ${I18n.t(context, "station_outside_desc")}",
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      if (!mounted) return;
      setState(() => _locatingGps = false);
      final errorKey = loc.errorKey ?? "location_error";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.t(context, errorKey)),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  void _selectStation(AppConfig config, Station station) {
    FocusManager.instance.primaryFocus?.unfocus();
    config.addRecentStation(station);
    Navigator.of(context).pop(station);
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context);
    final theme = Theme.of(context);
    final query = _searchCtrl.text.trim();
    final bool isSearching = query.isNotEmpty;

    // Filter matching history when query is non-empty
    final matchingHistory = isSearching
        ? config.recentStations
            .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
            .toList()
        : <Station>[];

    // Filter API results so we don't duplicate items already in matchingHistory
    final filteredSearchResults = _searchResults.where((s) {
      return !matchingHistory.any((h) => h.id == s.id || h.name.toLowerCase() == s.name.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: I18n.t(context, "station_search_placeholder"),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // Quick Action Row: GPS Location & Favorites
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // GPS Button
                  ActionChip(
                    avatar: _locatingGps
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.my_location, size: 16, color: theme.colorScheme.primary),
                    label: Text(
                      _locatingGps
                          ? I18n.t(context, "station_locating")
                          : I18n.t(context, "station_get_current_location"),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _locatingGps ? null : _fetchNearbyByGps,
                  ),
                  const SizedBox(width: 8),

                  // Favorite Stations
                  for (var s in config.favoriteStations) ...[
                    ActionChip(
                      avatar: const Icon(Icons.star, size: 15, color: Colors.amber),
                      label: Text(s.name, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _selectStation(config, s),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),

          if (_loading || _locatingGps)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: LinearProgressIndicator(),
            ),

          // Main Station List
          Expanded(
            child: isSearching
                ? _buildSearchResults(context, config, matchingHistory, filteredSearchResults)
                : _buildIdleStationList(context, config),
          ),
        ],
      ),
    );
  }

  /// View shown when search query is empty: History at top, followed by suggestions
  Widget _buildIdleStationList(BuildContext context, AppConfig config) {
    final theme = Theme.of(context);
    final recentList = config.recentStations;
    final suggestedList = _suggestedResults;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // 1. Recent Search History Section
        if (recentList.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Text(
                  I18n.t(context, "station_recent_searches"),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => config.clearRecentStations(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    I18n.t(context, "station_clear_recent"),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          for (var s in recentList)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.history, color: Colors.blue.shade700, size: 16),
              ),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                s.desc ?? (s.distance != null ? s.distance! : I18n.t(context, "station_recent_searches")),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                tooltip: I18n.t(context, "station_clear_recent"),
                onPressed: () => config.removeRecentStation(s.id),
              ),
              onTap: () => _selectStation(config, s),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(height: 1),
          ),
        ],

        // 2. Suggested Stations Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(Icons.explore_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                I18n.t(context, "station_suggested"),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        if (suggestedList.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                I18n.t(context, "station_history_empty"),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          for (var s in suggestedList)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFF1F5F9),
                child: const Icon(Icons.train, color: Color(0xFF475569), size: 16),
              ),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                s.desc ?? (s.distance != null ? s.distance! : "ID: ${s.id}"),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
              onTap: () => _selectStation(config, s),
            ),
      ],
    );
  }

  /// View shown when actively searching: History matches first, then live API results
  Widget _buildSearchResults(
    BuildContext context,
    AppConfig config,
    List<Station> matchingHistory,
    List<Station> apiResults,
  ) {
    final theme = Theme.of(context);

    if (matchingHistory.isEmpty && apiResults.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              I18n.t(context, "station_empty_nearby"),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Matching history results
        if (matchingHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  I18n.t(context, "station_recent_searches"),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
          for (var s in matchingHistory)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.history, color: Colors.blue.shade700, size: 16),
              ),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                s.desc ?? I18n.t(context, "station_recent_searches"),
                style: TextStyle(color: Colors.blue.shade700, fontSize: 11),
              ),
              onTap: () => _selectStation(config, s),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divider(height: 1),
          ),
        ],

        // API search results
        for (var s in apiResults)
          ListTile(
            dense: true,
            leading: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFF1F5F9),
              child: Icon(Icons.train, color: Color(0xFF0F172A), size: 16),
            ),
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              s.desc ?? (s.distance != null ? s.distance! : "ID: ${s.id}"),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
            onTap: () => _selectStation(config, s),
          ),
      ],
    );
  }
}

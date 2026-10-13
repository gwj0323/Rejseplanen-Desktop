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
  List<Station> _results = [];
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
          _results = res.data;
        });
      }
    });
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      _loadInitialSuggestions();
      return;
    }
    setState(() => _loading = true);
    final client = RejseplanenApiClient(Provider.of<AppConfig>(context, listen: false));
    client.searchLocations(q).then((res) {
      if (mounted) {
        setState(() {
          _results = res.data;
          _loading = false;
        });
      }
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
          _results = res.data;
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

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context);
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  for (var s in config.favoriteStations) ...[
                    ActionChip(
                      avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                      label: Text(s.name, style: const TextStyle(fontSize: 12)),
                      onPressed: () => Navigator.of(context).pop(s),
                    ),
                    const SizedBox(width: 8),
                  ],
                  for (var q in config.recentSearches) ...[
                    ActionChip(
                      avatar: const Icon(Icons.history, size: 14, color: Colors.grey),
                      label: Text(q, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _searchCtrl.text = q;
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),

          if (_loading || _locatingGps)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LinearProgressIndicator(),
            ),

          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
              itemBuilder: (ctx, i) {
                final s = _results[i];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Icon(Icons.train, color: Color(0xFF0F172A), size: 20),
                  ),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    s.desc ?? (s.distance != null ? "${s.distance} m" : "ID: ${s.id}"),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    config.addRecentSearch(s.name);
                    Navigator.of(context).pop(s);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

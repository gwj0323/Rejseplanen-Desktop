import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../models/departure.dart';
import '../services/api_client.dart';
import '../i18n/translations.dart';
import '../widgets/station_picker.dart';
import '../widgets/transit_badge.dart';

class BoardScreen extends StatefulWidget {
  final Station? initialStation;

  const BoardScreen({super.key, this.initialStation});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Station _currentStation = Station(id: "8600626", name: "København H");

  List<Departure> _departures = [];
  List<Departure> _arrivals = [];
  bool _isLoading = false;
  bool _isMock = true;
  String? _errorMessage;

  bool _autoRefresh = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialStation != null) {
      _currentStation = widget.initialStation!;
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

    if (isArrival) {
      final res = await client.getArrivalBoard(_currentStation.id);
      if (mounted) {
        setState(() {
          _arrivals = res.data;
          _isMock = res.isMock;
          _errorMessage = res.error;
          _isLoading = false;
        });
      }
    } else {
      final res = await client.getDepartureBoard(_currentStation.id);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = Provider.of<AppConfig>(context);
    final isArrival = _tabController.index == 1;
    final currentList = isArrival ? _arrivals : _departures;

    return Scaffold(
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
          // Station Selection & Status Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final s = await StationPickerModal.show(context,
                          title: I18n.t(context, "board_station"));
                      if (s != null) {
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
              child: currentList.isEmpty && !_isLoading
                  ? Center(
                      child: Text(
                        I18n.t(context, "board_no_departures"),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: currentList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = currentList[i];
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
      leading: SizedBox(
        width: 50,
        child: Center(
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
}

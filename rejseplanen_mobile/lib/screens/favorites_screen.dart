import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/station.dart';
import '../i18n/translations.dart';
import 'board_screen.dart';
import 'trip_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(I18n.t(context, "fav_title"), style: const TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            tabs: [
              Tab(text: I18n.t(context, "fav_stations_title")),
              Tab(text: I18n.t(context, "fav_trips_title")),
              Tab(text: I18n.t(context, "fav_history_title")),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Favorite stations
            _buildStationsList(context, config),
            // Tab 2: Favorite trips
            _buildTripsList(context, config),
            // Tab 3: History
            _buildHistoryList(context, config),
          ],
        ),
      ),
    );
  }

  Widget _buildStationsList(BuildContext context, AppConfig config) {
    if (config.favoriteStations.isEmpty) {
      return Center(
        child: Text(
          I18n.t(context, "fav_empty"),
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      itemCount: config.favoriteStations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final station = config.favoriteStations[i];
        return ListTile(
          leading: const Icon(Icons.star, color: Colors.amber),
          title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text("ID: ${station.id}"),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () => config.removeFavoriteStation(station.id),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BoardScreen(initialStation: station)),
            );
          },
        );
      },
    );
  }

  Widget _buildTripsList(BuildContext context, AppConfig config) {
    if (config.favoriteTrips.isEmpty) {
      return Center(
        child: Text(
          I18n.t(context, "fav_empty"),
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      itemCount: config.favoriteTrips.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final trip = config.favoriteTrips[i];
        final orig = trip['origin']!;
        final dest = trip['dest']!;

        return ListTile(
          leading: const Icon(Icons.route, color: Colors.blue),
          title: Text("${orig.name} → ${dest.name}", style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () => config.removeFavoriteTrip(i),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TripScreen(initialOrigin: orig, initialDest: dest),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryList(BuildContext context, AppConfig config) {
    if (config.recentStations.isEmpty) {
      return Center(
        child: Text(
          I18n.t(context, "fav_history_empty"),
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.clear_all, size: 18),
                label: Text(I18n.t(context, "fav_clear_history")),
                onPressed: () => config.clearRecentStations(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: config.recentStations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final station = config.recentStations[i];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.blueGrey),
                title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  station.desc ?? (station.distance != null ? "${station.distance} m" : "ID: ${station.id}"),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                  onPressed: () => config.removeRecentStation(station.id),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BoardScreen(initialStation: station),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

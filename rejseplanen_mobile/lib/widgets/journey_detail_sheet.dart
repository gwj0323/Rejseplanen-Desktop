import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/departure.dart';
import '../models/trip.dart';
import '../config/app_config.dart';
import '../services/api_client.dart';
import '../i18n/translations.dart';
import 'transit_badge.dart';

class JourneyDetailSheet extends StatefulWidget {
  final Departure departure;
  final String? currentStation;

  const JourneyDetailSheet({
    super.key,
    required this.departure,
    this.currentStation,
  });

  static Future<void> show(
    BuildContext context, {
    required Departure departure,
    String? currentStation,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JourneyDetailSheet(
        departure: departure,
        currentStation: currentStation,
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  State<JourneyDetailSheet> createState() => _JourneyDetailSheetState();
}

class _JourneyDetailSheetState extends State<JourneyDetailSheet> {
  List<TripStop>? _stops;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJourneyDetail();
  }

  Future<void> _loadJourneyDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final config = Provider.of<AppConfig>(context, listen: false);
    final client = RejseplanenApiClient(config);

    final res = await client.getJourneyDetail(
      widget.departure.journeyDetailRef ?? '',
      legName: widget.departure.name,
      originName: widget.currentStation ?? widget.departure.stop,
      destName: widget.departure.direction,
      timeStr: widget.departure.time,
      dateStr: widget.departure.date,
    );

    if (mounted) {
      setState(() {
        _stops = res.data;
        _loading = false;
        _error = res.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dep = widget.departure;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                TransitBadge(text: dep.name, typeCode: dep.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${dep.name} ➔ ${dep.direction}",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            "${dep.time} ${dep.track != '-' ? '(${I18n.t(context, 'trip_platform')} ${dep.track})' : ''}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          if (dep.isDelayed) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "+${dep.delay} min",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content: Stops Timeline
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_stops == null || _stops!.isEmpty)
                    ? Center(
                        child: Text(
                          I18n.t(context, "trip_no_stops"),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: _stops!.length,
                        itemBuilder: (ctx, idx) {
                          final stop = _stops![idx];
                          final isFirst = idx == 0;
                          final isLast = idx == _stops!.length - 1;
                          final isTerminal = isFirst || isLast;
                          final isCurrent = widget.currentStation != null &&
                              stop.name.toLowerCase().contains(widget.currentStation!.toLowerCase());
                          final hasDelay = stop.rtTime.isNotEmpty && stop.rtTime != stop.time;

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Time Column
                                SizedBox(
                                  width: 48,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        stop.time,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isTerminal || isCurrent ? FontWeight.bold : FontWeight.w500,
                                          color: isTerminal || isCurrent
                                              ? theme.colorScheme.onSurface
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Timeline Indicator Column
                                SizedBox(
                                  width: 24,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: isFirst
                                            ? const SizedBox()
                                            : Center(child: Container(width: 2, color: Colors.grey.shade300)),
                                      ),
                                      Container(
                                        width: isCurrent ? 14 : (isTerminal ? 12 : 9),
                                        height: isCurrent ? 14 : (isTerminal ? 12 : 9),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isCurrent
                                              ? Colors.green.shade600
                                              : (isTerminal ? theme.colorScheme.primary : Colors.grey.shade400),
                                          border: isTerminal || isCurrent
                                              ? Border.all(color: Colors.white, width: 2)
                                              : null,
                                        ),
                                      ),
                                      Expanded(
                                        child: isLast
                                            ? const SizedBox()
                                            : Center(child: Container(width: 2, color: Colors.grey.shade300)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Station Name & Details
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            stop.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isCurrent || isTerminal
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isCurrent
                                                  ? Colors.green.shade800
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        if (isCurrent) ...[
                                          Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              I18n.t(context, "journey_detail_current_stop"),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (hasDelay)
                                          Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              stop.rtTime,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                        if (stop.track.isNotEmpty && stop.track != '-')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "${I18n.t(context, 'trip_platform')} ${stop.track}",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey.shade800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

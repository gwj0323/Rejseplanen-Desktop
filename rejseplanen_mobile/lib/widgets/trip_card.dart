import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../models/station.dart';
import '../config/app_config.dart';
import '../i18n/translations.dart';
import 'transit_badge.dart';
import 'trip_reminder_sheet.dart';
import '../services/calendar_service.dart';
import '../services/notification_service.dart';
import '../services/api_client.dart';
import 'package:permission_handler/permission_handler.dart';

class TripCard extends StatefulWidget {
  final TripProposal trip;
  final Station origin;
  final Station destination;

  const TripCard({
    super.key,
    required this.trip,
    required this.origin,
    required this.destination,
  });

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  bool _expanded = false;
  final Set<int> _expandedLegs = {};
  final Map<int, List<TripStop>> _legStopsCache = {};
  final Set<int> _loadingLegs = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trip = widget.trip;
    final config = Provider.of<AppConfig>(context);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Times, Duration, Transfers
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    trip.depTime,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.0),
                    child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  ),
                  Text(
                    trip.arrTime,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Duration chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${trip.durationMin} min",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Changes count
                  Text(
                    trip.changes == 0
                        ? I18n.t(context, "trip_direct")
                        : "${trip.changes} ${I18n.t(context, "trip_changes")}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (config.isTripReminderActive(trip.idx)) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active, size: 11, color: Colors.green.shade700),
                          const SizedBox(width: 3),
                          Text(
                            I18n.t(context, "trip_reminder_active"),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (config.isOngoingTripActive(trip.idx)) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radar, size: 11, color: Colors.blue.shade700),
                          const SizedBox(width: 3),
                          Text(
                            I18n.t(context, "trip_ongoing_active"),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Badges row for all transit legs
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (int i = 0; i < trip.legs.length; i++) ...[
                    if (trip.legs[i].isWalk)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 2),
                          Text(
                            I18n.t(context, "trip_walk"),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      )
                    else
                      TransitBadge(
                        text: trip.legs[i].name,
                        typeCode: trip.legs[i].type,
                      ),
                    if (i < trip.legs.length - 1)
                      Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                  ],
                ],
              ),

              // Expandable Detail Timeline
              if (_expanded) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1),
                ),
                Text(
                  I18n.t(context, "trip_step_by_step"),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < trip.legs.length; i++)
                  _buildLegDetail(context, trip.legs[i], i),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // 1. Live Ongoing Trip Tracker
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: config.isOngoingTripActive(trip.idx)
                            ? Colors.blue.withOpacity(0.18)
                            : theme.colorScheme.secondaryContainer.withOpacity(0.55),
                        foregroundColor: config.isOngoingTripActive(trip.idx)
                            ? Colors.blue.shade900
                            : theme.colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: Icon(
                        config.isOngoingTripActive(trip.idx) ? Icons.radar : Icons.radar_outlined,
                        size: 17,
                      ),
                      label: Text(
                        config.isOngoingTripActive(trip.idx)
                            ? I18n.t(context, "trip_ongoing_stop")
                            : I18n.t(context, "trip_ongoing_start"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () async {
                        if (config.isOngoingTripActive(trip.idx)) {
                          await NotificationService().stopOngoingTripNotification();
                          config.stopOngoingTrip();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(I18n.t(context, "trip_ongoing_stopped_snack"))),
                            );
                          }
                        } else {
                          config.startOngoingTrip(widget.trip, widget.origin, widget.destination);
                          await NotificationService().showOngoingTripNotification(
                            trip: widget.trip,
                            origin: widget.origin,
                            destination: widget.destination,
                            lang: config.effectiveLanguage,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(I18n.t(context, "trip_ongoing_started_snack"))),
                            );
                          }
                        }
                      },
                    ),

                    // 2. Scheduled Trip Reminders
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: config.isTripReminderActive(trip.idx)
                            ? Colors.green.withOpacity(0.15)
                            : theme.colorScheme.primaryContainer.withOpacity(0.5),
                        foregroundColor: config.isTripReminderActive(trip.idx)
                            ? Colors.green.shade800
                            : theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: Icon(
                        config.isTripReminderActive(trip.idx)
                            ? Icons.notifications_active
                            : Icons.notifications_outlined,
                        size: 17,
                      ),
                      label: Text(
                        config.isTripReminderActive(trip.idx)
                            ? I18n.t(context, "trip_reminder_active")
                            : I18n.t(context, "trip_reminder_btn"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () {
                        TripReminderSheet.show(
                          context,
                          trip: widget.trip,
                          origin: widget.origin,
                          destination: widget.destination,
                        );
                      },
                    ),

                    // 3. Add to Calendar
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.calendar_month_outlined, size: 17),
                      label: Text(
                        I18n.t(context, "trip_add_calendar"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () async {
                        final ok = await CalendarService.addTripToCalendar(
                          trip: widget.trip,
                          origin: widget.origin,
                          destination: widget.destination,
                          lang: config.effectiveLanguage,
                        );
                        if (context.mounted) {
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(I18n.t(context, "trip_calendar_success")),
                              ),
                            );
                          } else {
                            final permDenied = await CalendarService.isPermanentlyDenied();
                            if (context.mounted) {
                              if (permDenied) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, color: Colors.amber),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(I18n.t(ctx, "trip_calendar_perm_title"))),
                                      ],
                                    ),
                                    content: Text(I18n.t(ctx, "trip_calendar_perm_body")),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(I18n.t(ctx, "common_cancel")),
                                      ),
                                      FilledButton.icon(
                                        icon: const Icon(Icons.settings, size: 16),
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await openAppSettings();
                                        },
                                        label: Text(I18n.t(ctx, "trip_calendar_open_settings")),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(I18n.t(context, "trip_calendar_error")),
                                  ),
                                );
                              }
                            }
                          }
                        }
                      },
                    ),

                    // 4. Save to Favorites
                    TextButton.icon(
                      icon: const Icon(Icons.star_border, size: 17),
                      label: Text(
                        I18n.t(context, "trip_save_fav"),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        config.addFavoriteTrip(widget.origin, widget.destination);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(I18n.t(context, "saved_to_fav")),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegDetail(BuildContext context, TripLeg leg, int legIdx) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!leg.isWalk)
                TransitBadge(text: leg.name, typeCode: leg.type)
              else
                Icon(Icons.directions_walk, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              if (leg.direction.isNotEmpty)
                Expanded(
                  child: Text(
                    "${I18n.t(context, "board_col_dir")}: ${leg.direction}",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Boarding
          Row(
            children: [
              Text(
                leg.origin.time,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  leg.origin.name,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (leg.origin.track.isNotEmpty && leg.origin.track != "-")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${I18n.t(context, "trip_platform")} ${leg.origin.track}",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Arrival
          Row(
            children: [
              Text(
                leg.destination.time,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  leg.destination.name,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (leg.destination.track.isNotEmpty && leg.destination.track != "-")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${I18n.t(context, "trip_platform")} ${leg.destination.track}",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (leg.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              leg.notes,
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
            ),
          ],
          // Intermediate Stops Section (journeyDetail)
          if (!leg.isWalk) ...[
            const SizedBox(height: 8),
            _buildStopsExpander(context, leg, legIdx),
          ],
        ],
      ),
    );
  }

  Widget _buildStopsExpander(BuildContext context, TripLeg leg, int legIdx) {
    final theme = Theme.of(context);
    final isExpanded = _expandedLegs.contains(legIdx);
    final isLoading = _loadingLegs.contains(legIdx);
    final stops = _legStopsCache[legIdx] ?? leg.stops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            if (isExpanded) {
              setState(() => _expandedLegs.remove(legIdx));
            } else {
              setState(() => _expandedLegs.add(legIdx));
              if (!_legStopsCache.containsKey(legIdx)) {
                if (leg.stops != null && leg.stops!.isNotEmpty) {
                  setState(() => _legStopsCache[legIdx] = leg.stops!);
                } else {
                  setState(() => _loadingLegs.add(legIdx));
                  final client = RejseplanenApiClient(Provider.of<AppConfig>(context, listen: false));
                  final res = await client.getJourneyDetail(
                    leg.journeyDetailRef ?? '',
                    legName: leg.name,
                    originName: leg.origin.name,
                    destName: leg.destination.name,
                    timeStr: leg.origin.time,
                    dateStr: leg.origin.date,
                  );
                  if (mounted) {
                    setState(() {
                      _legStopsCache[legIdx] = res.data;
                      _loadingLegs.remove(legIdx);
                    });
                  }
                }
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  isExpanded
                      ? I18n.t(context, "trip_hide_stops")
                      : (stops != null && stops.isNotEmpty
                          ? "${I18n.t(context, 'trip_view_stops')} (${stops.length})"
                          : I18n.t(context, "trip_view_stops")),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    I18n.t(context, "trip_loading_stops"),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else if (stops != null && stops.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.12)),
              ),
              child: Column(
                children: [
                  for (int sIdx = 0; sIdx < stops.length; sIdx++)
                    _buildStopTimelineRow(
                      context,
                      stops[sIdx],
                      isFirst: sIdx == 0,
                      isLast: sIdx == stops.length - 1,
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStopTimelineRow(
    BuildContext context,
    TripStop stop, {
    required bool isFirst,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final isTerminal = isFirst || isLast;
    final hasDelay = stop.rtTime.isNotEmpty && stop.rtTime != stop.time;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              stop.time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isTerminal ? FontWeight.bold : FontWeight.w500,
                color: isTerminal ? theme.colorScheme.onSurface : Colors.grey.shade600,
              ),
            ),
          ),
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Expanded(
                  child: isFirst
                      ? const SizedBox()
                      : Center(child: Container(width: 1.5, color: Colors.grey.shade300)),
                ),
                Container(
                  width: isTerminal ? 9 : 6,
                  height: isTerminal ? 9 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isTerminal ? theme.colorScheme.primary : Colors.grey.shade400,
                    border: isTerminal ? Border.all(color: Colors.white, width: 1.5) : null,
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox()
                      : Center(child: Container(width: 1.5, color: Colors.grey.shade300)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      stop.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isTerminal ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasDelay)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        stop.rtTime,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                      ),
                    ),
                  if (stop.track.isNotEmpty && stop.track != '-')
                    Text(
                      "Spor ${stop.track}",
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

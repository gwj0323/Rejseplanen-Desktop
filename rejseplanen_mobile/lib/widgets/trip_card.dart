import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../models/station.dart';
import '../config/app_config.dart';
import '../i18n/translations.dart';
import 'transit_badge.dart';

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
                for (var leg in trip.legs) _buildLegDetail(context, leg),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.star_border, size: 18),
                      label: Text(I18n.t(context, "trip_save_fav")),
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

  Widget _buildLegDetail(BuildContext context, TripLeg leg) {
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
        ],
      ),
    );
  }
}

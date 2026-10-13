import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../models/station.dart';
import '../config/app_config.dart';
import '../i18n/translations.dart';
import '../services/notification_service.dart';

class TripReminderSheet extends StatefulWidget {
  final TripProposal trip;
  final Station origin;
  final Station destination;

  const TripReminderSheet({
    super.key,
    required this.trip,
    required this.origin,
    required this.destination,
  });

  static Future<void> show(BuildContext context, {
    required TripProposal trip,
    required Station origin,
    required Station destination,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripReminderSheet(
        trip: trip,
        origin: origin,
        destination: destination,
      ),
    );
  }

  @override
  State<TripReminderSheet> createState() => _TripReminderSheetState();
}

class _TripReminderSheetState extends State<TripReminderSheet> {
  bool _enableDep = true;
  int _depMinutes = 10;

  bool _enableTransfer = true;

  bool _enableArr = true;
  int _arrMinutes = 5;

  bool _testing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = Provider.of<AppConfig>(context);
    final isAlreadyActive = config.isTripReminderActive(widget.trip.idx);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.notifications_active, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        I18n.t(context, "trip_reminder_sheet_title"),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${widget.origin.name} ➔ ${widget.destination.name} (${widget.trip.depTime} - ${widget.trip.arrTime})",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (isAlreadyActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          I18n.t(context, "trip_reminder_active"),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Card 1: Departure Reminder (出发提醒)
            _buildReminderCard(
              context: context,
              icon: Icons.directions_transit,
              iconColor: theme.colorScheme.primary,
              title: I18n.t(context, "reminder_dep_title"),
              subtitle: I18n.t(context, "reminder_dep_desc"),
              enabled: _enableDep,
              onToggle: (v) => setState(() => _enableDep = v),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [5, 10, 15].map((mins) {
                      final selected = _depMinutes == mins;
                      return ChoiceChip(
                        label: Text(I18n.t(context, "reminder_min_$mins")),
                        selected: selected,
                        onSelected: (val) {
                          if (val) setState(() => _depMinutes = mins);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "预览：预计将在发车前 $_depMinutes 分钟提醒前往站台乘车",
                            style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 2: Transfer Reminder (换乘提醒 - 仅当有换乘时展示)
            if (widget.trip.changes > 0) ...[
              _buildReminderCard(
                context: context,
                icon: Icons.transfer_within_a_station,
                iconColor: Colors.deepOrange,
                title: "${I18n.t(context, "reminder_transfer_title")} (${widget.trip.changes} 次换乘)",
                subtitle: I18n.t(context, "reminder_transfer_desc"),
                enabled: _enableTransfer,
                onToggle: (v) => setState(() => _enableTransfer = v),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 16, color: Colors.deepOrange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "到达中转站前 5 分钟提醒换乘并提示下一程车次及站台",
                          style: TextStyle(fontSize: 11, color: Colors.deepOrange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Card 3: Arrival / Get-off Reminder (下车提醒)
            _buildReminderCard(
              context: context,
              icon: Icons.pin_drop,
              iconColor: Colors.teal,
              title: I18n.t(context, "reminder_arr_title"),
              subtitle: I18n.t(context, "reminder_arr_desc"),
              enabled: _enableArr,
              onToggle: (v) => setState(() => _enableArr = v),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [3, 5, 10].map((mins) {
                      final selected = _arrMinutes == mins;
                      return ChoiceChip(
                        label: Text(I18n.t(context, "reminder_min_$mins")),
                        selected: selected,
                        onSelected: (val) {
                          if (val) setState(() => _arrMinutes = mins);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: Colors.teal),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "到达终点站 ${widget.destination.name} 前 $_arrMinutes 分钟提醒收拾行李下车",
                            style: TextStyle(fontSize: 11, color: Colors.teal.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bottom Action Buttons
            Row(
              children: [
                // Test Notification Button
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _testing ? null : _handleTestNotification,
                    icon: _testing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(I18n.t(context, "reminder_test_btn")),
                  ),
                ),
                const SizedBox(width: 12),

                // Enable Reminders Button
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _handleConfirmReminders(config),
                    icon: const Icon(Icons.notifications_active, size: 18),
                    label: Text(I18n.t(context, "reminder_enable_btn")),
                  ),
                ),
              ],
            ),

            if (isAlreadyActive) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  icon: const Icon(Icons.notifications_off_outlined, size: 18),
                  label: Text(I18n.t(context, "reminder_cancel_btn")),
                  onPressed: () => _handleCancelReminders(config),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required Widget child,
  }) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: enabled ? iconColor.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: iconColor,
                ),
              ],
            ),
            if (enabled) ...[
              const Divider(height: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleTestNotification() async {
    setState(() => _testing = true);
    final notificationService = NotificationService();
    await notificationService.showInstantNotification(
      id: 999,
      title: I18n.t(context, "reminder_test_title"),
      body: I18n.t(context, "reminder_test_body"),
    );
    if (mounted) {
      setState(() => _testing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.t(context, "reminder_test_sent")),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleConfirmReminders(AppConfig config) async {
    final notificationService = NotificationService();
    await notificationService.scheduleTripReminders(
      trip: widget.trip,
      origin: widget.origin,
      destination: widget.destination,
      enableDeparture: _enableDep,
      depAdvanceMinutes: _depMinutes,
      enableTransfer: _enableTransfer,
      enableArrival: _enableArr,
      arrAdvanceMinutes: _arrMinutes,
    );

    config.setTripReminderActive(widget.trip.idx, true);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(I18n.t(context, "reminder_enabled_snack"))),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleCancelReminders(AppConfig config) async {
    final notificationService = NotificationService();
    await notificationService.cancelTripReminders(widget.trip);
    config.setTripReminderActive(widget.trip.idx, false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.t(context, "reminder_cancelled_snack")),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

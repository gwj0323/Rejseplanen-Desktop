import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
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

class _TripReminderSheetState extends State<TripReminderSheet> with WidgetsBindingObserver {
  bool _enableDep = true;
  int _depMinutes = 10;

  bool _enableTransfer = true;

  bool _enableArr = true;
  int _arrMinutes = 5;

  bool _enableOngoingCard = true;

  bool _testing = false;
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    // Prompt for notification permission as soon as user opens reminder sheet
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final enabled = await NotificationService().areNotificationsEnabled();
      if (!enabled) {
        await NotificationService().requestPermission();
        _checkPermission();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _hasPermission = enabled;
      });
    }
  }

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

            // Notification Permission Warning Banner (if permission is not granted)
            if (!_hasPermission) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            I18n.t(context, "reminder_perm_banner_title"),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            I18n.t(context, "reminder_perm_banner_desc"),
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.amber.shade200,
                        foregroundColor: Colors.amber.shade900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final granted = await NotificationService().requestPermission();
                        if (!granted) {
                          await Geolocator.openAppSettings();
                        }
                        _checkPermission();
                      },
                      child: Text(
                        I18n.t(context, "reminder_perm_enable_btn"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                            I18n.t(context, "reminder_dep_preview", {"mins": "$_depMinutes"}),
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
                title: "${I18n.t(context, "reminder_transfer_title")} (${I18n.t(context, "reminder_transfer_count", {"count": "${widget.trip.changes}"})})",
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
                          I18n.t(context, "reminder_transfer_preview"),
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
                            I18n.t(context, "reminder_arr_preview", {
                              "station": widget.destination.name,
                              "mins": "$_arrMinutes",
                            }),
                            style: TextStyle(fontSize: 11, color: Colors.teal.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 4: Ongoing Trip Live Notification Card (行程常驻后台动态卡片)
            _buildReminderCard(
              context: context,
              icon: Icons.radar,
              iconColor: Colors.blue.shade700,
              title: I18n.t(context, "trip_ongoing_start"),
              subtitle: I18n.t(context, "trip_ongoing_banner_desc"),
              enabled: _enableOngoingCard,
              onToggle: (v) => setState(() => _enableOngoingCard = v),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        I18n.t(context, "trip_ongoing_banner_desc"),
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
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

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_off, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(I18n.t(ctx, "reminder_perm_dialog_title"))),
          ],
        ),
        content: Text(I18n.t(ctx, "reminder_perm_dialog_body")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(I18n.t(ctx, "common_cancel")),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.settings, size: 16),
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openAppSettings();
            },
            label: Text(I18n.t(ctx, "reminder_perm_open_settings")),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTestNotification() async {
    setState(() => _testing = true);
    final notificationService = NotificationService();

    // 1. Verify or prompt permission first
    bool granted = await notificationService.areNotificationsEnabled();
    if (!granted) {
      granted = await notificationService.requestPermission();
    }
    await _checkPermission();

    if (!granted) {
      if (mounted) {
        setState(() => _testing = false);
        _showPermissionDialog();
      }
      return;
    }

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

    // Verify or prompt permission first
    bool granted = await notificationService.areNotificationsEnabled();
    if (!granted) {
      granted = await notificationService.requestPermission();
    }
    await _checkPermission();

    if (!granted) {
      if (mounted) {
        _showPermissionDialog();
      }
      return;
    }

    await notificationService.scheduleTripReminders(
      trip: widget.trip,
      origin: widget.origin,
      destination: widget.destination,
      enableDeparture: _enableDep,
      depAdvanceMinutes: _depMinutes,
      enableTransfer: _enableTransfer,
      enableArrival: _enableArr,
      arrAdvanceMinutes: _arrMinutes,
      lang: config.effectiveLanguage,
    );

    config.setTripReminderActive(widget.trip.idx, true);

    if (_enableOngoingCard) {
      config.startOngoingTrip(widget.trip, widget.origin, widget.destination);
      await notificationService.showOngoingTripNotification(
        trip: widget.trip,
        origin: widget.origin,
        destination: widget.destination,
        lang: config.effectiveLanguage,
      );
    }

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

    if (config.isOngoingTripActive(widget.trip.idx)) {
      await notificationService.stopOngoingTripNotification();
      config.stopOngoingTrip();
    }

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

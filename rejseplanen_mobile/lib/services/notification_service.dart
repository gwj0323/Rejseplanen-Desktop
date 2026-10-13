import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/trip.dart';
import '../models/station.dart';
import '../i18n/translations.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String channelId = 'rejseplanen_trip_reminders';
  static const String channelName = '行程提醒 (Trip Reminders)';
  static const String channelDescription = '出发提醒、换乘提醒和下车提醒通知';

  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize timezone database
    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Copenhagen'));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (e) {
      debugPrint('[NotificationService] Timezone init error: $e');
    }

    // 2. Android initialization settings - use standard @mipmap/ic_launcher
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[NotificationService] User tapped notification: ${response.payload}');
        },
      );

      // 3. Create high-importance notification channel on Android
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await androidPlugin.createNotificationChannel(channel);
      }

      _initialized = true;
      debugPrint('[NotificationService] Initialized successfully');
    } catch (e) {
      debugPrint('[NotificationService] Init error: $e');
    }
  }

  /// Check whether notifications are currently enabled in the system
  Future<bool> areNotificationsEnabled() async {
    await init();
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return (await androidPlugin.areNotificationsEnabled()) ?? false;
      }
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request runtime notification permission on Android 13+
  Future<bool> requestPermission() async {
    await init();
    try {
      // 1. Request via permission_handler (pops up native Android OS dialog)
      final status = await Permission.notification.request();
      debugPrint('[NotificationService] Permission.notification.request() status: $status');
      if (status.isGranted) return true;

      // 2. Fallback to flutter_local_notifications plugin request
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final bool? granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('[NotificationService] requestNotificationsPermission result: $granted');
        if (granted == true) return true;
        return (await androidPlugin.areNotificationsEnabled()) ?? false;
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('[NotificationService] Request permission error: $e');
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return (await androidPlugin?.areNotificationsEnabled()) ?? false;
    }
  }

  /// Show an immediate notification (e.g. for user testing or immediate alert)
  Future<void> showInstantNotification({
    int id = 999,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails details = NotificationDetails(android: androidDetails);
      await _notificationsPlugin.show(id, title, body, details, payload: payload);
      debugPrint('[NotificationService] Shown instant notification: $title');
    } catch (e) {
      debugPrint('[NotificationService] Show notification error: $e');
    }
  }

  /// Parse time string like "14:35" into a DateTime for today or tomorrow
  DateTime _parseTripDateTime(String timeStr, DateTime baseDate) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        DateTime dt = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
        // If time is significantly earlier than now (e.g. crossing midnight into next day)
        if (dt.isBefore(baseDate.subtract(const Duration(hours: 4)))) {
          dt = dt.add(const Duration(days: 1));
        }
        return dt;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error parsing time $timeStr: $e');
    }
    return baseDate;
  }

  /// Schedule trip reminders for departure, transfers, and arrival
  Future<List<Map<String, dynamic>>> scheduleTripReminders({
    required TripProposal trip,
    required Station origin,
    required Station destination,
    bool enableDeparture = true,
    int depAdvanceMinutes = 10,
    bool enableTransfer = true,
    bool enableArrival = true,
    int arrAdvanceMinutes = 5,
    String lang = 'en_US',
  }) async {
    await init();
    await requestPermission();

    final List<Map<String, dynamic>> scheduledReminders = [];
    final DateTime now = DateTime.now();

    // 1. Departure Reminder (出发提醒)
    if (enableDeparture && trip.depTime.isNotEmpty) {
      final depDateTime = _parseTripDateTime(trip.depTime, now);
      final triggerTime = depDateTime.subtract(Duration(minutes: depAdvanceMinutes));
      final int depId = (trip.idx.hashCode + 101).abs() % 100000;

      final firstLegName = trip.legs.isNotEmpty ? trip.legs.first.name : I18n.tr('notif_transit_fallback', lang);
      final platform = trip.legs.isNotEmpty && trip.legs.first.origin.track.isNotEmpty && trip.legs.first.origin.track != '-'
          ? I18n.tr('notif_track_suffix', lang, {'track': trip.legs.first.origin.track})
          : '';

      final title = I18n.tr('notif_dep_title', lang, {'line': firstLegName});
      final body = I18n.tr('notif_dep_body', lang, {
        'time': trip.depTime,
        'origin': origin.name,
        'dest': destination.name,
        'track': platform,
      });

      if (triggerTime.isAfter(now)) {
        await _scheduleSingle(depId, title, body, triggerTime, 'dep');
        scheduledReminders.add({
          'type': 'departure',
          'id': depId,
          'time': triggerTime,
          'title': title,
          'body': body,
        });
      } else {
        // If already passed or departing right now, send immediate notification
        await showInstantNotification(id: depId, title: title, body: body);
        scheduledReminders.add({
          'type': 'departure_now',
          'id': depId,
          'time': now,
          'title': title,
          'body': body,
        });
      }
    }

    // 2. Transfer Reminders (换乘提醒)
    if (enableTransfer && trip.legs.length > 1) {
      for (int i = 0; i < trip.legs.length - 1; i++) {
        final currentLeg = trip.legs[i];
        final nextLeg = trip.legs[i + 1];

        if (currentLeg.destination.time.isEmpty) continue;

        final transferArrTime = _parseTripDateTime(currentLeg.destination.time, now);
        // Remind 5 minutes before arriving at transfer station
        final triggerTime = transferArrTime.subtract(const Duration(minutes: 5));
        final int transferId = (trip.idx.hashCode + 200 + i).abs() % 100000;

        final nextPlatform = nextLeg.origin.track.isNotEmpty && nextLeg.origin.track != '-'
            ? I18n.tr('notif_track_suffix', lang, {'track': nextLeg.origin.track})
            : '';

        final title = I18n.tr('notif_transfer_title', lang, {'station': currentLeg.destination.name});
        final body = I18n.tr('notif_transfer_body', lang, {
          'arrTime': currentLeg.destination.time,
          'station': currentLeg.destination.name,
          'nextLine': nextLeg.name,
          'nextTrack': nextPlatform,
          'depTime': nextLeg.origin.time,
        });

        if (triggerTime.isAfter(now)) {
          await _scheduleSingle(transferId, title, body, triggerTime, 'transfer_$i');
          scheduledReminders.add({
            'type': 'transfer',
            'id': transferId,
            'time': triggerTime,
            'title': title,
            'body': body,
          });
        }
      }
    }

    // 3. Arrival Reminder (下车提醒)
    if (enableArrival && trip.arrTime.isNotEmpty) {
      final arrDateTime = _parseTripDateTime(trip.arrTime, now);
      final triggerTime = arrDateTime.subtract(Duration(minutes: arrAdvanceMinutes));
      final int arrId = (trip.idx.hashCode + 301).abs() % 100000;

      final title = I18n.tr('notif_arr_title', lang, {'station': destination.name});
      final body = I18n.tr('notif_arr_body', lang, {
        'time': trip.arrTime,
        'station': destination.name,
      });

      if (triggerTime.isAfter(now)) {
        await _scheduleSingle(arrId, title, body, triggerTime, 'arr');
        scheduledReminders.add({
          'type': 'arrival',
          'id': arrId,
          'time': triggerTime,
          'title': title,
          'body': body,
        });
      }
    }

    return scheduledReminders;
  }

  Future<void> _scheduleSingle(int id, String title, String body, DateTime triggerTime, String payload) async {
    try {
      final tz.TZDateTime tzTime = tz.TZDateTime.from(triggerTime, tz.local);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[NotificationService] Scheduled notification $id at $tzTime');
    } catch (e) {
      debugPrint('[NotificationService] Error scheduling notification $id: $e');
    }
  }

  /// Cancel all reminders for a given trip proposal
  Future<void> cancelTripReminders(TripProposal trip) async {
    try {
      final int depId = (trip.idx.hashCode + 101).abs() % 100000;
      final int arrId = (trip.idx.hashCode + 301).abs() % 100000;
      await _notificationsPlugin.cancel(depId);
      await _notificationsPlugin.cancel(arrId);

      for (int i = 0; i < trip.legs.length; i++) {
        final int transferId = (trip.idx.hashCode + 200 + i).abs() % 100000;
        await _notificationsPlugin.cancel(transferId);
      }
      debugPrint('[NotificationService] Cancelled reminders for trip ${trip.idx}');
    } catch (e) {
      debugPrint('[NotificationService] Error cancelling reminders: $e');
    }
  }

  /// Cancel all pending notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}

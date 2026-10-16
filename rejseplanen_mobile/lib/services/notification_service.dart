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

  static const String channelId = 'spor_trip_reminders';
  static const String channelName = '行程提醒 (Trip Reminders)';
  static const String channelDescription = '出发提醒、换乘提醒和下车提醒通知';

  static const String ongoingChannelId = 'spor_ongoing_trip';
  static const String ongoingChannelName = '实时行程动态 (Live Trip Tracker)';
  static const String ongoingChannelDescription = '在通知栏实时展示正在进行的行程状态与到站提醒';
  static const int ongoingNotificationId = 8888;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize timezone database
    try {
      tz.initializeTimeZones();
      final String timeZoneName = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.getLocation('Europe/Copenhagen'));
        } catch (_) {
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
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

        const AndroidNotificationChannel ongoingChannel = AndroidNotificationChannel(
          ongoingChannelId,
          ongoingChannelName,
          description: ongoingChannelDescription,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );
        await androidPlugin.createNotificationChannel(ongoingChannel);
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
      if (status.isGranted || status.isLimited || status.isProvisional) return true;

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        if (enabled == true) return true;
      }

      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request runtime notification permission on Android 13+ and iOS
  Future<bool> requestPermission() async {
    await init();
    try {
      bool granted = false;

      // 1. Explicitly request permissions via IOSFlutterLocalNotificationsPlugin on iOS
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final bool? iosGranted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('[NotificationService] iOS requestPermissions result: $iosGranted');
        if (iosGranted == true) granted = true;
      }

      // 2. Request via permission_handler (works across platforms with PERMISSION_NOTIFICATIONS=1)
      try {
        final status = await Permission.notification.request();
        debugPrint('[NotificationService] Permission.notification.request() status: $status');
        if (status.isGranted || status.isLimited || status.isProvisional) granted = true;
      } catch (e) {
        debugPrint('[NotificationService] Permission.notification.request error: $e');
      }

      // 3. Request notification & exact alarms via flutter_local_notifications plugin on Android
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        try {
          await androidPlugin.requestExactAlarmsPermission();
        } catch (_) {}
        final bool? androidEnabled = await androidPlugin.areNotificationsEnabled();
        if (androidEnabled == true) granted = true;
      }

      return granted || await areNotificationsEnabled();
    } catch (e) {
      debugPrint('[NotificationService] Request permission error: $e');
      return await areNotificationsEnabled();
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
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _notificationsPlugin.show(id, title, body, details, payload: payload);
      debugPrint('[NotificationService] Shown instant notification: $title');
    } catch (e) {
      debugPrint('[NotificationService] Show notification error: $e');
    }
  }

  /// Parse time string like "14:35" into a DateTime for today or tomorrow
  DateTime _parseTripDateTime(String timeStr, DateTime baseDate, {bool hasExplicitDate = false}) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        DateTime dt = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
        // Only guess about crossing midnight when no explicit trip date is known.
        if (!hasExplicitDate && dt.isBefore(baseDate.subtract(const Duration(hours: 4)))) {
          dt = dt.add(const Duration(days: 1));
        }
        return dt;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error parsing time $timeStr: $e');
    }
    return baseDate;
  }

  /// Parse a HAFAS date ('dd.mm.yy', 'dd.mm.yyyy' or 'yyyy-mm-dd') into a
  /// DateTime, or null when absent/unparseable.
  DateTime? _parseHafasDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final s = dateStr.trim();
    try {
      if (s.contains('-')) {
        final p = s.split('-');
        if (p.length == 3) {
          final y = int.parse(p[0]);
          final m = int.parse(p[1]);
          final d = int.parse(p[2]);
          if (y > 0 && m > 0 && d > 0) return DateTime(y, m, d);
        }
      } else if (s.contains('.')) {
        final p = s.split('.');
        if (p.length == 3) {
          final y = p[2].length == 2 ? int.parse('20${p[2]}') : int.parse(p[2]);
          final m = int.parse(p[1]);
          final d = int.parse(p[0]);
          if (y > 0 && m > 0 && d > 0) return DateTime(y, m, d);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Deterministic 32-bit FNV-1a hash so notification IDs stay stable across
  /// app restarts (Dart's String.hashCode gives no such guarantee) and are
  /// derived from the trip itself instead of the result-list index, which is
  /// only '1'..'N' and collides between different searches.
  int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7FFFFFFF;
    }
    return h;
  }

  int _tripIdBase(TripProposal trip, {Station? origin, Station? destination}) {
    final sig = StringBuffer()
      ..write(trip.depTime)
      ..write('|')
      ..write(trip.arrTime);
    if (origin != null) {
      sig.write('|');
      sig.write(origin.name);
    }
    if (destination != null) {
      sig.write('|');
      sig.write(destination.name);
    }
    return _stableHash(sig.toString());
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

    // Anchor reminder times to the trip's real date (from the first leg)
    // instead of assuming "today or tomorrow".
    final DateTime? tripDate = _parseHafasDate(
      trip.legs.isNotEmpty ? trip.legs.first.origin.date : null,
    );
    final DateTime baseDate = tripDate ?? now;
    final bool hasExplicitDate = tripDate != null;
    final int idBase = _tripIdBase(trip, origin: origin, destination: destination);

    // 1. Departure Reminder (出发提醒)
    if (enableDeparture && trip.depTime.isNotEmpty) {
      final depDateTime = _parseTripDateTime(trip.depTime, baseDate, hasExplicitDate: hasExplicitDate);
      final triggerTime = depDateTime.subtract(Duration(minutes: depAdvanceMinutes));
      final int depId = (idBase + 101) % 100000;

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

        final transferDate = _parseHafasDate(currentLeg.destination.date) ?? baseDate;
        final transferArrTime = _parseTripDateTime(
          currentLeg.destination.time,
          transferDate,
          hasExplicitDate: hasExplicitDate || currentLeg.destination.date.isNotEmpty,
        );
        // Remind 5 minutes before arriving at transfer station
        final triggerTime = transferArrTime.subtract(const Duration(minutes: 5));
        final int transferId = (idBase + 200 + i) % 100000;

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
        } else if (transferArrTime.isAfter(now)) {
          // Imminent transfer: within 5 minutes of transfer station
          await showInstantNotification(id: transferId, title: title, body: body, payload: 'transfer_$i');
          scheduledReminders.add({
            'type': 'transfer_now',
            'id': transferId,
            'time': now,
            'title': title,
            'body': body,
          });
        }
      }
    }

    // 3. Arrival Reminder (下车提醒)
    if (enableArrival && trip.arrTime.isNotEmpty) {
      final lastLegDate = trip.legs.isNotEmpty ? _parseHafasDate(trip.legs.last.destination.date) : null;
      final arrBase = lastLegDate ?? baseDate;
      final arrDateTime = _parseTripDateTime(
        trip.arrTime,
        arrBase,
        hasExplicitDate: hasExplicitDate || lastLegDate != null,
      );
      final triggerTime = arrDateTime.subtract(Duration(minutes: arrAdvanceMinutes));
      final int arrId = (idBase + 301) % 100000;

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
      } else if (arrDateTime.isAfter(now)) {
        // Imminent arrival: within advance minutes of arrival, alert immediately
        await showInstantNotification(id: arrId, title: title, body: body, payload: 'arr');
        scheduledReminders.add({
          'type': 'arrival_now',
          'id': arrId,
          'time': now,
          'title': title,
          'body': body,
        });
      }
    }

    return scheduledReminders;
  }

  Future<void> _scheduleSingle(int id, String title, String body, DateTime triggerTime, String payload) async {
    try {
      final durationFromNow = triggerTime.difference(DateTime.now());
      if (durationFromNow.isNegative) {
        debugPrint('[NotificationService] Trigger time $triggerTime is already in the past, firing instant notification');
        await showInstantNotification(id: id, title: title, body: body, payload: payload);
        return;
      }

      // Safe TZDateTime calculated relative to current local time to prevent timezone skew
      final tz.TZDateTime tzTime = tz.TZDateTime.now(tz.local).add(durationFromNow);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 1. Attempt alarmClock schedule first (highest priority on Android, bypasses Doze & OEM freezes)
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        debugPrint('[NotificationService] Scheduled notification $id (alarmClock) at $tzTime (in ${durationFromNow.inMinutes}m ${durationFromNow.inSeconds % 60}s)');
        return;
      } catch (alarmErr) {
        debugPrint('[NotificationService] alarmClock failed ($alarmErr), falling back to exactAllowWhileIdle');
      }

      // 2. Fallback to exactAllowWhileIdle
      try {
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
        debugPrint('[NotificationService] Scheduled notification $id (exactAllowWhileIdle) at $tzTime');
        return;
      } catch (exactErr) {
        debugPrint('[NotificationService] exactAllowWhileIdle failed ($exactErr), falling back to inexactAllowWhileIdle');
      }

      // 3. Fallback to inexactAllowWhileIdle
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[NotificationService] Scheduled notification $id (inexact fallback) at $tzTime');
    } catch (e) {
      debugPrint('[NotificationService] Error scheduling notification $id: $e');
    }
  }

  /// Schedule a 1-tap Arrival / Alighting Alarm (e.g. 5 mins before real-time arrival)
  Future<bool> scheduleQuickArrivalAlarm({
    required TripProposal trip,
    required Station origin,
    required Station destination,
    int advanceMinutes = 5,
    String lang = 'en_US',
  }) async {
    await init();
    await requestPermission();

    final DateTime now = DateTime.now();
    final DateTime? tripDate = _parseHafasDate(
      trip.legs.isNotEmpty ? trip.legs.first.origin.date : null,
    );
    final DateTime baseDate = tripDate ?? now;
    final bool hasExplicitDate = tripDate != null;
    final int idBase = _tripIdBase(trip, origin: origin, destination: destination);
    final int arrId = (idBase + 305) % 100000;

    final String effectiveArrStr = (trip.legs.isNotEmpty &&
            trip.legs.last.destination.rtTime.trim().isNotEmpty)
        ? trip.legs.last.destination.rtTime.trim()
        : trip.arrTime;
    if (effectiveArrStr.isEmpty) return false;

    final lastLegDate =
        trip.legs.isNotEmpty ? _parseHafasDate(trip.legs.last.destination.date) : null;
    final arrBase = lastLegDate ?? baseDate;
    final arrDateTime = _parseTripDateTime(
      effectiveArrStr,
      arrBase,
      hasExplicitDate: hasExplicitDate || lastLegDate != null,
    );
    final triggerTime = arrDateTime.subtract(Duration(minutes: advanceMinutes));

    final title = I18n.tr('notif_arr_title', lang, {'station': destination.name});
    final body = I18n.tr('notif_arr_body', lang, {
      'time': effectiveArrStr,
      'station': destination.name,
    });

    if (triggerTime.isAfter(now)) {
      await _scheduleSingle(arrId, title, body, triggerTime, 'quick_arr');
      return true;
    } else if (arrDateTime.isAfter(now)) {
      await showInstantNotification(id: arrId, title: title, body: body, payload: 'quick_arr');
      return true;
    } else {
      await showInstantNotification(id: arrId, title: title, body: body, payload: 'quick_arr');
      return true;
    }
  }

  /// Cancel the 1-tap Arrival / Alighting Alarm
  Future<void> cancelQuickArrivalAlarm({
    required TripProposal trip,
    required Station origin,
    required Station destination,
  }) async {
    try {
      final int idBase = _tripIdBase(trip, origin: origin, destination: destination);
      final int arrId = (idBase + 305) % 100000;
      await _notificationsPlugin.cancel(arrId);
    } catch (e) {
      debugPrint('[NotificationService] Error cancelling quick arrival alarm: $e');
    }
  }

  /// Cancel all reminders for a given trip proposal
  Future<void> cancelTripReminders(
    TripProposal trip, {
    Station? origin,
    Station? destination,
  }) async {
    try {
      final int idBase = _tripIdBase(trip, origin: origin, destination: destination);
      final int depId = (idBase + 101) % 100000;
      final int arrId = (idBase + 301) % 100000;
      final int quickArrId = (idBase + 305) % 100000;
      await _notificationsPlugin.cancel(depId);
      await _notificationsPlugin.cancel(arrId);
      await _notificationsPlugin.cancel(quickArrId);

      for (int i = 0; i < trip.legs.length; i++) {
        final int transferId = (idBase + 200 + i) % 100000;
        await _notificationsPlugin.cancel(transferId);
      }
      debugPrint('[NotificationService] Cancelled reminders for trip ${trip.idx}');
    } catch (e) {
      debugPrint('[NotificationService] Error cancelling reminders: $e');
    }
  }

  /// Show or update a persistent ongoing notification card for the active trip
  Future<void> showOngoingTripNotification({
    required TripProposal trip,
    required Station origin,
    required Station destination,
    String lang = 'zh_CN',
  }) async {
    await init();
    await requestPermission();

    final DateTime now = DateTime.now();
    final DateTime? tripDate = _parseHafasDate(
      trip.legs.isNotEmpty ? trip.legs.first.origin.date : null,
    );
    final DateTime baseDate = tripDate ?? now;
    final bool hasExplicitDate = tripDate != null;

    // Determine currently active or next upcoming motorized leg based on current time
    TripLeg? currentLeg;
    for (var leg in trip.legs) {
      if (leg.isWalk) continue;
      if (leg.destination.time.isNotEmpty) {
        final legArrDate = _parseHafasDate(leg.destination.date) ?? baseDate;
        final arrDt = _parseTripDateTime(
          leg.destination.time,
          legArrDate,
          hasExplicitDate: hasExplicitDate || leg.destination.date.isNotEmpty,
        );
        if (arrDt.isAfter(now)) {
          currentLeg = leg;
          break;
        }
      } else {
        currentLeg = leg;
        break;
      }
    }
    // Fallback to the last non-walk leg or first leg if all leg arrival times have passed
    if (currentLeg == null) {
      for (var leg in trip.legs.reversed) {
        if (!leg.isWalk) {
          currentLeg = leg;
          break;
        }
      }
    }
    currentLeg ??= (trip.legs.isNotEmpty ? trip.legs.first : null);

    final lineName = currentLeg?.name ?? trip.depTime;
    final trackStr = (currentLeg?.origin.track.isNotEmpty == true && currentLeg!.origin.track != '-')
        ? ' (${I18n.tr("trip_platform", lang)} ${currentLeg.origin.track})'
        : '';
    final nextStop = currentLeg?.destination.name ?? destination.name;
    final arrTime = currentLeg?.destination.time ?? trip.arrTime;

    final String title = '🚆 ' + I18n.tr('notif_ongoing_title', lang, {
      'line': lineName + trackStr,
      'station': nextStop,
    });
    final String body = I18n.tr('notif_ongoing_body', lang, {
      'time': arrTime,
      'nextStop': nextStop,
      'dest': destination.name,
      'arrTime': trip.arrTime,
    });

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      ongoingChannelId,
      ongoingChannelName,
      channelDescription: ongoingChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // User cannot swipe away while trip is active
      autoCancel: false,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      ),
    );

    await _notificationsPlugin.show(
      ongoingNotificationId,
      title,
      body,
      details,
      payload: 'ongoing_trip_${trip.idx}',
    );
    debugPrint('[NotificationService] Shown ongoing trip card: $title');
  }

  /// Remove the ongoing trip notification
  Future<void> stopOngoingTripNotification() async {
    await _notificationsPlugin.cancel(ongoingNotificationId);
    debugPrint('[NotificationService] Stopped ongoing trip card');
  }

  /// Cancel all pending notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}

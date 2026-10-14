import 'package:flutter/foundation.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/trip.dart';
import '../models/station.dart';
import '../i18n/translations.dart';

class CalendarService {
  /// Checks and requests calendar permissions from the operating system
  static Future<bool> requestCalendarPermission() async {
    // Android uses platform Intent (ACTION_INSERT) via add_2_calendar, requiring no runtime permissions
    if (defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }
    try {
      final fullStatus = await Permission.calendarFullAccess.status;
      if (fullStatus.isGranted) return true;

      final writeStatus = await Permission.calendarWriteOnly.status;
      if (writeStatus.isGranted) return true;

      final reqFull = await Permission.calendarFullAccess.request();
      if (reqFull.isGranted) return true;

      final reqWrite = await Permission.calendarWriteOnly.request();
      if (reqWrite.isGranted) return true;

      final legacyStatus = await Permission.calendar.status;
      if (legacyStatus.isGranted) return true;
      final reqLegacy = await Permission.calendar.request();
      return reqLegacy.isGranted;
    } catch (e) {
      debugPrint('[CalendarService] Error checking/requesting permission: $e');
      return true;
    }
  }

  /// Checks if calendar permissions have been permanently denied by the user
  static Future<bool> isPermanentlyDenied() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return false;
    }
    try {
      final full = await Permission.calendarFullAccess.status;
      final write = await Permission.calendarWriteOnly.status;
      final legacy = await Permission.calendar.status;
      return full.isPermanentlyDenied || write.isPermanentlyDenied || legacy.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }
  static DateTime _parseDateTime(String timeStr, String dateStr, DateTime fallback) {
    try {
      int year = fallback.year;
      int month = fallback.month;
      int day = fallback.day;

      if (dateStr.isNotEmpty) {
        if (dateStr.contains('-')) {
          final p = dateStr.split('-');
          if (p.length == 3) {
            year = int.parse(p[0]);
            month = int.parse(p[1]);
            day = int.parse(p[2]);
          }
        } else if (dateStr.contains('.')) {
          final p = dateStr.split('.');
          if (p.length == 3) {
            day = int.parse(p[0]);
            month = int.parse(p[1]);
            year = int.parse(p[2].length == 2 ? '20${p[2]}' : p[2]);
          }
        }
      }

      int hour = fallback.hour;
      int minute = fallback.minute;
      if (timeStr.isNotEmpty && timeStr.contains(':')) {
        final tp = timeStr.split(':');
        hour = int.parse(tp[0]);
        minute = int.parse(tp[1]);
      }

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      debugPrint('[CalendarService] Error parsing date: $e');
      return fallback;
    }
  }

  /// Exports the selected trip itinerary directly into device native calendar (Apple Calendar / Google Calendar)
  static Future<bool> addTripToCalendar({
    required TripProposal trip,
    required Station origin,
    required Station destination,
    String lang = 'zh_CN',
  }) async {
    try {
      // 1. Request calendar permission from the operating system
      await requestCalendarPermission();

      final now = DateTime.now();
      final String firstLegDate = trip.legs.isNotEmpty ? trip.legs.first.origin.date : '';
      final String lastLegDate = trip.legs.isNotEmpty ? trip.legs.last.destination.date : '';

      final DateTime start = _parseDateTime(trip.depTime, firstLegDate, now);
      DateTime end = _parseDateTime(trip.arrTime, lastLegDate, start.add(Duration(minutes: trip.durationMin)));
      if (end.isBefore(start)) {
        end = start.add(Duration(minutes: trip.durationMin > 0 ? trip.durationMin : 30));
      }

      final buffer = StringBuffer();
      buffer.writeln('${origin.name} ➔ ${destination.name}');
      buffer.writeln('${I18n.tr("trip_duration", lang)}: ${trip.durationMin} min | ${trip.changes} ${I18n.tr("trip_changes", lang)}');
      buffer.writeln('----------------------------------------');

      for (int i = 0; i < trip.legs.length; i++) {
        final leg = trip.legs[i];
        final legPlatform = leg.origin.track.isNotEmpty && leg.origin.track != '-'
            ? ' (${I18n.tr("trip_platform", lang)} ${leg.origin.track})'
            : '';
        if (leg.isWalk) {
          buffer.writeln('${i + 1}. [${I18n.tr("trip_walk", lang)}] ${leg.origin.name} ➔ ${leg.destination.name} (${leg.origin.time} - ${leg.destination.time})');
        } else {
          buffer.writeln('${i + 1}. [${leg.name}] ${leg.origin.name}$legPlatform ➔ ${leg.destination.name} (${leg.origin.time} - ${leg.destination.time})');
        }
        if (leg.notes.isNotEmpty) {
          buffer.writeln('   ℹ️ ${leg.notes}');
        }
      }
      buffer.writeln('----------------------------------------');
      buffer.writeln('Spor');

      final firstPlatform = trip.legs.isNotEmpty && trip.legs.first.origin.track.isNotEmpty && trip.legs.first.origin.track != '-'
          ? ' (${I18n.tr("trip_platform", lang)} ${trip.legs.first.origin.track})'
          : '';

      final firstLegName = trip.legs.isNotEmpty ? trip.legs.first.name : '';

      final String eventTitle = 'Spor: ${origin.name} ➔ ${destination.name}' +
          (firstLegName.isNotEmpty ? ' [$firstLegName]' : '');

      final event = Event(
        title: eventTitle,
        description: buffer.toString(),
        location: '${origin.name}$firstPlatform, Denmark',
        startDate: start,
        endDate: end,
        iosParams: const IOSParams(
          reminder: Duration(minutes: 15),
        ),
        androidParams: const AndroidParams(
          emailInvites: [],
        ),
      );

      final success = await Add2Calendar.addEvent2Cal(event);
      return success;
    } catch (e) {
      debugPrint('[CalendarService] Error adding to calendar: $e');
      return false;
    }
  }
}

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Daily reading-reminder notifications (flutter_local_notifications).
///
/// Schedules a repeating notification at the user-chosen time. The text
/// is in Russian (no Chinese required).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _reminderId = 100;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Reschedules or cancels the daily reminder.
  /// [time] is "HH:MM" in local time.
  Future<void> onReminderChanged(bool enabled, String time) async {
    await _ensureInitialized();
    try {
      if (!enabled) {
        await _plugin.cancel(_reminderId);
        return;
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reading_reminder',
          'Ежедневные напоминания',
          channelDescription:
              'Напоминание о ежедневном чтении китайских текстов',
          importance: Importance.defaultImportance,
        ),
      );

      final now = DateTime.now();
      final hour = int.tryParse(time.split(':').first) ?? 18;
      final minute = int.tryParse(time.split(':').last) ?? 0;

      var next = DateTime(now.year, now.month, now.day, hour, minute);
      if (next.isBefore(now)) {
        next = next.add(const Duration(days: 1));
      }

      tz_data.initializeTimeZones();
      await _plugin.zonedSchedule(
        _reminderId,
        'Время читать!',
        'Не забудьте поработать над китайским 📖',
        _tz(next),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      // Best-effort: notifications are a nice-to-have; never break the
      // settings screen because of them.
      debugPrint('[Notif] reminder scheduling failed: $e');
    }
  }

  /// Converts a [DateTime] (interpreted as local wall-clock time) to a
  /// [tz.TZDateTime] for zonedSchedule.
  ///
  /// Uses the `Etc/GMT±H` zones from the bundled tz database (note: the
  /// Etc/GMT sign is *inverted* relative to the UTC offset sign) so no
  /// tzlocal platform lookup is needed.
  tz.TZDateTime _tz(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final hours = offset.inHours.abs();
    final minutes = offset.inMinutes.remainder(60).abs();
    final suffix = minutes == 0 ? '' : '30';
    // Etc/GMT+H means UTC−H, Etc/GMT−H means UTC+H.
    final etcName = offset.inMinutes >= 0
        ? 'Etc/GMT-$hours$suffix'
        : 'Etc/GMT$hours$suffix';
    return tz.TZDateTime(
      tz.getLocation(etcName),
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
    );
  }
}

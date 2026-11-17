import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'recipes.dart';

class ExpiryItem {
  final String name;
  final DateTime expiry;
  const ExpiryItem(this.name, this.expiry);
}

/// One reminder to schedule. [when] is local wall-clock time.
class PlannedReminder {
  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String payload;
  const PlannedReminder(
    this.id,
    this.title,
    this.body,
    this.when,
    this.payload,
  );
}

/// Expiry reminders: the day before and the morning an item expires, each
/// with recipe tips, at the user's chosen time (default 9:00).
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static String _lastSignature = '';
  static List<ExpiryItem> _lastItems = const [];

  /// Time of day reminders fire. Changed from the profile screen.
  static int reminderHour = 9;
  static int reminderMinute = 0;

  /// Set when the user taps an expiry reminder: the fridge item it was
  /// about. The home screen listens and opens recipes for that item.
  static final ValueNotifier<String?> openItem = ValueNotifier(null);

  static const _payloadPrefix = 'item:';

  /// White silhouette for the status bar (res/drawable-*/), tinted leaf green.
  static const _statusIcon = 'ic_stat_fridge_mate';
  static const _accent = Color(0xFF6BD28B);

  static NotificationDetails _details([String? longText]) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_alerts',
          'Expiry alerts',
          channelDescription: 'Reminders when food is about to expire',
          importance: Importance.high,
          priority: Priority.high,
          icon: _statusIcon,
          color: _accent,
          // Shows the whole message (with recipe tips) when expanded.
          styleInformation: longText == null
              ? null
              : BigTextStyleInformation(longText),
        ),
        iOS: const DarwinNotificationDetails(),
      );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    // Follow the phone's own time zone, so reminders fire at the chosen
    // local time wherever the user is. Malaysia time if it can't be read.
    try {
      final device = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(device.identifier));
    } catch (e) {
      debugPrint('Using Asia/Kuala_Lumpur; device time zone unavailable: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/$_statusIcon'),
      // iOS asks for alert, sound and badge permission on first launch.
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (r) => _handleTap(r.payload),
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    // The app may have been opened by tapping a reminder while it was closed.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _handleTap(launch!.notificationResponse?.payload);
    }
    _ready = true;
  }

  static void _handleTap(String? payload) {
    if (payload != null && payload.startsWith(_payloadPrefix)) {
      openItem.value = payload.substring(_payloadPrefix.length);
    }
  }

  /// Whether the app may show notifications (Android 13+ asks the user).
  /// Null where it can't be checked.
  static Future<bool?> notificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return android?.areNotificationsEnabled();
  }

  /// Asks for notification permission again. Returns whether it's granted.
  static Future<bool?> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return android?.requestNotificationsPermission();
  }

  /// How many reminders are waiting to be shown.
  static Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;

  /// Changes the reminder time and reschedules everything for it.
  static Future<void> setReminderTime(int hour, int minute) async {
    if (hour == reminderHour && minute == reminderMinute) return;
    reminderHour = hour;
    reminderMinute = minute;
    _lastSignature = '';
    await reschedule(_lastItems);
  }

  /// The reminder text for an item, with up to three recipe tips that use it.
  @visibleForTesting
  static String reminderBody(String itemName, String when, List<String> tips) {
    final base = '$itemName $when.';
    if (tips.isEmpty) return '$base Use it or lose it!';
    return '$base Try: ${joinOr(tips)}.';
  }

  /// Decides which reminders to schedule (pure, so it can be tested).
  ///
  /// For each item: one the day before it expires and one on the day, at
  /// [hour]:[minute], skipping any that are already in the past at [now].
  /// Expired items get none.
  static List<PlannedReminder> planReminders(
    List<ExpiryItem> items,
    DateTime now, {
    int hour = 9,
    int minute = 0,
  }) {
    final pantry = [for (final i in items) PantryItem(i.name, i.expiry)];
    final out = <PlannedReminder>[];
    var id = 0;
    for (final item in items) {
      final day = DateTime(
        item.expiry.year,
        item.expiry.month,
        item.expiry.day,
        hour,
        minute,
      );
      if (!day.isAfter(now)) continue;
      final dayBefore = DateTime(
        day.year,
        day.month,
        day.day - 1,
        hour,
        minute,
      );

      final tips = recipesUsing(item.name, pantry).map((r) => r.name).toList();
      final payload = '$_payloadPrefix${item.name}';

      if (dayBefore.isAfter(now)) {
        out.add(
          PlannedReminder(
            id++,
            'Expiring tomorrow: ${item.name}',
            reminderBody(item.name, 'expires tomorrow', tips),
            dayBefore,
            payload,
          ),
        );
      }
      out.add(
        PlannedReminder(
          id++,
          'Expires today: ${item.name}',
          reminderBody(item.name, 'expires today', tips),
          day,
          payload,
        ),
      );
    }
    return out;
  }

  /// Cancels old reminders and schedules new ones for the given items.
  static Future<void> reschedule(List<ExpiryItem> items) async {
    _lastItems = items;
    if (!_ready) return;

    // Skip the work if nothing changed.
    final itemsSig = items
        .map((e) => '${e.name}|${e.expiry.millisecondsSinceEpoch}')
        .join(';');
    final sig = '$reminderHour:$reminderMinute;$itemsSig';
    if (sig == _lastSignature) return;
    _lastSignature = sig;

    await _plugin.cancelAll();

    final nowTz = tz.TZDateTime.now(tz.local);
    final now = DateTime(
      nowTz.year,
      nowTz.month,
      nowTz.day,
      nowTz.hour,
      nowTz.minute,
      nowTz.second,
    );
    final planned = planReminders(
      items,
      now,
      hour: reminderHour,
      minute: reminderMinute,
    );

    for (final r in planned) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.payload,
        scheduledDate: tz.TZDateTime(
          tz.local,
          r.when.year,
          r.when.month,
          r.when.day,
          r.when.hour,
          r.when.minute,
        ),
        notificationDetails: _details(r.body),
        // Inexact mode avoids the special "exact alarm" permission; Android
        // may deliver a few minutes late to save battery.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint(
      'Expiry reminders scheduled: ${pending.length} '
      '(at ${reminderHour.toString().padLeft(2, '0')}:'
      '${reminderMinute.toString().padLeft(2, '0')})',
    );
  }
}

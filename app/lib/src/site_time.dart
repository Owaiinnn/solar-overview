import 'package:timezone/data/latest_all.dart' as database;
import 'package:timezone/timezone.dart' as tz;

bool _loaded = false;

tz.Location? siteLocation(String? name) {
  if (!_loaded) {
    database.initializeTimeZones();
    _loaded = true;
  }
  if (name == null) return null;
  try {
    return tz.getLocation(name);
  } catch (_) {
    return null;
  }
}

String? validSiteTimestamp(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse('${value.replaceFirst(' ', 'T')}Z');
  return parsed != null &&
          parsed.toIso8601String().substring(0, 19) ==
              value.replaceFirst(' ', 'T')
      ? value
      : null;
}

DateTime? siteTimestampUtc(String? stamp, String? zone) {
  final location = siteLocation(zone);
  if (validSiteTimestamp(stamp) == null || location == null) return null;
  final wall = DateTime.parse('${stamp!.replaceFirst(' ', 'T')}Z');
  final matches = <DateTime>{};
  for (final offset in location.zones.map((z) => z.offset).toSet()) {
    final candidate = wall.subtract(offset);
    final local = tz.TZDateTime.from(candidate, location);
    if (local.year == wall.year &&
        local.month == wall.month &&
        local.day == wall.day &&
        local.hour == wall.hour &&
        local.minute == wall.minute &&
        local.second == wall.second) {
      matches.add(candidate);
    }
  }
  return matches.length == 1 ? matches.single : null;
}

bool isSiteToday(DateTime instant, DateTime now, String? zone) {
  final location = siteLocation(zone);
  if (location == null) return false;
  final reported = tz.TZDateTime.from(instant, location);
  final today = tz.TZDateTime.from(now, location);
  return reported.year == today.year &&
      reported.month == today.month &&
      reported.day == today.day;
}

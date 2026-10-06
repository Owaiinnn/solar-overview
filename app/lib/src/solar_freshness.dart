enum ReadingFreshness { recent, stale, unknown }

const solarStaleAfter = Duration(minutes: 30);

ReadingFreshness solarFreshness(DateTime? reportedAt, DateTime now) {
  final currentTime = now.toUtc();
  if (reportedAt == null || reportedAt.isAfter(currentTime)) {
    return ReadingFreshness.unknown;
  }
  return currentTime.difference(reportedAt) >= solarStaleAfter
      ? ReadingFreshness.stale
      : ReadingFreshness.recent;
}

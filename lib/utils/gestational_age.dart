// lib/utils/gestational_age.dart

// Simple gestational age utilities.
//
// Provides functions to compute gestational age from a Last Menstrual
// Period (LMP) or from an estimated due date (EDD).
// All functions return a plain data class `GestationalAge` which contains
// weeks, days and a nice `toString()`.

class GestationalAge {
  final int weeks;
  final int days;

  GestationalAge({required this.weeks, required this.days});

  /// Total days of pregnancy.
  int get totalDays => weeks * 7 + days;

  /// Human readable representation, e.g. "12w 3d".
  @override
  String toString() => '${weeks}w ${days}d';
}

/// Calculate gestational age from last menstrual period [lmp].
///
/// If [now] is omitted the current time is used. If LMP is in the future
/// this returns 0w 0d (clamped to zero).
GestationalAge gestationalAgeFromLMP(DateTime lmp, {DateTime? now}) {
  final DateTime end = now ?? DateTime.now();
  // Normalize times to dates to avoid timezone partial-day issues
  final lmpDate = DateTime(lmp.year, lmp.month, lmp.day);
  final nowDate = DateTime(end.year, end.month, end.day);

  final difference = nowDate.difference(lmpDate).inDays;
  final clamped = difference < 0 ? 0 : difference;
  final weeks = clamped ~/ 7;
  final days = clamped % 7;
  return GestationalAge(weeks: weeks, days: days);
}

/// Calculate gestational age from estimated due date [edd].
///
/// This returns the time elapsed since conception assuming a 280-day
/// (40-week) pregnancy: GA = 280 days - days until EDD. If EDD is in the past
/// the result can be > 40 weeks.
GestationalAge gestationalAgeFromEDD(DateTime edd, {DateTime? now}) {
  final DateTime today = now ?? DateTime.now();
  final eddDate = DateTime(edd.year, edd.month, edd.day);
  final todayDate = DateTime(today.year, today.month, today.day);
  final daysUntilEdd = eddDate.difference(todayDate).inDays;

  // gestational age in days assuming 280-day full term
  final gaDays = 280 - daysUntilEdd;
  final clamped = gaDays < 0 ? 0 : gaDays;
  final weeks = clamped ~/ 7;
  final days = clamped % 7;
  return GestationalAge(weeks: weeks, days: days);
}

/// Convenience: parse an LMP string in ISO 8601 (yyyy-MM-dd) and compute GA.
/// Returns null if parsing fails.
GestationalAge? gestationalAgeFromLMPString(String isoDate, {DateTime? now}) {
  try {
    final parsed = DateTime.parse(isoDate);
    return gestationalAgeFromLMP(parsed, now: now);
  } catch (_) {
    return null;
  }
}

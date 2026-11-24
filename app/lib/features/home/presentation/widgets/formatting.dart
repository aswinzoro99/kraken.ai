import 'package:intl/intl.dart';

/// "today", "yesterday", "4 days ago", then "12 Oct".
String relativeDay(DateTime date, DateTime now) {
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
  return switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    < 7 => '$days days ago',
    _ => DateFormat('d MMM').format(date),
  };
}

String people(int n) => n == 1 ? '1 person' : '$n people';

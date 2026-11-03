import 'package:intl/intl.dart';

/// Small shared formatters and human labels.

const oilTypes = ['sunflower', 'mustard', 'soybean', 'palm', 'mixed', 'other'];
const orgTypes = ['hotel', 'restaurant', 'marriage_hall', 'cloud_kitchen', 'household', 'other'];

String oilLabel(String t) => switch (t) {
      'sunflower' => 'Sunflower',
      'mustard' => 'Mustard',
      'soybean' => 'Soybean',
      'palm' => 'Palm',
      'mixed' => 'Mixed',
      _ => 'Other',
    };

String oilEmoji(String t) => switch (t) {
      'sunflower' => '🌻',
      'mustard' => '🌾',
      'soybean' => '🫘',
      'palm' => '🌴',
      _ => '🫗',
    };

String orgLabel(String t) => switch (t) {
      'hotel' => 'Hotel',
      'restaurant' => 'Restaurant',
      'marriage_hall' => 'Marriage hall',
      'cloud_kitchen' => 'Cloud kitchen',
      'household' => 'Home',
      _ => 'Other',
    };

String orgIcon(String t) => switch (t) {
      'hotel' => '🏨',
      'restaurant' => '🍽️',
      'marriage_hall' => '🎪',
      'cloud_kitchen' => '🛵',
      'household' => '🏠',
      _ => '🏢',
    };

String statusLabel(String s) => switch (s) {
      'open' => 'Ready for pickup',
      'claimed' => 'Pickup scheduled',
      'collected' => 'Collected',
      'cancelled' => 'Cancelled',
      'expired' => 'Window closed',
      'scheduled' => 'Scheduled',
      'completed' => 'Completed',
      _ => s,
    };

String money(num v, {bool decimals = false}) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: decimals ? 2 : 0).format(v);

String litres(num v) => '${NumberFormat('#,##0.#').format(v)} L';

String dayMonth(DateTime d) => DateFormat('d MMM').format(d);
String dayMonthTime(DateTime d) => DateFormat('d MMM, h:mm a').format(d);
String timeOnly(DateTime d) => DateFormat('h:mm a').format(d);
String fullDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return dayMonth(d);
}

/// A pickup window that reads naturally: "Today 6 pm → Tomorrow 9 am".
String windowLabel(DateTime from, DateTime to) {
  final now = DateTime.now();
  final a = DateUtilsHelper.sameDay(from, now)
      ? 'Today ${timeOnly(from)}'
      : DateUtilsHelper.sameDay(from, now.add(const Duration(days: 1)))
          ? 'Tomorrow ${timeOnly(from)}'
          : dayMonthTime(from);
  final b = DateUtilsHelper.sameDay(to, now)
      ? 'Today ${timeOnly(to)}'
      : DateUtilsHelper.sameDay(to, now.add(const Duration(days: 1)))
          ? 'Tomorrow ${timeOnly(to)}'
          : dayMonthTime(to);
  return '$a → $b';
}

class DateUtilsHelper {
  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

/// Digits only, with 91 prefixed for WhatsApp (Indian numbers).
String waNumber(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) return '91$digits';
  if (digits.startsWith('0') && digits.length == 11) return '91${digits.substring(1)}';
  return digits;
}

extension _CharAt on String {
  Iterable<String> get characters => split('');
}

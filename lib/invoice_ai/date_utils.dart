class DateUtils {
  static const Map<String, int> monthNames = {
    'enero': 1,
    'febrero': 2,
    'marzo': 3,
    'abril': 4,
    'mayo': 5,
    'junio': 6,
    'julio': 7,
    'agosto': 8,
    'septiembre': 9,
    'setiembre': 9,
    'octubre': 10,
    'noviembre': 11,
    'diciembre': 12,
  };

  static String? normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim();
    print('DateUtils.normalize called with: $normalized');

    // Intentar nombre de mes primero
    final monthNameMatch = RegExp(
            r'(\d{1,2})[- ]?(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)[a-z]*[- ]?(\d{4})',
            caseSensitive: false)
        .firstMatch(normalized);
    if (monthNameMatch != null) {
      final day = int.parse(monthNameMatch.group(1)!);
      final monthName = monthNameMatch.group(2)!.toLowerCase();
      final year = monthNameMatch.group(3)!;
      return normalizeMonthNameDate(day, monthName, year);
    }

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) return normalized;

    if (!RegExp(r'^\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}$').hasMatch(normalized)) {
      return null;
    }

    final separator = normalized.contains('/')
        ? '/'
        : normalized.contains('.')
            ? '.'
            : '-';
    final parts = normalized.split(separator);
    if (parts.length != 3) {
      return null;
    }

    final first = parts[0].padLeft(2, '0');
    final second = parts[1].padLeft(2, '0');
    final third = parts[2];
    if (third.length == 2) {
      return '20$third-$second-$first';
    }
    return '$third-$second-$first';
  }

  static String? normalizeMonthNameDate(
      int day, String monthName, String year) {
    final strippedMonthName = _stripAccents(monthName.toLowerCase());
    final month = monthNames[strippedMonthName] ?? 0;
    print(
        'normalizeMonthNameDate day: $day, monthName: $monthName, stripped: $strippedMonthName, month: $month, year: $year');
    if (month == 0) return null;
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  static String _stripAccents(String input) {
    const from = 'áéíóúÁÉÍÓÚñÑ';
    const to = 'aeiouAEIOUUnN';
    var result = input;
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }
}

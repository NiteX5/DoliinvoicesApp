class AmountUtils {
  static double? normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var processed = raw.trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (processed.isEmpty ||
        processed == '-' ||
        processed == ',' ||
        processed == '.') {
      return null;
    }

    final lastComma = processed.lastIndexOf(',');
    final lastDot = processed.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      // El último separador es el decimal: 1.234,50 y 1,234.50.
      final decimalIndex = lastComma > lastDot ? lastComma : lastDot;
      final integer =
          processed.substring(0, decimalIndex).replaceAll(RegExp(r'[.,]'), '');
      final fraction =
          processed.substring(decimalIndex + 1).replaceAll(RegExp(r'[.,]'), '');
      processed = '$integer.$fraction';
    } else if (lastComma >= 0 || lastDot >= 0) {
      final separator = lastComma >= 0 ? ',' : '.';
      final parts = processed.split(separator);
      // Un solo separador seguido de uno/dos dígitos es decimal. El resto
      // son separadores de miles, como se imprime normalmente en documentos chilenos.
      processed = parts.length == 2 && parts.last.length <= 2
          ? '${parts.first}.${parts.last}'
          : parts.join();
    }

    // Intentar parsear!
    final number = double.tryParse(processed);

    print(
        'AmountUtils.normalize: input=$raw, processed=$processed, result=$number');
    return number;
  }

  static String formatForApi(double value) {
    return value.toStringAsFixed(2);
  }
}

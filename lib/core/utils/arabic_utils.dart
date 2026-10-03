class ArabicUtils {
  ArabicUtils._();

  static const _easternDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// 123 -> ١٢٣
  static String toArabicDigits(Object value) {
    final buffer = StringBuffer();
    for (final ch in value.toString().split('')) {
      final d = int.tryParse(ch);
      buffer.write(d == null ? ch : _easternDigits[d]);
    }
    return buffer.toString();
  }

  static final RegExp _diacritics = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

  /// Normalizes Arabic text for searching: strips tashkeel, Quranic marks
  /// and tatweel, and unifies letter variants.
  static String normalize(String input) {
    var s = input.replaceAll('﻿', '').replaceAll(_diacritics, '');
    s = s
        .replaceAll(RegExp('[أإآٱٲٳ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ة', 'ه')
        .replaceAll('ۥ', '')
        .replaceAll('ۦ', '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Search key: [normalize] without spaces, so «يا أيها» matches «ياأيها».
  /// The index is built from the plain (imlaei) spelling of each ayah.
  static String searchKey(String input) => normalize(input).replaceAll(' ', '');

  /// ~14-word excerpt of [text] around the first word matching [query].
  static String snippet(String text, String query) {
    final words = text.split(' ');
    if (words.length <= 14) return text;
    final firstKey = searchKey(query.trim().split(RegExp(r'\s+')).first).replaceAll('ا', '');
    var i = firstKey.isEmpty ? 0 : words.indexWhere((w) => searchKey(w).replaceAll('ا', '').contains(firstKey));
    if (i < 0) i = 0;
    final start = (i - 4).clamp(0, words.length);
    final end = (start + 14).clamp(0, words.length);
    return '${start > 0 ? '… ' : ''}${words.sublist(start, end).join(' ')}${end < words.length ? ' …' : ''}';
  }

  static final String _bismillahNormalized = normalize('بسم الله الرحمن الرحيم');

  /// The API prefixes the first ayah of every surah (except Al-Fatihah and
  /// At-Tawbah) with the Basmala. We show it as a separate header instead.
  static String stripBismillah(String text, int surah) {
    final clean = text.replaceAll('﻿', '').trim();
    if (surah == 1 || surah == 9) return clean;
    final words = clean.split(' ');
    if (words.length > 4 && normalize(words.take(4).join(' ')) == _bismillahNormalized) {
      return words.skip(4).join(' ').trim();
    }
    return clean;
  }

  /// Ornate ayah end marker: ﴿١٢﴾
  static String ayahMarker(int number) => '﴿${toArabicDigits(number)}﴾';

  /// End-of-ayah sign U+06DD followed by the number: the bundled Amiri Quran
  /// font composes this into the ornate numbered medallion used in the Mushaf.
  static String ornateAyahMarker(int number) => '\u00A0${toArabicDigits(number)}';

  static String formatDuration(Duration d, {bool withSeconds = true}) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final raw = withSeconds ? (h > 0 ? '$h:$m:$s' : '$m:$s') : (h > 0 ? '$h:$m' : m);
    return toArabicDigits(raw);
  }

  /// Arabic counting: دقيقة، دقيقتان (دقيقتين after a preposition),
  /// ٣–١٠ دقائق، ١١ فأكثر دقيقة.
  static String minutes(int n, {bool afterPreposition = false}) =>
      _count(n, 'دقيقة', afterPreposition ? 'دقيقتين' : 'دقيقتان', 'دقائق');

  static String hours(int n, {bool afterPreposition = false}) =>
      _count(n, 'ساعة', afterPreposition ? 'ساعتين' : 'ساعتان', 'ساعات');

  static String _count(int n, String one, String two, String few) {
    if (n == 1) return one;
    if (n == 2) return two;
    final d = toArabicDigits(n);
    final r = n % 100;
    if (r >= 3 && r <= 10) return '$d $few';
    return '$d $one';
  }

  static String formatTime(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour < 12 ? 'ص' : 'م';
    return '${toArabicDigits('$hour12:${t.minute.toString().padLeft(2, '0')}')} $period';
  }
}

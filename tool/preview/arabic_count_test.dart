import 'package:al_huda/core/utils/arabic_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arabic counting of minutes', () {
    expect(ArabicUtils.minutes(1), 'دقيقة');
    expect(ArabicUtils.minutes(2, afterPreposition: true), 'دقيقتين');
    expect(ArabicUtils.minutes(5), '٥ دقائق');
    expect(ArabicUtils.minutes(10), '١٠ دقائق');
    expect(ArabicUtils.minutes(15), '١٥ دقيقة');
    expect(ArabicUtils.minutes(20), '٢٠ دقيقة');
    expect(ArabicUtils.minutes(103), '١٠٣ دقائق');
  });
}

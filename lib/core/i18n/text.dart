import 'package:flutter/widgets.dart' as w;
import 'package:flutter/widgets.dart' show BuildContext, Color, IconData, InlineSpan, Locale, StatelessWidget, StrutStyle, TextAlign,
    TextDirection, TextHeightBehavior, TextOverflow, TextScaler, TextStyle, TextWidthBasis, Widget;

import 'i18n.dart';

export 'i18n.dart' show tr, I18n;

/// The «open» chevron of list rows and cards: the same arrow (›) in Arabic
/// and English (Icons.chevron_left_rounded turns with the text direction).
const IconData kGoChevron = IconData(0xf63b, fontFamily: 'MaterialIcons');

/// The app's [Text]: Flutter's own, with the string passed through [tr] so
/// the interface follows the chosen language. Files import it in place of
/// Flutter's (`hide Text`). Quran text (its own fonts) is never touched.
class Text extends StatelessWidget {
  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  static bool _isQuran(TextStyle? s) {
    final f = s?.fontFamily;
    if (f == null) return false;
    return f.contains('Hafs') || f.contains('Quran') || f.contains('Scheherazade') || f.contains('Naskh');
  }

  @override
  Widget build(BuildContext context) {
    final span = textSpan;
    if (span != null) {
      return w.Text.rich(
        span,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    final text = I18n.en && !_isQuran(style) ? tr(data!) : data!;
    return w.Text(
      text,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

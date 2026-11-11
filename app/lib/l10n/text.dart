import 'package:flutter/material.dart' as m;

import 'script.dart';

export 'script.dart' show t;

/// Flutter'ning `Text` vidjeti o'rnida ishlatiladigan nusxa — matnni
/// joriy yozuvda (lotin yoki kirill) chizadi.
///
/// NEGA SHUNDAY: ilovada yuzlab `Text('...')` bor. Har birini qo'lda
/// `t()` ga o'rash — bittasini unutish va ekranda aralash yozuv
/// qoldirish degani. Shu sabab fayllar `material.dart` ni `hide Text`
/// bilan import qiladi va shu vidjetni oladi: mavjud `Text('...')`
/// yozuvi o'zgarmaydi, lekin endi yozuvni o'zi hisobga oladi.
///
/// Raqam, telefon, № va kirillda kiritilgan matn o'girilganda
/// o'zgarmaydi — faqat lotin harflar o'giriladi.
class Text extends m.StatelessWidget {
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
  })  : textSpan = null,
        verbatim = false;

  const Text.rich(
    m.InlineSpan this.textSpan, {
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
  })  : data = null,
        verbatim = false;

  /// Matnni O'GIRMASDAN chizadi.
  ///
  /// Kamdan-kam kerak: masalan yozuv tanlovida "Lotin" va "Кирилл"
  /// har biri o'z yozuvida turishi shart.
  const Text.verbatim(
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
  })  : textSpan = null,
        verbatim = true;

  final String? data;
  final m.InlineSpan? textSpan;
  final bool verbatim;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;

  @override
  m.Widget build(m.BuildContext context) {
    final label = semanticsLabel == null ? null : t(semanticsLabel!);
    final value = data;
    if (value != null) {
      return m.Text(
        verbatim ? value : t(value),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: label,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return m.Text.rich(
      _span(textSpan!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: label,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

/// `TextSpan` daraxtidagi barcha matnni o'giradi; `WidgetSpan` o'zgarmaydi.
m.InlineSpan _span(m.InlineSpan span) {
  if (span is! m.TextSpan) return span;
  return m.TextSpan(
    text: span.text == null ? null : t(span.text!),
    children: span.children?.map(_span).toList(),
    style: span.style,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel == null ? null : t(span.semanticsLabel!),
    locale: span.locale,
    spellOut: span.spellOut,
  );
}

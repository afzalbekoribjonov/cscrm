import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_branding.dart';

/// CSCRM brend nishoni — vektor sifatida chiziladi.
///
/// Rasm (PNG) o'rniga [CustomPainter] ishlatilgan: nishon istalgan o'lchamda
/// aniq chiqadi, ilova hajmiga qo'shilmaydi va qorong'i mavzuda ham to'g'ri
/// ko'rinadi. Launcher ikonkasi bilan bir xil shakl — `tools/generate_icons.py`
/// aynan shu geometriyani PNG'ga chiqaradi.
class CscrmMark extends StatelessWidget {
  const CscrmMark({
    super.key,
    this.size = 56,
    this.rounded = 0.225,
    this.filled = true,
  });

  final double size;

  /// Fon kvadratining burchak radiusi (o'lchamga nisbatan).
  final double rounded;

  /// `true` — gradient fon ustida oq tomchi (asosiy ko'rinish).
  /// `false` — fon yo'q, tomchi brend rangida (yorug' sirtlar uchun).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(rounded: rounded, filled: filled),
        isComplex: true,
        willChange: false,
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.rounded, required this.filled});

  final double rounded;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Rect.fromLTWH(0, 0, s, s);

    if (filled) {
      final bg = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brand, AppColors.brandLight],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * rounded)),
        bg,
      );
    }

    // Tomchi: pastdagi doira + tepadagi uch. `saveLayer` ichida chiziladi,
    // shunda porlashlarni `BlendMode.clear` bilan "teshib" olamiz.
    canvas.saveLayer(rect, Paint());

    final drop = Paint()..color = filled ? Colors.white : AppColors.brand;
    final cx = s / 2;
    final r = s * 0.242;
    final cy = s * 0.635;
    canvas.drawCircle(Offset(cx, cy), r, drop);

    final tip = Path()
      ..moveTo(cx, s * 0.115)
      ..lineTo(cx - r * 0.955, cy - r * 0.30)
      ..lineTo(cx + r * 0.955, cy - r * 0.30)
      ..close();
    canvas.drawPath(tip, drop);

    // Porlashlar — tomchi ichidan kesib olinadi.
    final cut = Paint()..blendMode = BlendMode.clear;
    _sparkle(canvas, Offset(s * 0.435, s * 0.615), s * 0.115, cut);
    _sparkle(canvas, Offset(s * 0.605, s * 0.475), s * 0.070, cut);

    canvas.restore();
  }

  /// To'rt uchli porlash (yulduzcha).
  void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final thin = r * 0.20;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + thin, c.dy - thin)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + thin, c.dy + thin)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - thin, c.dy + thin)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - thin, c.dy - thin)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.rounded != rounded || old.filled != filled;
}

/// Nishon + "CSCRM" so'z belgisi — login, splash va app bar sarlavhalari uchun.
class CscrmWordmark extends StatelessWidget {
  const CscrmWordmark({
    super.key,
    this.markSize = 44,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
  });

  final double markSize;
  final TextStyle? titleStyle;

  /// Nom ostidagi qo'shimcha qator. `null` bo'lsa ko'rsatilmaydi.
  final String? subtitle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CscrmMark(size: markSize),
        SizedBox(width: markSize * 0.28),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppBranding.name,
                overflow: TextOverflow.ellipsis,
                style: titleStyle ??
                    theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle ??
                      theme.textTheme.bodySmall?.copyWith(
                        color: context.colorTextSecondary,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shrift oilalari — ikkalasi ham ilova ichida (pubspec.yaml), ya'ni
/// internetsiz ham, birinchi ochilishda ham bir xil ko'rinadi.
abstract class AppFonts {
  /// Matn: Roboto.
  static const sans = 'CscrmSans';

  /// Sarlavha va katta raqamlar: Montserrat.
  static const display = 'CscrmDisplay';

  /// Raqamlar ustun bo'lib turishi uchun (summalar, hisoblagichlar).
  static const tabular = [FontFeature.tabularFigures()];
}

/// Oraliqlar — 4 ning karralilari. Ekranlarda raqam qo'lda yozilmaydi.
abstract class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Ekran chetidan kontentgacha.
  static const double page = 16;
}

/// Burchak radiuslari.
abstract class Radii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

abstract class AppTheme {
  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static TextTheme _textTheme(Color primary, Color secondary) {
    TextStyle display(double size, FontWeight weight, double height,
            {double spacing = 0}) =>
        TextStyle(
          fontFamily: AppFonts.display,
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
          color: primary,
        );
    TextStyle sans(double size, FontWeight weight, double height,
            {double spacing = 0, Color? color}) =>
        TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
          color: color ?? primary,
        );

    return TextTheme(
      displayLarge: display(40, FontWeight.w700, 1.1, spacing: -0.8),
      displayMedium: display(34, FontWeight.w700, 1.12, spacing: -0.6),
      displaySmall: display(28, FontWeight.w700, 1.15, spacing: -0.5),
      headlineLarge: display(26, FontWeight.w700, 1.2, spacing: -0.4),
      headlineMedium: display(22, FontWeight.w700, 1.25, spacing: -0.3),
      headlineSmall: display(20, FontWeight.w700, 1.25, spacing: -0.2),
      titleLarge: display(18, FontWeight.w600, 1.3, spacing: -0.1),
      titleMedium: sans(16, FontWeight.w700, 1.35, spacing: 0.05),
      titleSmall: sans(14, FontWeight.w700, 1.35, spacing: 0.05),
      bodyLarge: sans(16, FontWeight.w400, 1.45),
      bodyMedium: sans(14, FontWeight.w400, 1.42),
      bodySmall: sans(12.5, FontWeight.w400, 1.38, color: secondary),
      labelLarge: sans(14, FontWeight.w500, 1.3, spacing: 0.1),
      labelMedium: sans(12, FontWeight.w500, 1.3, spacing: 0.2),
      labelSmall: sans(11, FontWeight.w500, 1.25, spacing: 0.3),
    );
  }

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final surfaceMuted =
        isDark ? AppColors.surfaceMutedDark : AppColors.surfaceMutedLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final borderStrong =
        isDark ? AppColors.borderStrongDark : AppColors.borderStrongLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primarySoft =
        isDark ? AppColors.primarySoftDark : AppColors.primarySoftLight;
    final primaryInk = isDark ? const Color(0xFF8AB4FF) : AppColors.primary;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: primarySoft,
      onPrimaryContainer: primaryInk,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      // NavigationBar, FilterChip va boshqalarning "tanlangan" foni.
      secondaryContainer: primarySoft,
      onSecondaryContainer: primaryInk,
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceMuted,
      surfaceContainerHighest: surfaceMuted,
      outline: borderStrong,
      outlineVariant: border,
      inverseSurface: isDark ? const Color(0xFFE9EEF6) : const Color(0xFF162033),
      onInverseSurface: isDark ? const Color(0xFF0E1726) : Colors.white,
      inversePrimary: const Color(0xFF8AB4FF),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    final textTheme = _textTheme(textPrimary, textSecondary);
    final buttonText = TextStyle(
      fontFamily: AppFonts.sans,
      fontWeight: FontWeight.w700,
      fontSize: 15,
      letterSpacing: 0.1,
    );
    final controlShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      textTheme: textTheme,
      fontFamily: AppFonts.sans,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(color: textSecondary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Gap.page,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: textPrimary, size: 24),
        actionsIconTheme: IconThemeData(color: textPrimary, size: 24),
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodySmall,
        minVerticalPadding: 10,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 6,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        extendedTextStyle: buttonText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceMuted,
          disabledForegroundColor: textSecondary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: buttonText,
          shape: controlShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceMuted,
          disabledForegroundColor: textSecondary,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: buttonText,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryInk,
          side: BorderSide(color: borderStrong),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: buttonText,
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryInk,
          textStyle: buttonText.copyWith(fontSize: 14),
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(44, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: border.withValues(alpha: 0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: primaryInk,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.danger),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      // Switch ranglari qo'lda: ColorScheme urug'dan emas, shuning uchun
      // standart qiymatlar mavzuga mos tushmaydi (o'chiq switch qora
      // bo'lib, yoqilganga o'xshab qolardi).
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : (isDark ? AppColors.textSecondaryDark : Colors.white)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : (isDark ? AppColors.borderStrongDark : AppColors.borderStrongLight)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        thumbIcon: WidgetStateProperty.resolveWith((states) => null),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: borderStrong, width: 1.6),
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : borderStrong),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primarySoft,
        disabledColor: surfaceMuted,
        labelStyle: textTheme.labelLarge?.copyWith(color: textPrimary),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: primaryInk),
        side: BorderSide(color: border),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        checkmarkColor: primaryInk,
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? primarySoft : surface),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? primaryInk : textPrimary),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
          ),
        ),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: primaryInk,
        unselectedLabelColor: textSecondary,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle:
            textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: border,
        tabAlignment: TabAlignment.start,
        overlayColor: WidgetStatePropertyAll(
          AppColors.primary.withValues(alpha: 0.06),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: const Color(0xFF8AB4FF),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        textStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.danger,
        textColor: Colors.white,
        textStyle: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: surfaceMuted,
        circularTrackColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: surface,
        headerForegroundColor: textPrimary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
        todayBorder: const BorderSide(color: AppColors.primary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primarySoft,
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            textTheme.labelSmall?.copyWith(
              color: states.contains(WidgetState.selected)
                  ? primaryInk
                  : textSecondary,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            )),
      ),
    );
  }
}

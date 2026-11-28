import 'package:flutter/material.dart';

import 'app_text.dart';
import 'app_tokens.dart';

/// Builds the light and dark [ThemeData] from [AureliTokens].
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AureliTokens.light);
  static ThemeData get dark => _build(Brightness.dark, AureliTokens.dark);

  static ThemeData _build(Brightness brightness, AureliTokens t) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.brand,
      onPrimary: Colors.white,
      secondary: t.cobalt,
      onSecondary: brightness == Brightness.dark ? t.canvas : Colors.white,
      error: t.coral,
      onError: brightness == Brightness.dark ? t.canvas : Colors.white,
      surface: t.panel,
      onSurface: t.ink,
      onSurfaceVariant: t.inkSecondary,
      outline: t.hairline,
      outlineVariant: t.hairline,
      surfaceTint: Colors.transparent,
      scrim: t.scrim,
    );

    final textTheme = AppText.textTheme(t.ink, t.inkSecondary);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: t.hairline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppText.family,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.canvas,
      canvasColor: t.canvas,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [t],
      dividerColor: t.hairline,
      dividerTheme: DividerThemeData(color: t.hairline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: t.ink,
        titleTextStyle: AppText.title1.copyWith(color: t.ink),
        iconTheme: IconThemeData(color: t.ink),
      ),
      cardTheme: CardThemeData(
        color: t.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: t.hairline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: AppText.body.copyWith(color: t.inkSecondary),
        hintStyle: AppText.body.copyWith(color: t.inkMuted),
        helperStyle: AppText.caption.copyWith(color: t.inkMuted),
        errorStyle: AppText.caption.copyWith(color: t.coral),
        prefixIconColor: t.inkSecondary,
        suffixIconColor: t.inkSecondary,
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: t.hairline.withValues(alpha: 0.5)),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: t.emerald, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: t.coral),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: t.coral, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _filled(t)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _filled(t)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: t.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppText.label.copyWith(fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.emerald,
          textStyle: AppText.label.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: t.ink),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.brand,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 3,
        shape: const CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.inputFill,
        selectedColor: t.soft(t.emerald, brightness: brightness),
        side: BorderSide(color: t.hairline),
        labelStyle: AppText.label.copyWith(color: t.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : t.inkSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.brand
              : t.inputFill,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : t.hairline,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.emerald,
        linearTrackColor: t.hairline,
        circularTrackColor: t.hairline,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.panel,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.panel,
        modalBarrierColor: t.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: t.hairline),
        ),
        titleTextStyle: AppText.title1.copyWith(color: t.ink),
        contentTextStyle: AppText.body.copyWith(color: t.inkSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: AppText.body.copyWith(color: t.inkInverse),
        actionTextColor: brightness == Brightness.dark ? t.brand : t.emerald,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.inkSecondary,
        textColor: t.ink,
        titleTextStyle: AppText.body.copyWith(color: t.ink),
        subtitleTextStyle: AppText.bodySmall.copyWith(color: t.inkSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: t.hairline),
        ),
        textStyle: AppText.body.copyWith(color: t.ink),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.ink,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppText.caption.copyWith(color: t.inkInverse),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.emerald,
        selectionColor: t.emerald.withValues(alpha: 0.3),
        selectionHandleColor: t.emerald,
      ),
    );
  }

  static ButtonStyle _filled(AureliTokens t) => FilledButton.styleFrom(
        backgroundColor: t.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: t.inkFaint.withValues(alpha: 0.35),
        disabledForegroundColor: t.inkMuted,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: AppText.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      );
}

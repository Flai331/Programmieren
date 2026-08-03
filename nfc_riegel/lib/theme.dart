import 'package:flutter/material.dart';

/// Design-Tokens der App. Spiegel von `design_system/tokens.css` — ändert sich
/// dort etwas, muss es hier und in den beiden Kotlin-Schirmen nachgezogen werden.
///
/// Grundidee: nachtblaue Flächen, Eisblau für alles Interaktive und den
/// Ruhezustand „offen", Bernstein ausschließlich für „gesperrt".
class RiegelColors {
  const RiegelColors._();

  // Akzent
  static const accent = Color(0xFF62D9E8);
  static const accentBright = Color(0xFF8AE6F2);
  static const accentDim = Color(0xFF3FA3B5);
  static const accentTint = Color(0x1F62D9E8); // 12 %
  static const accentTint2 = Color(0x3362D9E8); // 20 %

  // Zustand „gesperrt" — nie für Buttons, nie für Fehler
  static const locked = Color(0xFFF5A65B);
  static const lockedBright = Color(0xFFFFC089);
  static const lockedTint = Color(0x24F5A65B); // 14 %

  // Flächen
  static const bgBase = Color(0xFF080B12);
  static const bgCanvas = Color(0xFF0D1119);
  static const bgElev1 = Color(0xFF141A24);
  static const bgElev2 = Color(0xFF1C2430);
  static const bgElev3 = Color(0xFF26303E);
  static const bgBlock = Color(0xFF05070C);

  // Rahmen
  static const borderSubtle = Color(0x0FFFFFFF); // 6 %
  static const borderDefault = Color(0x1AFFFFFF); // 10 %
  static const borderStrong = Color(0x29FFFFFF); // 16 %

  // Text
  static const fg1 = Color(0xFFEEF2F7);
  static const fg2 = Color(0xFFB6C0CE);
  static const fg3 = Color(0xFF7C8899);
  static const fg4 = Color(0xFF515C6B);
  static const fgOnAccent = Color(0xFF04141A);
  static const fgOnLocked = Color(0xFF1A0E04);

  // Semantik
  static const success = Color(0xFF4ADE80);
  static const danger = Color(0xFFFF6B7A);
  static const dangerDim = Color(0x24FF6B7A);
  static const dangerText = Color(0xFFFFB3BB);
  static const warning = Color(0xFFFBBF24);
  static const info = Color(0xFF60A5FA);
}

/// Vielfache von 4. Bildschirmrand und Kartenabstand liegen bei [s4],
/// Abschnittsabstand bei [s6].
class RiegelSpacing {
  const RiegelSpacing._();

  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
}

class RiegelRadii {
  const RiegelRadii._();

  static const sm = 6.0;
  static const md = 10.0; // Buttons, Eingabefelder
  static const lg = 14.0; // Karten
  static const xl = 18.0; // Statuskachel
  static const xxl = 24.0;
  static const pill = 999.0;
}

/// Zahlen, die sich bewegen, laufen in Mono — sonst zappelt die Zeile bei jedem
/// Sekundenwechsel. Gilt für Countdown und Notfall-Code.
///
/// `monospace` ist der von Android gelieferte Alias; damit braucht die App keine
/// eigenen Schriftdateien. Die im Design System genannte JetBrains Mono würde
/// gebündelte TTFs voraussetzen.
const kMonoFamily = 'monospace';

ThemeData buildRiegelTheme() {
  const scheme = ColorScheme.dark(
    primary: RiegelColors.accent,
    onPrimary: RiegelColors.fgOnAccent,
    primaryContainer: RiegelColors.accentTint2,
    onPrimaryContainer: RiegelColors.accentBright,
    secondary: RiegelColors.locked,
    onSecondary: RiegelColors.fgOnLocked,
    secondaryContainer: RiegelColors.lockedTint,
    onSecondaryContainer: RiegelColors.lockedBright,
    surface: RiegelColors.bgCanvas,
    onSurface: RiegelColors.fg1,
    surfaceContainerHighest: RiegelColors.bgElev2,
    surfaceContainer: RiegelColors.bgElev1,
    onSurfaceVariant: RiegelColors.fg2,
    outline: RiegelColors.borderStrong,
    outlineVariant: RiegelColors.borderDefault,
    error: RiegelColors.danger,
    onError: Color(0xFF2A0508),
    errorContainer: RiegelColors.dangerDim,
    onErrorContainer: RiegelColors.dangerText,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: RiegelColors.bgBase,
    // Schriftskala aus dem Design System. Familie bleibt die des Systems —
    // DM Sans bräuchte gebündelte Schriftdateien.
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
        color: RiegelColors.fg1,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        height: 1.15,
        color: RiegelColors.fg1,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: RiegelColors.fg1,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: RiegelColors.fg1,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: RiegelColors.fg1),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: RiegelColors.fg2),
      bodySmall: TextStyle(fontSize: 13, height: 1.5, color: RiegelColors.fg2),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: RiegelColors.fg1,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        letterSpacing: 0.6,
        color: RiegelColors.fg3,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RiegelColors.bgBase,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: RiegelColors.fg1,
      ),
    ),
    // Karten tragen einen Hairline-Rahmen statt Schatten: auf so dunklen Flächen
    // wirken Schatten wie Schmutz.
    cardTheme: CardThemeData(
      color: RiegelColors.bgElev1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RiegelRadii.lg),
        side: const BorderSide(color: RiegelColors.borderDefault),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: RiegelColors.fg3,
      textColor: RiegelColors.fg1,
    ),
    dividerTheme: const DividerThemeData(
      color: RiegelColors.borderSubtle,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RiegelColors.accent,
        foregroundColor: RiegelColors.fgOnAccent,
        disabledBackgroundColor: RiegelColors.bgElev2,
        disabledForegroundColor: RiegelColors.fg4,
        padding: const EdgeInsets.symmetric(
          horizontal: RiegelSpacing.s5,
          vertical: RiegelSpacing.s3,
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RiegelRadii.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RiegelColors.accent,
        disabledForegroundColor: RiegelColors.fg4,
        side: const BorderSide(color: RiegelColors.borderStrong),
        padding: const EdgeInsets.symmetric(
          horizontal: RiegelSpacing.s5,
          vertical: RiegelSpacing.s3,
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RiegelRadii.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RiegelColors.accent,
        disabledForegroundColor: RiegelColors.fg4,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return RiegelColors.accentTint2;
          }
          return RiegelColors.bgElev1;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return RiegelColors.fg4;
          if (states.contains(WidgetState.selected)) {
            return RiegelColors.accentBright;
          }
          return RiegelColors.fg2;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: RiegelColors.borderDefault),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RiegelRadii.pill),
          ),
        ),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: RiegelColors.accent,
      inactiveTrackColor: RiegelColors.bgElev3,
      thumbColor: RiegelColors.accent,
      disabledActiveTrackColor: RiegelColors.fg4,
      disabledInactiveTrackColor: RiegelColors.bgElev2,
      disabledThumbColor: RiegelColors.fg4,
      trackHeight: 4,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return RiegelColors.accent;
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(RiegelColors.fgOnAccent),
      side: const BorderSide(color: RiegelColors.borderStrong, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RiegelRadii.sm),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RiegelColors.bgElev1,
      hintStyle: const TextStyle(color: RiegelColors.fg3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RiegelRadii.md),
        borderSide: const BorderSide(color: RiegelColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RiegelRadii.md),
        borderSide: const BorderSide(color: RiegelColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RiegelRadii.md),
        borderSide: const BorderSide(color: RiegelColors.accent, width: 1.5),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: RiegelColors.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: RiegelColors.bgElev3,
      contentTextStyle: const TextStyle(color: RiegelColors.fg1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RiegelRadii.md),
      ),
    ),
  );
}

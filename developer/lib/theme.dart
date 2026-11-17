// Fridge Mate look: "Shelves" (design direction C). Big rounded Nunito
// type, the ShelfLife forest and leaf greens, pastel category colours and
// soft 24 px corners — in light and dark versions.
//
// Screens read colours from [AppPalette] (context.palette) rather than
// fixed values, so they follow the chosen theme.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ShelfLife brand colours, taken from the company logo.
const Color brandForest = Color(0xFF12332D);
const Color brandLeaf = Color(0xFF6BD28B);

/// Fixed supporting colours (same in both themes).
const Color inkOnLeaf = Color(0xFF0E2A25); // text on leaf green
const Color forestLight = Color(0xFFCFE3DC); // muted text on forest
const Color urgentRed = Color(0xFFC0392B);
const Color urgentSoft = Color(0xFFFF8A7A);
const Color warnAmber = Color(0xFFD98A00);

/// Light-theme colours, kept for the few places that are always light.
const Color appBackground = Color(0xFFFBFCFA);
const Color softSurface = Color(0xFFEEF3EE);
const Color mutedText = Color(0xFF56706A);

// ---------------------------------------------------------------------------
// Theme choice (System / Light / Dark), saved on the device
// ---------------------------------------------------------------------------

/// The user's theme choice. The app rebuilds when it changes.
final ValueNotifier<ThemeMode> themeModeSetting =
    ValueNotifier(ThemeMode.system);

const _themeKey = 'themeMode';

/// Loads the saved choice; call once at startup.
Future<void> loadThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    themeModeSetting.value = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  } catch (e) {
    debugPrint('Could not load theme setting: $e');
  }
}

/// Applies and saves a new choice.
Future<void> setThemeMode(ThemeMode mode) async {
  themeModeSetting.value = mode;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  } catch (e) {
    debugPrint('Could not save theme setting: $e');
  }
}

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// Background/foreground pair, e.g. for an expiry pill.
class Tone {
  final Color bg;
  final Color fg;
  const Tone(this.bg, this.fg);

  static Tone lerp(Tone a, Tone b, double t) =>
      Tone(Color.lerp(a.bg, b.bg, t)!, Color.lerp(a.fg, b.fg, t)!);
}

/// The app's named colours, with a light and a dark set.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color card;
  final Color cardBorder;
  final Color soft; // chips, inputs, round icon buttons
  final Color ink; // main text
  final Color muted; // secondary text
  final Color hero; // forest feature cards and the nav pill
  final Color onHero;
  final Color onHeroMuted;
  final Color heroTrack; // progress track on hero cards
  final Color link;
  final Color selected; // selected chip / tab
  final Color onSelected;
  final Tone fresh; // 4+ days
  final Tone soon; // 1–3 days
  final Tone urgent; // today / expired
  final Map<String, Color> shelves;

  const AppPalette({
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.soft,
    required this.ink,
    required this.muted,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroTrack,
    required this.link,
    required this.selected,
    required this.onSelected,
    required this.fresh,
    required this.soon,
    required this.urgent,
    required this.shelves,
  });

  /// Pastel shelf colour for a fridge category.
  Color shelf(String? category) => shelves[category] ?? shelves['Other']!;

  static const light = AppPalette(
    background: appBackground,
    card: Colors.white,
    cardBorder: Color(0xFFE6ECE6),
    soft: softSurface,
    ink: brandForest,
    muted: mutedText,
    hero: brandForest,
    onHero: Colors.white,
    onHeroMuted: forestLight,
    heroTrack: Color(0xFF2E6157),
    link: Color(0xFF1E7A43),
    selected: brandForest,
    onSelected: Colors.white,
    fresh: Tone(Color(0xFFDDF3E3), Color(0xFF1E6A3B)),
    soon: Tone(Color(0xFFFFF1D6), Color(0xFF7A4F00)),
    urgent: Tone(Color(0xFFFBE1DF), urgentRed),
    shelves: {
      'Vegetables': Color(0xFFDDF3E3),
      'Fruits': Color(0xFFFCE3F0),
      'Meat & Chicken': Color(0xFFFBE1DF),
      'Seafood': Color(0xFFDCEBFA),
      'Dairy': Color(0xFFE3EEFB),
      'Eggs': Color(0xFFFFF1D6),
      'Leftovers': Color(0xFFFFE8D6),
      'Other': Color(0xFFECEAF7),
    },
  );

  static const dark = AppPalette(
    background: Color(0xFF0F1E1B),
    card: Color(0xFF172B27),
    cardBorder: Color(0xFF24403A),
    soft: Color(0xFF22403A),
    ink: Color(0xFFE7F2EE),
    muted: Color(0xFFA3BDB5),
    hero: Color(0xFF1F4A41),
    onHero: Colors.white,
    onHeroMuted: forestLight,
    heroTrack: Color(0xFF2F6458),
    link: Color(0xFF7FDB9C),
    selected: brandLeaf,
    onSelected: inkOnLeaf,
    fresh: Tone(Color(0xFF1F4031), Color(0xFF8FE0A8)),
    soon: Tone(Color(0xFF47391F), Color(0xFFF2C46B)),
    urgent: Tone(Color(0xFF46292A), Color(0xFFFF9A8C)),
    shelves: {
      'Vegetables': Color(0xFF1F4031),
      'Fruits': Color(0xFF43263A),
      'Meat & Chicken': Color(0xFF46292A),
      'Seafood': Color(0xFF1F3448),
      'Dairy': Color(0xFF24364A),
      'Eggs': Color(0xFF47391F),
      'Leftovers': Color(0xFF48331F),
      'Other': Color(0xFF2E2B45),
    },
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: c(background, other.background),
      card: c(card, other.card),
      cardBorder: c(cardBorder, other.cardBorder),
      soft: c(soft, other.soft),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      hero: c(hero, other.hero),
      onHero: c(onHero, other.onHero),
      onHeroMuted: c(onHeroMuted, other.onHeroMuted),
      heroTrack: c(heroTrack, other.heroTrack),
      link: c(link, other.link),
      selected: c(selected, other.selected),
      onSelected: c(onSelected, other.onSelected),
      fresh: Tone.lerp(fresh, other.fresh, t),
      soon: Tone.lerp(soon, other.soon, t),
      urgent: Tone.lerp(urgent, other.urgent, t),
      shelves: {
        for (final k in shelves.keys)
          k: c(shelves[k]!, other.shelves[k] ?? shelves[k]!),
      },
    );
  }
}

extension PaletteContext on BuildContext {
  /// The current theme's named colours.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

// ---------------------------------------------------------------------------
// Type
// ---------------------------------------------------------------------------

const double _radius = 24;

/// Nunito, the app's typeface, at any weight.
TextStyle appFont({
  TextStyle? textStyle,
  FontWeight? fontWeight,
  double? fontSize,
  Color? color,
}) => GoogleFonts.nunito(
  textStyle: textStyle,
  fontWeight: fontWeight,
  fontSize: fontSize,
  color: color,
);

// ---------------------------------------------------------------------------
// Themes
// ---------------------------------------------------------------------------

ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final p = dark ? AppPalette.dark : AppPalette.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: brandForest,
    brightness: brightness,
    primary: dark ? brandLeaf : brandForest,
    onPrimary: dark ? inkOnLeaf : Colors.white,
    secondary: brandLeaf,
    onSecondary: inkOnLeaf,
    // Selected chips and tonal buttons.
    secondaryContainer: p.selected,
    onSecondaryContainer: p.onSelected,
    surface: p.background,
    onSurface: p.ink,
    surfaceContainerHighest: p.soft,
    outline: p.muted,
    error: dark ? const Color(0xFFFF9A8C) : urgentRed,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );
  final t = base.textTheme;

  // Each style gets Nunito at its final weight (google_fonts loads one font
  // file per weight, so the weight must be set here, not afterwards).
  TextStyle n(TextStyle? s, FontWeight w, [Color? color]) => appFont(
    textStyle: s?.copyWith(color: color ?? p.ink),
    fontWeight: w,
  );

  final textTheme = TextTheme(
    displayLarge: n(t.displayLarge, FontWeight.w900),
    displayMedium: n(t.displayMedium, FontWeight.w900),
    displaySmall: n(t.displaySmall, FontWeight.w900),
    headlineLarge: n(t.headlineLarge, FontWeight.w900),
    headlineMedium: n(t.headlineMedium, FontWeight.w900),
    headlineSmall: n(t.headlineSmall, FontWeight.w900),
    titleLarge: n(t.titleLarge, FontWeight.w900),
    titleMedium: n(t.titleMedium, FontWeight.w800),
    titleSmall: n(t.titleSmall, FontWeight.w800),
    bodyLarge: n(t.bodyLarge, FontWeight.w600),
    bodyMedium: n(t.bodyMedium, FontWeight.w600),
    bodySmall: n(t.bodySmall, FontWeight.w600, p.muted),
    labelLarge: n(t.labelLarge, FontWeight.w800),
    labelMedium: n(t.labelMedium, FontWeight.w700),
    labelSmall: n(t.labelSmall, FontWeight.w700),
  );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_radius),
  );

  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall?.copyWith(fontSize: 28),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      shape: rounded.copyWith(side: BorderSide(color: p.cardBorder)),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.soft,
      selectedColor: p.selected,
      disabledColor: p.soft,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
      // Contrasting label on the selected chip.
      labelStyle: textTheme.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.onSelected : p.ink,
        ),
      ),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: p.onSelected),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        side: BorderSide(color: p.ink),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.link,
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.ink),
    ),
    iconTheme: IconThemeData(color: p.ink),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: brandLeaf,
      foregroundColor: inkOnLeaf,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.soft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: p.soft,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: textTheme.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      modalBackgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(color: p.card),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? p.hero : brandForest,
      actionTextColor: brandLeaf,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.onSelected,
      unselectedLabelColor: p.ink,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge,
      dividerHeight: 0,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: p.selected,
        borderRadius: BorderRadius.circular(20),
      ),
      splashBorderRadius: BorderRadius.circular(20),
    ),
    listTileTheme: ListTileThemeData(iconColor: p.ink, textColor: p.ink),
    dividerTheme: DividerThemeData(color: p.cardBorder),
  );
}

// ---------------------------------------------------------------------------
// Brand marks
// ---------------------------------------------------------------------------

/// The Fridge Mate app icon ("Fresh Shelf"), as a rounded tile.
class FridgeMateIcon extends StatelessWidget {
  final double size;
  const FridgeMateIcon({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icon/fridge_mate_icon.png',
    width: size,
    height: size,
    semanticLabel: 'Fridge Mate',
  );
}

/// The ShelfLife company wordmark. The image has its own forest-green
/// background, so it sits on [brandForest] without visible edges.
class ShelfLifeLogo extends StatelessWidget {
  final double height;
  const ShelfLifeLogo({super.key, this.height = 72});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/shelflife_logo.png',
    height: height,
    semanticLabel: 'ShelfLife',
  );
}

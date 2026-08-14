import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

/// -----------------------------------------------------------------------
/// AppTheme
/// -----------------------------------------------------------------------
/// Single source of truth for every color, radius, spacing and component
/// style used across the app. Screens should NEVER hardcode a `Color(...)`
/// or a raw `Colors.xxx` value — pull everything from `Theme.of(context)`
/// (colorScheme, textTheme, cardTheme, etc.) or from the [AppColors]
/// extension exposed via `AppTheme.colorsOf(context)`.
/// -----------------------------------------------------------------------
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------
  // Brand / semantic colors (theme-independent — same meaning everywhere)
  // ---------------------------------------------------------------------
  static const Color arahPurple = Color(
    0xFF6C63FF,
  ); // legacy alias, kept for compatibility
  static const Color primaryLight = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF7C6BFF);
  static const Color accentDark = Color(0xFF8B7BFF);
  static const Color successGreen = Color(0xFF10B981);
  static const Color successGreenDark = Color(0xFF16A34A);
  static const Color successBgLight = Color(0xFFF0FDF4);
  static const Color successBorderLight = Color(0xFFBBF7D0);
  static const Color _lightBorder = Color(0xFFE5E7EB);
  static const Color alertRed = Color(0xFFEF4444);
  static const Color alertRedDark = Color(0xFFDC2626);
  static const Color alertRedBgLight = Color(0xFFFEE2E2);

  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberBgLight = Color(0xFFFEF3C7);

  static const Color infoBlue = Color(0xFF3B82F6);

  // Legacy aliases kept so any remaining references keep compiling.
  static const Color navyBlue = Color(0xFF111827);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFFAFAFC);

  // ---------------------------------------------------------------------
  // Light theme tokens
  // ---------------------------------------------------------------------
  static const Color _lightBackground = Color(0xFFFAFAFC);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightMainText = Color(0xFF111111);
  static const Color _lightSecondaryText = Color(0xFF5F6368);
  static const Color _lightSearchBg = Color(0xFFF7F7F8);
  static const Color _lightChipBg = Color(0xFFF1F3F5);
  static const Color _lightChipSelectedBg = Color(0xFFE8E7FF);
  // ---------------------------------------------------------------------
  // Dark theme tokens
  // ---------------------------------------------------------------------
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkCard = Color(0xFF242424);
  static const Color _darkMainText = Color(0xFFFFFFFF);
  static const Color _darkSecondaryText = Color(0xFFB3B3B3);
  static const Color _darkBorder = Color(0xFF353535);
  static const Color _darkSearchBg = Color(0xFF252A35);
  static const Color _darkChipUnselected = Color(0xFF102A43);
  static const Color _darkChipSelected = Color(0xFF163A5F);
  // ---------------------------------------------------------------------
  // Radii & spacing — kept centralized so every screen stays consistent.
  // ---------------------------------------------------------------------
  static const double radiusCard = 22;
  static const double radiusButton = 18;
  static const double radiusSearch = 18;
  static const double radiusChip = 18;
  static const double radiusDialog = 24;
  static const double radiusSheet = 28;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 20);

  /// Convenience accessor: `AppTheme.colorsOf(context).cardColor` etc.
  static AppColors colorsOf(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? AppColors.light;

  // Helper to hide scrollbars globally
  static const ScrollBehavior noScrollbarBehavior = ScrollBehavior();

  // =======================================================================
  // LIGHT THEME
  // =======================================================================
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: primaryLight,
      onPrimary: Colors.white,
      secondary: primaryLight,
      onSecondary: Colors.white,
      surface: _lightCard,
      onSurface: _lightMainText,
      surfaceContainerHighest: _lightSearchBg,
      onSurfaceVariant: _lightSecondaryText,
      outline: _lightBorder,
      outlineVariant: _lightBorder,
      error: alertRed,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      brightness: Brightness.light,
    );

    return base.copyWith(
      brightness: Brightness.light,
      useMaterial3: true,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: _lightBackground,
      canvasColor: _lightBackground,
      cardColor: _lightCard,
      dividerColor: _lightBorder,
      shadowColor: Colors.black.withOpacity(0.08),
      splashColor: primaryLight.withOpacity(0.08),
      highlightColor: Colors.transparent,
      colorScheme: colorScheme,
      extensions: const [AppColors.light],

      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBackground,
        foregroundColor: _lightMainText,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: _lightMainText),
        actionsIconTheme: IconThemeData(color: _lightMainText),
        titleTextStyle: TextStyle(
          color: _lightMainText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      textTheme: base.textTheme
          .apply(
            bodyColor: _lightMainText,
            displayColor: _lightMainText,
            fontFamily: 'Poppins',
          )
          .copyWith(
            headlineLarge: const TextStyle(
              color: _lightMainText,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            headlineMedium: const TextStyle(
              color: _lightMainText,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            titleLarge: const TextStyle(
              color: _lightMainText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            titleMedium: const TextStyle(
              color: _lightMainText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(color: _lightMainText, fontSize: 16),
            bodyMedium: const TextStyle(
              color: _lightSecondaryText,
              fontSize: 14,
            ),
            bodySmall: const TextStyle(
              color: _lightSecondaryText,
              fontSize: 12,
            ),
            labelLarge: const TextStyle(
              color: _lightMainText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

      iconTheme: const IconThemeData(color: _lightMainText, size: 24),

      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryLight.withOpacity(0.4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 52),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightMainText,
          side: const BorderSide(color: _lightBorder, width: 1.4),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 52),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: _lightMainText),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        focusElevation: 4,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSearchBg,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 18,
        ),
        hintStyle: const TextStyle(color: _lightSecondaryText, fontSize: 14),
        labelStyle: const TextStyle(color: _lightSecondaryText, fontSize: 14),
        prefixIconColor: _lightSecondaryText,
        suffixIconColor: _lightSecondaryText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: const BorderSide(color: primaryLight, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: const BorderSide(color: alertRed, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: const BorderSide(color: alertRed, width: 1.6),
        ),
        errorStyle: const TextStyle(color: alertRed, fontSize: 12),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: _lightChipBg,
        selectedColor: _lightChipSelectedBg,
        disabledColor: _lightChipBg,
        labelStyle: const TextStyle(
          color: _lightMainText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: _lightMainText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusChip),
        ),
        side: BorderSide.none,
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),

      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.15),
        titleTextStyle: const TextStyle(
          color: _lightMainText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: _lightSecondaryText,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusDialog),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _lightCard,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: _lightCard,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
        dragHandleColor: _lightBorder,
        showDragHandle: true,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightMainText,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: primaryLight.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return primaryLight;
          return const Color(0xFFD1D5DB);
        }),
        trackOutlineColor: const MaterialStatePropertyAll(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return primaryLight;
          return Colors.transparent;
        }),
        checkColor: const MaterialStatePropertyAll(Colors.white),
        side: const BorderSide(color: _lightBorder, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return primaryLight;
          return _lightSecondaryText;
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: primaryLight,
        unselectedLabelColor: _lightSecondaryText,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: primaryLight,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: _lightBorder,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lightCard,
        selectedItemColor: primaryLight,
        unselectedItemColor: _lightSecondaryText,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightCard,
        indicatorColor: primaryLight.withOpacity(0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final selected = states.contains(MaterialState.selected);
          return IconThemeData(
            color: selected ? primaryLight : _lightSecondaryText,
          );
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final selected = states.contains(MaterialState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? primaryLight : _lightSecondaryText,
          );
        }),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: _lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.1),
        textStyle: const TextStyle(color: _lightMainText, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _lightBorder),
        ),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const MaterialStatePropertyAll(_lightCard),
          surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(color: _lightMainText, fontSize: 14),
        menuStyle: MenuStyle(
          backgroundColor: const MaterialStatePropertyAll(_lightCard),
          surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _lightSearchBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSearch),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryLight,
        linearTrackColor: _lightChipBg,
        circularTrackColor: _lightChipBg,
      ),

      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: _lightSecondaryText,
        textColor: _lightMainText,
        tileColor: Colors.transparent,
        selectedTileColor: primaryLight.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _lightMainText,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),

      badgeTheme: const BadgeThemeData(
        backgroundColor: alertRed,
        textColor: Colors.white,
      ),
    );
  }

  // =======================================================================
  // DARK THEME
  // =======================================================================
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: primaryDark,
      onPrimary: Colors.white,
      secondary: accentDark,
      onSecondary: Colors.white,
      surface: _darkCard,
      onSurface: _darkMainText,
      surfaceContainerHighest: _darkSearchBg,
      onSurfaceVariant: _darkSecondaryText,
      outline: _darkBorder,
      outlineVariant: _darkBorder,
      error: alertRed,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      brightness: Brightness.dark,
    );

    return base.copyWith(
      brightness: Brightness.dark,
      useMaterial3: true,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: _darkBackground,
      canvasColor: _darkBackground,
      cardColor: _darkCard,
      dividerColor: _darkBorder,
      shadowColor: Colors.black.withOpacity(0.4),
      splashColor: primaryDark.withOpacity(0.12),
      highlightColor: Colors.transparent,
      colorScheme: colorScheme,
      extensions: const [AppColors.dark],

      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: _darkMainText,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: _darkMainText),
        actionsIconTheme: IconThemeData(color: _darkMainText),
        titleTextStyle: TextStyle(
          color: _darkMainText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      textTheme: base.textTheme
          .apply(
            bodyColor: const Color.fromARGB(255, 255, 255, 255),
            displayColor: const Color.fromARGB(255, 255, 255, 255),
            fontFamily: 'Poppins',
          )
          .copyWith(
            headlineLarge: const TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            headlineMedium: const TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            titleLarge: const TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            titleMedium: const TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(color: _darkMainText, fontSize: 16),
            bodyMedium: const TextStyle(
              color: _darkSecondaryText,
              fontSize: 14,
            ),
            bodySmall: const TextStyle(color: _darkSecondaryText, fontSize: 12),
            labelLarge: const TextStyle(
              color: _darkMainText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

      iconTheme: const IconThemeData(color: _darkMainText, size: 24),

      cardTheme: CardThemeData(
        color: const Color.fromARGB(255, 22, 20, 20),
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: const Color.fromARGB(255, 24, 24, 24),
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(
            color: Color.fromARGB(255, 40, 39, 39),
            width: 1,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryDark.withOpacity(0.35),
          disabledForegroundColor: Colors.white54,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 52),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkMainText,
          side: const BorderSide(color: _darkBorder, width: 1.4),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 52),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentDark,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: _darkMainText),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        focusElevation: 4,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSearchBg,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 18,
        ),
        hintStyle: const TextStyle(color: _darkSecondaryText, fontSize: 14),
        labelStyle: const TextStyle(color: _darkSecondaryText, fontSize: 14),
        prefixIconColor: _darkSecondaryText,
        suffixIconColor: _darkSecondaryText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: const BorderSide(color: primaryDark, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: const BorderSide(color: alertRed, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSearch),
          borderSide: const BorderSide(color: alertRed, width: 1.6),
        ),
        errorStyle: const TextStyle(color: alertRed, fontSize: 12),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E293B),
        selectedColor: const Color(0xFF334155),
        disabledColor: _darkChipUnselected,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusChip),
        ),
        side: BorderSide.none,
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: _darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.5),
        titleTextStyle: const TextStyle(
          color: _darkMainText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: _darkSecondaryText,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusDialog),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _darkCard,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: _darkCard,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
        dragHandleColor: _darkBorder,
        showDragHandle: true,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurface,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: accentDark,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _darkBorder),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const MaterialStatePropertyAll(Colors.white),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color.fromARGB(255, 96, 86, 173);
          }
          return const Color(0xFF4B4B4B);
        }),
        trackOutlineColor: const MaterialStatePropertyAll(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color.fromARGB(255, 96, 86, 173);
          }
          return Colors.transparent;
        }),
        checkColor: const MaterialStatePropertyAll(Colors.white),
        side: const BorderSide(color: _darkBorder, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return primaryDark;
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: accentDark,
        unselectedLabelColor: _darkSecondaryText,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: primaryDark,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: _darkBorder,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkCard,
        selectedItemColor: accentDark,
        unselectedItemColor: _darkSecondaryText,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkCard,
        indicatorColor: primaryDark.withOpacity(0.2),
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final selected = states.contains(MaterialState.selected);
          return IconThemeData(
            color: selected ? accentDark : _darkSecondaryText,
          );
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final selected = states.contains(MaterialState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? accentDark : _darkSecondaryText,
          );
        }),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: _darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.4),
        textStyle: const TextStyle(color: _darkMainText, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorder),
        ),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const MaterialStatePropertyAll(_darkCard),
          surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(color: _darkMainText, fontSize: 14),
        menuStyle: MenuStyle(
          backgroundColor: const MaterialStatePropertyAll(_darkCard),
          surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _darkSearchBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSearch),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryDark,
        linearTrackColor: _darkChipUnselected,
        circularTrackColor: _darkChipUnselected,
      ),

      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: _darkSecondaryText,
        textColor: _darkMainText,
        tileColor: Colors.transparent,
        selectedTileColor: primaryDark.withOpacity(0.14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _darkSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _darkBorder),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),

      badgeTheme: const BadgeThemeData(
        backgroundColor: alertRed,
        textColor: Colors.white,
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// AppColors
/// -----------------------------------------------------------------------
/// A [ThemeExtension] carrying the semantic tokens that don't map 1:1 onto
/// Flutter's built-in [ColorScheme] (search field fill, chip states,
/// success/warning colors, etc). Access via `AppTheme.colorsOf(context)`.
/// -----------------------------------------------------------------------
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color card;
  final Color mainText;
  final Color secondaryText;
  final Color border;
  final Color searchBackground;
  final Color chipBackground;
  final Color chipSelectedBackground;
  final Color chipSelectedText;
  final Color chipText;
  final Color success;
  final Color successBackground;
  final Color error;
  final Color errorBackground;
  final Color warning;
  final Color warningBackground;
  final Color info;
  final Color shadow;

  const AppColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.mainText,
    required this.secondaryText,
    required this.border,
    required this.searchBackground,
    required this.chipBackground,
    required this.chipSelectedBackground,
    required this.chipSelectedText,
    required this.chipText,
    required this.success,
    required this.successBackground,
    required this.error,
    required this.errorBackground,
    required this.warning,
    required this.warningBackground,
    required this.info,
    required this.shadow,
  });

  static const light = AppColors(
    background: Color(0xFFFAFAFC),
    surface: Colors.white,
    card: Colors.white,
    border: Color(0xFFE5E7EB),
    searchBackground: Color(0xFFF3F4F6),
    chipBackground: Color(0xFFF3F4F6),
    mainText: Color(0xFF111111),
    secondaryText: Color(0xFF5F6368),
    chipSelectedBackground: Color(0xFFE8E7FF),
    chipSelectedText: Color(0xFF111111),
    chipText: Color(0xFF111111),
    success: AppTheme.successGreen,
    successBackground: AppTheme.successBgLight,
    error: AppTheme.alertRed,
    errorBackground: AppTheme.alertRedBgLight,
    warning: AppTheme.warningAmber,
    warningBackground: AppTheme.warningAmberBgLight,
    info: AppTheme.infoBlue,
    shadow: Color(0x14000000),
  );

  static const dark = AppColors(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    card: Color(0xFF242424),
    mainText: Colors.white,
    secondaryText: Color(0xFFB3B3B3),
    border: Color(0xFF353535),
    searchBackground: Color(0xFF2A2A2A),
    chipBackground: Color(0xFF1E293B),
    chipSelectedBackground: Color(0xFF334155),
    chipSelectedText: Colors.white,
    chipText: Colors.white,
    success: AppTheme.successGreen,
    successBackground: Color(0x2610B981),
    error: AppTheme.alertRed,
    errorBackground: Color(0x26EF4444),
    warning: AppTheme.warningAmber,
    warningBackground: Color(0x26F59E0B),
    info: AppTheme.infoBlue,
    shadow: Color(0x40000000),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? mainText,
    Color? secondaryText,
    Color? border,
    Color? searchBackground,
    Color? chipBackground,
    Color? chipSelectedBackground,
    Color? chipSelectedText,
    Color? chipText,
    Color? success,
    Color? successBackground,
    Color? error,
    Color? errorBackground,
    Color? warning,
    Color? warningBackground,
    Color? info,
    Color? shadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      mainText: mainText ?? this.mainText,
      secondaryText: secondaryText ?? this.secondaryText,
      border: border ?? this.border,
      searchBackground: searchBackground ?? this.searchBackground,
      chipBackground: chipBackground ?? this.chipBackground,
      chipSelectedBackground:
          chipSelectedBackground ?? this.chipSelectedBackground,
      chipSelectedText: chipSelectedText ?? this.chipSelectedText,
      chipText: chipText ?? this.chipText,
      success: success ?? this.success,
      successBackground: successBackground ?? this.successBackground,
      error: error ?? this.error,
      errorBackground: errorBackground ?? this.errorBackground,
      warning: warning ?? this.warning,
      warningBackground: warningBackground ?? this.warningBackground,
      info: info ?? this.info,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      mainText: Color.lerp(mainText, other.mainText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      border: Color.lerp(border, other.border, t)!,
      searchBackground: Color.lerp(
        searchBackground,
        other.searchBackground,
        t,
      )!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      chipSelectedBackground: Color.lerp(
        chipSelectedBackground,
        other.chipSelectedBackground,
        t,
      )!,
      chipSelectedText: Color.lerp(
        chipSelectedText,
        other.chipSelectedText,
        t,
      )!,
      chipText: Color.lerp(chipText, other.chipText, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBackground: Color.lerp(
        successBackground,
        other.successBackground,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      errorBackground: Color.lerp(errorBackground, other.errorBackground, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBackground: Color.lerp(
        warningBackground,
        other.warningBackground,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

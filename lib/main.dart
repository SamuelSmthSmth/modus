import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/app_navigator.dart';
import 'core/settings_provider.dart';
import 'features/online/online_provider.dart';
import 'features/stats/stats_provider.dart';
import 'features/tasks/task_provider.dart';
import 'features/timer/home_screen.dart';
import 'features/timer/timer_logic.dart';

void main() {
  runApp(const ModusApp());
}

class ModusApp extends StatelessWidget {
  const ModusApp({super.key});

  static const Color _lightBackground = Color(0xFFF6F7F9);
  static const Color _lightSurface = Color(0xFFFFFFFF);

  static const Color _ayuDarkBackground = Color(0xFF0B0E14);
  static const Color _ayuDarkSurface = Color(0xFF151A24);
  static const Color _ayuDarkSurfaceAlt = Color(0xFF1D2433);

  ThemeData _buildLightTheme(Color accentColor, String fontFamily) {
    final scheme = ColorScheme.light(
      primary: accentColor,
      secondary: accentColor,
      surface: _lightSurface,
      onSurface: const Color(0xFF1E222A),
      onSurfaceVariant: const Color(0xFF667085),
      outline: const Color(0xFFD7DDE5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: GoogleFonts.getFont(fontFamily).fontFamily,
      scaffoldBackgroundColor: _lightBackground,
      cardColor: _lightSurface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        hintStyle: const TextStyle(color: Color(0xFF667085)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7DDE5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor),
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
      ),
      dividerColor: const Color(0xFFE4E7EC),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentColor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1E222A),
          side: const BorderSide(color: Color(0xFFD7DDE5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  ThemeData _buildLayeredDarkTheme(
    Color accentColor,
    bool isOledMode,
    String fontFamily,
  ) {
    final darkBackground = isOledMode
        ? const Color(0xFF000000)
        : _ayuDarkBackground;
    final darkSurface = isOledMode ? const Color(0xFF0A0A0A) : _ayuDarkSurface;
    final darkDivider = isOledMode
        ? const Color(0xFF111111)
        : _ayuDarkSurfaceAlt;
    final scheme = ColorScheme.dark(
      primary: accentColor,
      secondary: accentColor,
      surface: darkSurface,
      onSurface: const Color(0xFFE6E1CF),
      onSurfaceVariant: const Color(0xFF9AA4B2),
      outline: const Color(0xFF2A3242),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: GoogleFonts.getFont(fontFamily).fontFamily,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkSurface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle: const TextStyle(color: Color(0xFF9AA4B2)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A3242)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkDivider),
        ),
      ),
      dividerColor: darkDivider,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkBackground,
        selectedItemColor: const Color(0xFFE6E1CF),
        unselectedItemColor: const Color(0xFF9AA4B2),
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentColor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE6E1CF),
          side: const BorderSide(color: Color(0xFF2A3242)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<TaskProvider>(create: (_) => TaskProvider()),
        ChangeNotifierProvider<StatsProvider>(create: (_) => StatsProvider()),
        ChangeNotifierProxyProvider3<
          TaskProvider,
          SettingsProvider,
          StatsProvider,
          TimerProvider
        >(
          create: (_) => TimerProvider()..loadTimerState(),
          update:
              (
                _,
                taskProvider,
                settingsProvider,
                statsProvider,
                timerProvider,
              ) {
                final provider = timerProvider ?? TimerProvider();
                provider.attachTaskProvider(taskProvider);
                provider.attachSettingsProvider(settingsProvider);
                provider.attachStatsProvider(statsProvider);
                return provider;
              },
        ),
        ChangeNotifierProxyProvider3<
          TimerProvider,
          TaskProvider,
          SettingsProvider,
          OnlineProvider
        >(
          create: (context) => OnlineProvider(
            timerProvider: context.read<TimerProvider>(),
            taskProvider: context.read<TaskProvider>(),
            settingsProvider: context.read<SettingsProvider>(),
          ),
          update:
              (
                _,
                timerProvider,
                taskProvider,
                settingsProvider,
                onlineProvider,
              ) {
                final provider =
                    onlineProvider ??
                    OnlineProvider(
                      timerProvider: timerProvider,
                      taskProvider: taskProvider,
                      settingsProvider: settingsProvider,
                    );

                provider.update(timerProvider, taskProvider);
                provider.updateSettings(settingsProvider);

                return provider;
              },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (_, settingsProvider, _) {
          final fontFamily = settingsProvider.selectedFontFamily;

          return MaterialApp(
            title: 'Modus',
            navigatorKey: navigatorKey,
            theme: _buildLightTheme(
              settingsProvider.currentAccentColor,
              fontFamily,
            ),
            darkTheme: _buildLayeredDarkTheme(
              settingsProvider.currentAccentColor,
              settingsProvider.isOledMode,
              fontFamily,
            ),
            themeMode: settingsProvider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'config/app_config.dart';
import 'screens/main_navigation.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig();
  await config.loadSettings();
  await NotificationService().init();
  runApp(
    ChangeNotifierProvider.value(
      value: config,
      child: const RejseNuApp(),
    ),
  );
}

class RejseNuApp extends StatelessWidget {
  const RejseNuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (config.isSystemAccentColor && lightDynamic != null && darkDynamic != null) {
          // Follow Material You system wallpaper dynamic color
          lightColorScheme = lightDynamic;
          darkColorScheme = darkDynamic;
        } else {
          // Custom accent color or fallback Danish red
          final seed = config.customAccentColor;
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'RejseNu',
          debugShowCheckedModeBanner: false,
          themeMode: config.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            cardTheme: const CardTheme(
              color: Colors.white,
              elevation: 1,
            ),
            appBarTheme: AppBarTheme(
              centerTitle: false,
              elevation: 0,
              scrolledUnderElevation: 2,
              backgroundColor: lightColorScheme.surface,
              foregroundColor: lightColorScheme.onSurface,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            cardTheme: const CardTheme(
              elevation: 1,
            ),
            appBarTheme: AppBarTheme(
              centerTitle: false,
              elevation: 0,
              scrolledUnderElevation: 2,
              backgroundColor: darkColorScheme.surface,
              foregroundColor: darkColorScheme.onSurface,
            ),
          ),
          home: const MainNavigation(),
        );
      },
    );
  }
}

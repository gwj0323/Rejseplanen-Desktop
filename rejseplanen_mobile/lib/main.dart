import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'screens/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppConfig(),
      child: const RejseplanenApp(),
    ),
  );
}

class RejseplanenApp extends StatelessWidget {
  const RejseplanenApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context);

    // Danish transit brand colors (DSB red & Nordic Blue)
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC72027),
      brightness: Brightness.light,
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC72027),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Rejseplanen',
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
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        cardTheme: const CardTheme(
          elevation: 1,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

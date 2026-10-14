import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../i18n/translations.dart';
import 'trip_screen.dart';
import 'board_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TripScreen(),
    BoardScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context);
    final isLiquidGlass = config.navBarStyle != 'material3';

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        extendBody: isLiquidGlass,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: isLiquidGlass
            ? _buildLiquidGlassBar(context)
            : _buildMaterial3Bar(context),
      ),
    );
  }

  Widget _buildMaterial3Bar(BuildContext context) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) {
        setState(() => _currentIndex = idx);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.directions_transit_outlined),
          selectedIcon: const Icon(Icons.directions_transit),
          label: I18n.t(context, "nav_trip"),
        ),
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: I18n.t(context, "nav_board"),
        ),
        NavigationDestination(
          icon: const Icon(Icons.star_outline),
          selectedIcon: const Icon(Icons.star),
          label: I18n.t(context, "nav_favorites"),
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: I18n.t(context, "nav_settings"),
        ),
      ],
    );
  }

  Widget _buildLiquidGlassBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final navItems = [
      (
        icon: Icons.directions_transit_outlined,
        activeIcon: Icons.directions_transit,
        label: I18n.t(context, "nav_trip"),
      ),
      (
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: I18n.t(context, "nav_board"),
      ),
      (
        icon: Icons.star_outline,
        activeIcon: Icons.star,
        label: I18n.t(context, "nav_favorites"),
      ),
      (
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: I18n.t(context, "nav_settings"),
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomPadding > 0 ? bottomPadding + 4 : 14,
      ),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
              blurRadius: 26,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: primaryColor.withOpacity(isDark ? 0.15 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                color: isDark
                    ? const Color(0xFF0F172A).withOpacity(0.72)
                    : Colors.white.withOpacity(0.72),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.white.withOpacity(0.65),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: List.generate(navItems.length, (idx) {
                  final item = navItems[idx];
                  final isSelected = _currentIndex == idx;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_currentIndex != idx) {
                          HapticFeedback.lightImpact();
                          setState(() => _currentIndex = idx);
                        }
                      },
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 12 : 6,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withOpacity(isDark ? 0.22 : 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                            border: isSelected
                                ? Border.all(
                                    color: primaryColor.withOpacity(isDark ? 0.35 : 0.22),
                                    width: 1.0,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: isSelected ? 1.08 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  size: 22,
                                  color: isSelected
                                      ? primaryColor
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? primaryColor
                                      : (isDark ? Colors.white60 : Colors.black54),
                                  letterSpacing: 0.1,
                                ),
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

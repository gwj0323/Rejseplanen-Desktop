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
      onPopInvoked: (didPop) {
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

    const double pillRadius = 33.0;

    // Specular gradient border imitating light reflecting off glass curvature
    final borderGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              Colors.white.withOpacity(0.48),
              Colors.white.withOpacity(0.14),
              Colors.white.withOpacity(0.04),
            ]
          : [
              Colors.white.withOpacity(0.85),
              Colors.white.withOpacity(0.35),
              Colors.white.withOpacity(0.12),
            ],
      stops: const [0.0, 0.45, 1.0],
    );

    // Highly translucent, refractive glass fill gradient (transparent enough for backdrop to show)
    final fillGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withOpacity(0.12),
              const Color(0xFF0F172A).withOpacity(0.20),
              const Color(0xFF1E293B).withOpacity(0.28),
            ]
          : [
              Colors.white.withOpacity(0.32),
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.22),
            ],
      stops: const [0.0, 0.55, 1.0],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomPadding > 0 ? bottomPadding + 6 : 16,
      ),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(pillRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.32 : 0.07),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: primaryColor.withOpacity(isDark ? 0.14 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 2),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(pillRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: CustomPaint(
              painter: GlassBorderPainter(
                strokeWidth: 1.5,
                radius: pillRadius,
                gradient: borderGradient,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(pillRadius),
                  gradient: fillGradient,
                ),
                child: Stack(
                  children: [
                    // Top interior specular curvature sheen
                    Positioned(
                      top: 1,
                      left: 24,
                      right: 24,
                      height: 1.2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(isDark ? 0.35 : 0.70),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Navigation items row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                    horizontal: isSelected ? 14 : 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    gradient: isSelected
                                        ? LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              primaryColor.withOpacity(isDark ? 0.28 : 0.16),
                                              primaryColor.withOpacity(isDark ? 0.12 : 0.07),
                                            ],
                                          )
                                        : null,
                                    border: isSelected
                                        ? Border.all(
                                            color: primaryColor.withOpacity(isDark ? 0.40 : 0.25),
                                            width: 1.0,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: primaryColor.withOpacity(isDark ? 0.20 : 0.08),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: isSelected ? 1.10 : 1.0,
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOutBack,
                                        child: Icon(
                                          isSelected ? item.activeIcon : item.icon,
                                          size: 22,
                                          color: isSelected
                                              ? primaryColor
                                              : (isDark ? Colors.white60 : const Color(0xFF64748B)),
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
                                              : (isDark ? Colors.white60 : const Color(0xFF64748B)),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that renders a smooth gradient stroke border around a rounded rectangle
class GlassBorderPainter extends CustomPainter {
  final double strokeWidth;
  final double radius;
  final Gradient gradient;

  GlassBorderPainter({
    required this.strokeWidth,
    required this.radius,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant GlassBorderPainter oldDelegate) => false;
}

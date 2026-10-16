import 'dart:math' as math;
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

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  late final AnimationController _dropletController;
  double _fromIndex = 0.0;
  double _toIndex = 0.0;
  double? _dragIndex;

  final List<Widget> _screens = const [
    TripScreen(),
    BoardScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _dropletController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _dropletController.dispose();
    super.dispose();
  }

  void _selectTab(int idx) {
    if (idx == _currentIndex && _dragIndex == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _fromIndex = _currentAnimatedIndex;
      _toIndex = idx.toDouble();
      _currentIndex = idx;
      _dragIndex = null;
    });
    _dropletController.forward(from: 0.0);
  }

  double get _currentAnimatedIndex {
    if (_dragIndex != null) return _dragIndex!;
    final t = Curves.easeOutCubic.transform(_dropletController.value);
    return ui.lerpDouble(_fromIndex, _toIndex, t) ?? _currentIndex.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context);
    final isLiquidGlass = config.navBarStyle != 'material3';

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentIndex != 0) {
          _selectTab(0);
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
      onDestinationSelected: _selectTab,
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

    const double barHeight = 64.0;
    const double pillRadius = 32.0;
    const double innerHorizontalPad = 5.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        bottomPadding > 0 ? bottomPadding + 6 : 16,
      ),
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(pillRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.28 : 0.08),
              blurRadius: 20,
              offset: Offset.zero,
              blurStyle: BlurStyle.outer,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(pillRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: 16.0,
              sigmaY: 16.0,
              tileMode: TileMode.clamp,
            ),
            child: CustomPaint(
              painter: LiquidGlassShellPainter(
                radius: pillRadius,
                isDark: isDark,
                isForeground: false,
              ),
              foregroundPainter: LiquidGlassShellPainter(
                radius: pillRadius,
                isDark: isDark,
                isForeground: true,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth - innerHorizontalPad * 2;
                  final tabWidth = totalWidth / navItems.length;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) {
                      _dropletController.stop();
                      final localX = (details.localPosition.dx - innerHorizontalPad)
                          .clamp(0.0, totalWidth);
                      setState(() {
                        _dragIndex = (localX / tabWidth - 0.5)
                            .clamp(0.0, (navItems.length - 1).toDouble());
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      final localX = (details.localPosition.dx - innerHorizontalPad)
                          .clamp(0.0, totalWidth);
                      final newDragIdx = (localX / tabWidth - 0.5)
                          .clamp(0.0, (navItems.length - 1).toDouble());
                      final nearestTab = newDragIdx.round();
                      if (nearestTab != _currentIndex) {
                        HapticFeedback.selectionClick();
                        _currentIndex = nearestTab;
                      }
                      setState(() {
                        _dragIndex = newDragIdx;
                      });
                    },
                    onHorizontalDragEnd: (_) {
                      final target = (_dragIndex ?? _currentIndex.toDouble()).round();
                      setState(() {
                        _fromIndex = _dragIndex ?? _currentIndex.toDouble();
                        _toIndex = target.toDouble();
                        _currentIndex = target;
                        _dragIndex = null;
                      });
                      _dropletController.forward(from: 0.0);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: innerHorizontalPad),
                      child: AnimatedBuilder(
                        animation: _dropletController,
                        builder: (context, _) {
                          final animIdx = _currentAnimatedIndex;
                          final rawProgress = _dropletController.isAnimating
                              ? _dropletController.value
                              : 0.0;
                          final stretchWave = math.sin(rawProgress * math.pi);
                          final scaleX = 1.0 + 0.08 * stretchWave;
                          final scaleY = 1.0 - 0.03 * stretchWave;

                          final dropletLeft = (animIdx * tabWidth).clamp(
                            0.0,
                            totalWidth - tabWidth,
                          );

                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // 1. Sliding Frosted Pill Indicator (clean uniform iOS 26 style)
                              Positioned(
                                left: dropletLeft,
                                top: 5,
                                bottom: 5,
                                width: tabWidth,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                                  child: CustomPaint(
                                    painter: LiquidDropletLensPainter(
                                      isDark: isDark,
                                      primaryColor: primaryColor,
                                    ),
                                  ),
                                ),
                              ),

                              // 2. Interactive Tab Icons & Labels
                              Row(
                                children: List.generate(navItems.length, (idx) {
                                  final item = navItems[idx];
                                  final proximity =
                                      (1.0 - (animIdx - idx).abs()).clamp(0.0, 1.0);

                                  final inactiveColor = isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B);
                                  final itemColor = Color.lerp(
                                    inactiveColor,
                                    primaryColor,
                                    proximity,
                                  )!;

                                  return Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _selectTab(idx),
                                      child: SizedBox(
                                        height: barHeight,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Transform.scale(
                                              scale: 1.0 + 0.06 * proximity,
                                              child: Icon(
                                                proximity > 0.5
                                                    ? item.activeIcon
                                                    : item.icon,
                                                size: 22,
                                                color: itemColor,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              item.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: proximity > 0.5
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: itemColor,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the outer capsule's uniform frosted glass fill and 0.8px hairline rim
class LiquidGlassShellPainter extends CustomPainter {
  final double radius;
  final bool isDark;
  final bool isForeground;

  LiquidGlassShellPainter({
    required this.radius,
    required this.isDark,
    required this.isForeground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    if (!isForeground) {
      // High-transparency uniform vertical frosted glass surface
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          isDark
              ? [
                  const Color(0xFF1E222D).withOpacity(0.28),
                  const Color(0xFF141720).withOpacity(0.36),
                ]
              : [
                  Colors.white.withOpacity(0.36),
                  const Color(0xFFF8FAFC).withOpacity(0.28),
                ],
        );
      canvas.drawRRect(rrect, fillPaint);
      return;
    }

    // Subtle 0.8px hairline specular border (top-to-bottom vertical light falloff)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        isDark
            ? [
                Colors.white.withOpacity(0.24),
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.12),
              ]
            : [
                Colors.white.withOpacity(0.85),
                Colors.black.withOpacity(0.05),
                Colors.black.withOpacity(0.08),
              ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(rrect.deflate(0.4), rimPaint);
  }

  @override
  bool shouldRepaint(covariant LiquidGlassShellPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.radius != radius ||
      oldDelegate.isForeground != isForeground;
}

/// Renders the clean, uniform frosted capsule behind the active tab (no plastic dome blob)
class LiquidDropletLensPainter extends CustomPainter {
  final bool isDark;
  final Color primaryColor;

  LiquidDropletLensPainter({
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.height / 2;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 1. Clean, uniform translucent pill fill (subtle vertical glass gradient)
    final bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        isDark
            ? [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.06),
              ]
            : [
                Colors.white.withOpacity(0.55),
                Colors.white.withOpacity(0.38),
              ],
      );
    canvas.drawRRect(rrect, bodyPaint);

    // 2. Very subtle primary color ambient tint
    final tintPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = primaryColor.withOpacity(isDark ? 0.10 : 0.08);
    canvas.drawRRect(rrect, tintPaint);

    // 3. Delicate 0.8px hairline rim on the active pill
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        isDark
            ? [
                Colors.white.withOpacity(0.24),
                Colors.white.withOpacity(0.05),
              ]
            : [
                Colors.white.withOpacity(0.90),
                Colors.black.withOpacity(0.04),
              ],
      );
    canvas.drawRRect(rrect.deflate(0.4), rimPaint);
  }

  @override
  bool shouldRepaint(covariant LiquidDropletLensPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.primaryColor != primaryColor;
}

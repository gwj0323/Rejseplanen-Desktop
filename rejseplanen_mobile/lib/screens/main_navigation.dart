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
    final t = Curves.easeOutBack.transform(_dropletController.value);
    return ui.lerpDouble(_fromIndex, _toIndex, t) ?? _currentIndex.toDouble();
  }

  /// Saturation matrix (boosts saturation ~1.35x like iOS UIVisualEffectView vibrancy)
  static const List<double> _vibrancyMatrix = <double>[
    1.24, -0.18, -0.06, 0, 4,
    -0.08, 1.20, -0.12, 0, 4,
    -0.08, -0.18, 1.26, 0, 4,
    0, 0, 0, 1, 0,
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

    const double barHeight = 68.0;
    const double pillRadius = 34.0;
    const double innerHorizontalPad = 6.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomPadding > 0 ? bottomPadding + 6 : 16,
      ),
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(pillRadius),
          boxShadow: [
            // Deep ambient elevation shadow
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
            // Subtle colored caustic glow beneath the glass
            BoxShadow(
              color: primaryColor.withOpacity(isDark ? 0.22 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(pillRadius),
          child: BackdropFilter(
            // Combine vibrancy saturation boost with deep Gaussian blur
            filter: ui.ImageFilter.compose(
              outer: ui.ImageFilter.blur(
                sigmaX: 28.0,
                sigmaY: 28.0,
                tileMode: TileMode.mirror,
              ),
              inner: const ColorFilter.matrix(_vibrancyMatrix),
            ),
            child: CustomPaint(
              // Background optical layer (sub-surface scattering & top curvature sheen)
              painter: LiquidGlassShellPainter(
                radius: pillRadius,
                isDark: isDark,
                accentColor: primaryColor,
                isForeground: false,
              ),
              // Foreground optical layer (Fresnel specular rim & inner lip refraction)
              foregroundPainter: LiquidGlassShellPainter(
                radius: pillRadius,
                isDark: isDark,
                accentColor: primaryColor,
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
                          // Calculate liquid stretch deformation during movement
                          final rawProgress = _dropletController.isAnimating
                              ? _dropletController.value
                              : (_dragIndex != null ? 0.35 : 0.0);
                          final distance = (_toIndex - _fromIndex).abs().clamp(1.0, 2.2);
                          final stretchWave = math.sin(rawProgress * math.pi);
                          final scaleX = 1.0 + 0.22 * stretchWave * (distance * 0.7);
                          final scaleY = 1.0 - 0.07 * stretchWave;

                          final dropletLeft = (animIdx * tabWidth).clamp(
                            0.0,
                            totalWidth - tabWidth,
                          );

                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // 1. Sliding & Morphing 3D Liquid Glass Lens Droplet
                              Positioned(
                                left: dropletLeft,
                                top: 6,
                                bottom: 6,
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
                                      ? Colors.white.withOpacity(0.68)
                                      : const Color(0xFF475569);
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
                                              scale: 1.0 + 0.12 * proximity,
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
                                                    ? FontWeight.w700
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

/// Renders the outer capsule's optical glass layers:
/// - Background pass (`isForeground == false`): sub-surface translucent tint + curved top reflection arc.
/// - Foreground pass (`isForeground == true`): multi-stop Fresnel specular rim + inner concave lip highlight.
class LiquidGlassShellPainter extends CustomPainter {
  final double radius;
  final bool isDark;
  final Color accentColor;
  final bool isForeground;

  LiquidGlassShellPainter({
    required this.radius,
    required this.isDark,
    required this.accentColor,
    required this.isForeground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    if (!isForeground) {
      // 1. Sub-surface refractive tint fill
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          isDark
              ? [
                  Colors.white.withOpacity(0.14),
                  const Color(0xFF0F172A).withOpacity(0.42),
                  const Color(0xFF1E293B).withOpacity(0.52),
                ]
              : [
                  Colors.white.withOpacity(0.58),
                  Colors.white.withOpacity(0.28),
                  Colors.white.withOpacity(0.44),
                ],
          const [0.0, 0.52, 1.0],
        );
      canvas.drawRRect(rrect, fillPaint);

      // 2. Upper half curved sky reflection band
      final upperRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.48);
      final skyPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.linear(
          upperRect.topCenter,
          upperRect.bottomCenter,
          [
            Colors.white.withOpacity(isDark ? 0.14 : 0.42),
            Colors.white.withOpacity(0.0),
          ],
        );
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(upperRect, skyPaint);
      canvas.restore();
      return;
    }

    // Foreground Pass: Drawn ON TOP of children so rim light is crisp and unobstructed
    // 1. Inner concave shadow at bottom edge for 3D glass thickness
    final innerBottomShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [
          Colors.transparent,
          Colors.black.withOpacity(isDark ? 0.30 : 0.08),
        ],
        const [0.65, 1.0],
      );
    canvas.drawRRect(rrect.deflate(1.0), innerBottomShadow);

    // 2. Diagonal Fresnel Specular Rim Light (Bright top-left & bottom-right bounce)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        isDark
            ? [
                Colors.white.withOpacity(0.75),
                Colors.white.withOpacity(0.18),
                accentColor.withOpacity(0.15),
                Colors.white.withOpacity(0.42),
              ]
            : [
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.35),
                accentColor.withOpacity(0.18),
                Colors.white.withOpacity(0.75),
              ],
        const [0.0, 0.35, 0.70, 1.0],
      );
    canvas.drawRRect(rrect.deflate(0.75), rimPaint);

    // 3. Top crest intense specular glare line
    final crestRect = Rect.fromLTWH(size.width * 0.08, 1.2, size.width * 0.84, 1.4);
    final crestPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        crestRect.centerLeft,
        crestRect.centerRight,
        [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(isDark ? 0.65 : 0.95),
          Colors.white.withOpacity(0.0),
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(crestRect, crestPaint);
  }

  @override
  bool shouldRepaint(covariant LiquidGlassShellPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.radius != radius ||
      oldDelegate.isForeground != isForeground;
}

/// Renders the sliding convex 3D liquid droplet lens behind the active tab
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

    // 1. Soft outer glow of the liquid droplet
    final glowPaint = Paint()
      ..color = primaryColor.withOpacity(isDark ? 0.24 : 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rrect.deflate(2), glowPaint);

    // 2. Convex droplet body fill (glassy primary tint + bright top)
    final bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        isDark
            ? [
                Colors.white.withOpacity(0.24),
                primaryColor.withOpacity(0.28),
                primaryColor.withOpacity(0.16),
              ]
            : [
                Colors.white.withOpacity(0.88),
                Color.lerp(Colors.white, primaryColor, 0.16)!.withOpacity(0.72),
                Color.lerp(Colors.white, primaryColor, 0.24)!.withOpacity(0.62),
              ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(rrect, bodyPaint);

    // 3. Top convex lens highlight dome (simulating curved water droplet surface)
    final domeRect = Rect.fromLTWH(
      size.width * 0.12,
      2.0,
      size.width * 0.76,
      size.height * 0.38,
    );
    final domeRRect = RRect.fromRectAndRadius(domeRect, Radius.circular(radius));
    final domePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        domeRect.topCenter,
        domeRect.bottomCenter,
        [
          Colors.white.withOpacity(isDark ? 0.42 : 0.90),
          Colors.white.withOpacity(0.0),
        ],
      );
    canvas.drawRRect(domeRRect, domePaint);

    // 4. Crisp Fresnel rim around the droplet lens
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        isDark
            ? [
                Colors.white.withOpacity(0.75),
                primaryColor.withOpacity(0.45),
                Colors.white.withOpacity(0.30),
              ]
            : [
                Colors.white,
                primaryColor.withOpacity(0.32),
                Colors.white.withOpacity(0.85),
              ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRRect(rrect.deflate(0.6), rimPaint);
  }

  @override
  bool shouldRepaint(covariant LiquidDropletLensPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.primaryColor != primaryColor;
}

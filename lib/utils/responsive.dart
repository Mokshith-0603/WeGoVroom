import 'package:flutter/material.dart';

extension ResponsiveX on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  bool get isTablet => screenSize.shortestSide >= 600;

  double get _scale {
    final width = screenSize.width;
    if (width >= 1024) return 1.25;
    if (width >= 768) return 1.15;
    if (width >= 600) return 1.08;
    return (width / 390).clamp(0.85, 1.05);
  }

  double rs(double value) => value * _scale;

  double get maxContentWidth => isTablet ? 720 : double.infinity;
}

class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.maxContentWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

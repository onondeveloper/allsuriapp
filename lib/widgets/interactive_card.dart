import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final Color? color;
  final BoxBorder? border;

  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.gradient,
    this.color,
    this.border,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _setPressed(bool v) {
    if (_isPressed != v) setState(() => _isPressed = v);
  }

  void _setHovered(bool v) {
    if (_isHovered != v) setState(() => _isHovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final bool hoverEnabled = kIsWeb || Theme.of(context).platform == TargetPlatform.macOS || Theme.of(context).platform == TargetPlatform.windows || Theme.of(context).platform == TargetPlatform.linux;

    final double scale = _isPressed ? 0.98 : (_isHovered ? 1.01 : 1.0);
    final List<BoxShadow> shadows = [
      BoxShadow(
        color: Colors.black.withOpacity(_isPressed ? 0.03 : (_isHovered ? 0.10 : 0.06)),
        blurRadius: _isPressed ? 6 : (_isHovered ? 16 : 10),
        spreadRadius: 0,
        offset: const Offset(0, 4),
      )
    ];

    final decoration = BoxDecoration(
      color: widget.color ?? Theme.of(context).colorScheme.surface,
      gradient: widget.gradient,
      borderRadius: widget.borderRadius,
      border: widget.border ?? Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: shadows,
    );

    Widget content = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: decoration,
        child: widget.child,
      ),
    );

    content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: content,
      ),
    );

    if (hoverEnabled) {
      content = MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: content,
      );
    }

    return content;
  }
}



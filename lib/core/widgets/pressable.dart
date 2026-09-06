import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// A tap target that scales down slightly while held.
///
/// Used instead of InkWell wherever the surface is a gradient or an image —
/// a Material ripple over those either does not show up or looks wrong. The
/// scale is deliberately small; anything larger reads as a bug on fast taps.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _active ? (_) => _set(true) : null,
      onTapUp: _active ? (_) => _set(false) : null,
      onTapCancel: _active ? () => _set(false) : null,
      onTap: _active ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppDimens.fast,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.5,
          duration: AppDimens.fast,
          child: widget.child,
        ),
      ),
    );
  }
}

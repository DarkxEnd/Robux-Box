import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';

/// The primary call to action.
///
/// Shows its own spinner while [onPressed] is running and blocks re-entry for
/// that whole time — every action behind one of these costs coins or makes a
/// server call, and a double tap would fire it twice.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppTheme.brandGradient,
    this.enabled = true,
    this.expand = true,
  });

  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool enabled;
  final bool expand;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _busy = false;

  bool get _enabled => widget.enabled && widget.onPressed != null && !_busy;

  Future<void> _run() async {
    if (!_enabled) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      // The button can be disposed mid-flight if the action navigated away.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      enabled: _enabled,
      onTap: _run,
      child: Container(
        height: AppDimens.buttonHeight,
        width: widget.expand ? double.infinity : null,
        padding: widget.expand
            ? null
            : const EdgeInsets.symmetric(horizontal: AppDimens.xl),
        decoration: BoxDecoration(
          gradient: _enabled
              ? widget.gradient
              : LinearGradient(
                  colors: [Colors.grey.shade600, Colors.grey.shade700],
                ),
          borderRadius: AppDimens.brMd,
          boxShadow: _enabled
              ? [
                  BoxShadow(
                    color: widget.gradient.colors.first.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: AppDimens.sm),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

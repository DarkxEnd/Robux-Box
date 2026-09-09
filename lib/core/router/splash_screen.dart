import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/r_glyph.dart';

/// Shown while Firebase resolves the session.
///
/// Visually identical to the native launch screen so the handover between them
/// is invisible — a different background here reads as a flash on every start.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppTheme.brandGradient),
        child: Center(child: RGlyph(size: 96)),
      ),
    );
  }
}

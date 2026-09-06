import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/google_logo.dart';
import '../../../core/widgets/r_glyph.dart';
import '../domain/auth_controller.dart';
import 'widgets/social_auth_button.dart';

/// The signed-out landing screen.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      final f = next.failure;
      // "cancelled" is the user closing the Google picker; surfacing it as an
      // error would be nagging them for a deliberate choice.
      if (f != null && f.code != 'cancelled') {
        AppToast.failure(context, f);
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const RGlyph(size: 88),
                const SizedBox(height: AppDimens.xl),
                Text(
                  l.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppDimens.md),
                Text(
                  l.welcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(flex: 3),

                SocialAuthButton(
                  label: l.welcomeContinueGoogle,
                  icon: const GoogleLogo(),
                  busy: state.busy,
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signInWithGoogle(),
                ),
                const SizedBox(height: AppDimens.md),
                SocialAuthButton(
                  label: l.welcomeContinueEmail,
                  icon: const Icon(Icons.mail_outline, size: 20),
                  background: Colors.white.withValues(alpha: 0.10),
                  foreground: Colors.white,
                  onPressed: () async => context.push(Routes.authEmail),
                ),
                const SizedBox(height: AppDimens.md),
                SocialAuthButton(
                  label: l.welcomeContinuePhone,
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  background: Colors.white.withValues(alpha: 0.10),
                  foreground: Colors.white,
                  onPressed: () async => context.push(Routes.authPhone),
                ),

                const SizedBox(height: AppDimens.xl),
                _Legal(text: l.welcomeTerms),
                const SizedBox(height: AppDimens.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legal extends ConsumerWidget {
  const _Legal({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);

    Future<void> open(String url) async {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimens.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => open(config.termsUrl),
              child: const Text('Terms', style: TextStyle(fontSize: 12)),
            ),
            Text('·', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            TextButton(
              onPressed: () => open(config.privacyUrl),
              child: const Text('Privacy', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }
}

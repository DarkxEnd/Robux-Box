import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/gradient_button.dart';

/// Explains why the app asks for location, before the system prompt appears.
///
/// The permission is genuinely optional — the server falls back to the device
/// locale and pins the country on first resolve either way. This screen exists
/// so the prompt is not a cold, unexplained dialog, which is what makes people
/// deny it permanently.
class LocationGateScreen extends ConsumerWidget {
  const LocationGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Future<void> proceed() async {
      // Either way the app continues; the difference is only how accurate the
      // first tier guess is.
      if (context.mounted) context.go(Routes.home);
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.public,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppDimens.xl),
                Text(
                  l.locationRequiredTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppDimens.md),
                Text(
                  l.locationRequiredBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppDimens.xxl),
                GradientButton(
                  label: l.locationAllow,
                  onPressed: () async {
                    // detectCountryCode() triggers the system prompt itself
                    // when the locale gives no answer.
                    await ref.read(geoTierServiceProvider).detectCountryCode();
                    await proceed();
                  },
                ),
                const SizedBox(height: AppDimens.sm),
                TextButton(
                  onPressed: proceed,
                  child: Text(l.locationSkip),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

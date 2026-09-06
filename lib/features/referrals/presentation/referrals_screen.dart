import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../profile/data/user_repository.dart';

class ReferralsScreen extends ConsumerWidget {
  const ReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final code = user?.referralCode ?? '';

    return AppScaffold(
      title: l.referralsTitle,
      padding: AppDimens.pagePadding,
      body: ListView(
        children: [
          const SizedBox(height: AppDimens.xl),
          Container(
            padding: const EdgeInsets.all(AppDimens.xl),
            decoration: const BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: AppDimens.brXl,
            ),
            child: Column(
              children: [
                const Icon(Icons.group_add, color: Colors.white, size: 44),
                const SizedBox(height: AppDimens.lg),
                Text(
                  l.referralsSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          GlassCard(
            child: Column(
              children: [
                Text(l.referralsYourCode, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppDimens.sm),
                SelectableText(
                  // A brand-new account has no code until the auth trigger
                  // writes one, so the placeholder is a real state, not an
                  // error.
                  code.isEmpty ? '…' : code,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: code.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: code),
                                );
                                if (context.mounted) {
                                  AppToast.success(context, l.commonCopied);
                                }
                              },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(l.commonCopy),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          GlassCard(
            child: Column(
              children: [
                _Reward(
                  icon: Icons.person_add_alt,
                  label: l.referralsInvite,
                  coins: AppConstants.referrerBonusCoins,
                ),
                const Divider(height: AppDimens.xl),
                _Reward(
                  icon: Icons.percent,
                  label:
                      '${(AppConstants.referralRevenueSharePercent * 100).round()}% lifetime',
                  coins: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          GradientButton(
            label: l.referralsInvite,
            icon: Icons.share,
            enabled: code.isNotEmpty,
            onPressed: () async {
              await Share.share(
                '${l.welcomeTitle}\n\n'
                '${l.referralsYourCode}: $code\n'
                'https://play.google.com/store/apps/details'
                '?id=com.robuxbox.app',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward({required this.icon, required this.label, this.coins});

  final IconData icon;
  final String label;
  final int? coins;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: AppDimens.md),
        Expanded(child: Text(label)),
        if (coins != null)
          Text(
            '+${coins!.grouped}',
            style: const TextStyle(
              color: AppTheme.coin,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

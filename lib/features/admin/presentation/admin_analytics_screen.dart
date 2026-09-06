import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/format_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_gate.dart';

/// Headline numbers, recomputed on demand.
class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final analytics = ref.watch(adminAnalyticsProvider);

    return AdminGate(
      title: l.adminAnalytics,
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminAnalyticsProvider),
        child: AsyncView(
          value: analytics,
          onRetry: () => ref.invalidate(adminAnalyticsProvider),
          data: (data) => ListView(
            padding: const EdgeInsets.all(AppDimens.lg),
            children: [
              _Metric(
                icon: Icons.people_outline,
                label: 'Users',
                value: _int(data['totalUsers']).grouped,
                color: AppTheme.primary,
              ),
              _Metric(
                icon: Icons.monetization_on_outlined,
                // The whole outstanding coin float — the app's liability, and
                // the number worth watching before changing any payout rate.
                label: 'Coins outstanding',
                value: _int(data['coinsOutstanding']).grouped,
                color: AppTheme.coin,
              ),
              _Metric(
                icon: Icons.sports_esports_outlined,
                label: 'Robux equivalent',
                value: _int(data['robuxEquivalent']).grouped,
                color: AppTheme.accent,
              ),
              _Metric(
                icon: Icons.receipt_long_outlined,
                label: 'Pending redemptions',
                value: _int(data['pendingRedemptions']).grouped,
                color: AppTheme.warning,
              ),
              if (data.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppDimens.xl),
                  child: Text(
                    'No analytics yet. Pull to refresh.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static int _int(Object? v) => (v as num?)?.toInt() ?? 0;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: AppDimens.brSm,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppDimens.lg),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

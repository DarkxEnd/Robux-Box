import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/model_utils.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_gate.dart';

/// Bug reports submitted from settings.
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final reports = ref.watch(adminReportsProvider);

    return AdminGate(
      title: l.adminReports,
      child: AsyncView(
        value: reports,
        onRetry: () => ref.invalidate(adminReportsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.flag_outlined,
              title: l.emptyNothingHere,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (_, i) {
              final report = list[i];
              final created = Parse.toDate(report['createdAt']);
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Parse.toStr(report['message'])),
                    const SizedBox(height: AppDimens.sm),
                    Text(
                      // Device and version are attached automatically —
                      // a report without them is usually unactionable.
                      [
                        Parse.toStr(report['platform']),
                        Parse.toStr(report['model']),
                        Parse.toStr(report['appVersion']),
                        if (created != null) created.toLocal().toString(),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    SelectableText(
                      Parse.toStr(report['uid']),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

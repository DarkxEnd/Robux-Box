import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/extensions/vip_level_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/leaderboard_entry.dart';
import '../data/leaderboard_repository.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final period = ref.watch(selectedPeriodProvider);
    final entries = ref.watch(leaderboardProvider);
    final mine = ref.watch(myRankProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);

    return AppScaffold(
      title: l.leaderboardTitle,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: SegmentedButton<LeaderboardPeriod>(
              segments: [
                ButtonSegment(
                  value: LeaderboardPeriod.daily,
                  label: Text(l.leaderboardDaily),
                ),
                ButtonSegment(
                  value: LeaderboardPeriod.weekly,
                  label: Text(l.leaderboardWeekly),
                ),
                ButtonSegment(
                  value: LeaderboardPeriod.allTime,
                  label: Text(l.leaderboardAllTime),
                ),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(selectedPeriodProvider.notifier).state = s.first,
            ),
          ),
          Expanded(
            child: AsyncView(
              value: entries,
              onRetry: () => ref.invalidate(leaderboardProvider),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyView(
                    icon: Icons.emoji_events_outlined,
                    title: l.emptyNothingHere,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.lg,
                    0,
                    AppDimens.lg,
                    AppDimens.xxl,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimens.sm),
                  itemBuilder: (_, i) => _Row(
                    entry: list[i],
                    isMe: list[i].uid == uid,
                  ),
                );
              },
            ),
          ),
          // The user is usually outside the top 50, so their own row is
          // pinned rather than left unfindable.
          if (mine != null && !_isInTop(entries.valueOrNull, mine.uid))
            Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: _Row(entry: mine, isMe: true),
            ),
        ],
      ),
    );
  }

  static bool _isInTop(List<LeaderboardEntry>? list, String uid) =>
      list?.any((e) => e.uid == uid) ?? false;
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.isMe});

  final LeaderboardEntry entry;
  final bool isMe;

  Color? get _medal => switch (entry.rank) {
        1 => const Color(0xFFFFD54F),
        2 => const Color(0xFFCFD8DC),
        3 => const Color(0xFFCD7F32),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medal = _medal;

    return GlassCard(
      padding: const EdgeInsets.all(AppDimens.md),
      gradient: isMe
          ? LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.22),
                theme.colorScheme.primary.withValues(alpha: 0.08),
              ],
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: medal != null
                ? Icon(Icons.emoji_events, color: medal, size: 22)
                : Text(
                    '${entry.rank}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
          ),
          const SizedBox(width: AppDimens.sm),
          CircleAvatar(
            radius: 17,
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.16),
            backgroundImage: (entry.photoUrl?.isNotEmpty ?? false)
                ? CachedNetworkImageProvider(entry.photoUrl!)
                : null,
            child: (entry.photoUrl?.isNotEmpty ?? false)
                ? null
                : Text(entry.safeName.characters.first.toUpperCase()),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.safeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isMe ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                if (entry.vipLevel.isVipTier) ...[
                  const SizedBox(width: 4),
                  Icon(
                    entry.vipLevel.vipIcon,
                    size: 13,
                    color: entry.vipLevel.vipColor,
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on,
                  size: 14, color: AppTheme.coin),
              const SizedBox(width: 3),
              Text(
                entry.coins.compact,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

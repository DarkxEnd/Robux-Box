import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers.dart';
import '../theme/app_dimens.dart';
import '../theme/app_theme.dart';

/// A slim bar that appears while the device reports no network.
///
/// Informational only — it never blocks interaction. The radio being down does
/// not mean a queued Firestore write will fail, and blocking the UI on this
/// signal would break offline reads that work perfectly well from cache.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Treat "not yet known" as online: showing an offline warning for a frame
    // on every cold start is worse than showing it a moment late.
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;

    return AnimatedSize(
      duration: AppDimens.normal,
      curve: Curves.easeOut,
      child: online
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: AppTheme.warning.withValues(alpha: 0.16),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.lg,
                vertical: AppDimens.sm,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 15,
                    color: AppTheme.warning,
                  ),
                  SizedBox(width: AppDimens.sm),
                  Text(
                    'No internet connection',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

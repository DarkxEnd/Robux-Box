import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/failure.dart';
import '../theme/app_dimens.dart';

/// Loading, empty and error states.
///
/// Every list screen uses these three rather than rolling its own, so a
/// failure looks the same everywhere and always offers a way forward. An
/// error with no retry is the most common cause of an uninstall.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppDimens.lg),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppDimens.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppDimens.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppDimens.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  /// Accepts a [Failure] when we have one and any object otherwise, so it can
  /// also render an unexpected throw from a provider.
  final Object failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = failure is Failure
        ? (failure as Failure).message
        : 'Something went wrong. Please try again.';

    final icon = switch (failure) {
      NetworkFailure() => Icons.wifi_off_rounded,
      AuthFailure() => Icons.lock_outline,
      PermissionFailure() => Icons.block_outlined,
      _ => Icons.error_outline,
    };

    return EmptyView(
      icon: icon,
      title: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
    );
  }
}

/// Wraps an [AsyncValue] so a screen does not repeat the three-branch switch.
///
/// Keeps stale data on screen during a refresh rather than flashing a spinner
/// — the balance disappearing for a frame every time the wallet re-reads is
/// far more alarming than a value that is a second old.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const LoadingView(),
      error: (e, _) => ErrorView(failure: e, onRetry: onRetry),
    );
  }
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/providers.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/banner.dart';

/// Active promo banners, ordered.
///
/// Scheduling (`startsAt`/`endsAt`) is filtered client-side because Firestore
/// cannot range-filter two different fields in one query. The set is small, so
/// the cost is nil.
final homeBannersProvider = StreamProvider<List<HomeBanner>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FsPaths.banners)
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => HomeBanner.fromMap(d.id, d.data()))
          .where((b) => b.isLive)
          .toList());
});

/// An auto-advancing banner carousel.
class PromoCarousel extends ConsumerStatefulWidget {
  const PromoCarousel({super.key});

  @override
  ConsumerState<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends ConsumerState<PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _index = 0;

  void _startTimer(int count) {
    _timer?.cancel();
    // A single banner must not animate — it would slide to itself forever.
    if (count < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % count,
        duration: AppDimens.slow,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(homeBannersProvider).valueOrNull ?? const [];
    if (banners.isEmpty) return const SizedBox.shrink();

    _startTimer(banners.length);

    return Column(
      children: [
        SizedBox(
          height: 128,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _Banner(banner: banners[i]),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: AppDimens.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              banners.length,
              (i) => AnimatedContainer(
                duration: AppDimens.fast,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: AppDimens.brPill,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.banner});

  final HomeBanner banner;

  @override
  Widget build(BuildContext context) {
    final colors = banner.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.xs),
      child: GestureDetector(
        onTap: () {
          final route = banner.deeplink;
          // Admin-authored, so it is validated like any other untrusted route.
          if (route != null && Routes.isKnown(route)) context.push(route);
        },
        child: ClipRRect(
          borderRadius: AppDimens.brLg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: colors.length >= 2
                      ? LinearGradient(colors: colors)
                      : AppTheme.brandGradient,
                ),
              ),
              if (banner.imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  fit: BoxFit.cover,
                  // An unreachable image must leave the gradient visible
                  // rather than punching a hole in the carousel.
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  placeholder: (_, __) => const SizedBox.shrink(),
                ),
              Padding(
                padding: const EdgeInsets.all(AppDimens.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (banner.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        banner.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

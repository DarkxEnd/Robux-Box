import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/gradient_button.dart';

/// A three-page explainer shown once, after the first sign-in.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = const [
    _Page(
      icon: Icons.ondemand_video_rounded,
      title: 'Watch and earn',
      body: 'Short videos and quick offers turn into coins in your wallet.',
      gradient: AppTheme.brandGradient,
    ),
    _Page(
      icon: Icons.task_alt_rounded,
      title: 'Finish offers',
      body: 'Surveys and app trials pay far more than a single video.',
      gradient: LinearGradient(colors: [Color(0xFF00D1FF), Color(0xFF2FD07A)]),
    ),
    _Page(
      icon: Icons.card_giftcard_rounded,
      title: 'Redeem for Robux',
      body: 'Swap coins for Robux gift cards, Amazon or Google Play credit.',
      gradient: AppTheme.coinGradient,
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(preferencesProvider).setOnboardingDone(true);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _pages[i],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: AppDimens.normal,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: AppDimens.brPill,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimens.xl),
                child: GradientButton(
                  label: isLast ? 'Get started' : 'Next',
                  onPressed: () async {
                    if (isLast) return _finish();
                    await _controller.nextPage(
                      duration: AppDimens.normal,
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.icon,
    required this.title,
    required this.body,
    required this.gradient,
  });

  final IconData icon;
  final String title;
  final String body;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: AppDimens.xxl),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppDimens.md),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

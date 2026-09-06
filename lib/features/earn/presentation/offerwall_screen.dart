import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/providers.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/premium_loader.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/offerwall.dart';

/// A provider's offerwall, in a WebView.
///
/// The URL is fetched fresh from `getOfferwallUrl` every time and never built
/// or cached client-side: it is signed with a secret only Cloud Functions
/// holds and carries the uid the postback will credit. Constructing it here
/// would let anyone point a completion at any account.
///
/// Coins are never granted by this screen. The provider posts back to our
/// server when an offer completes, which is why nothing here reads a result.
class OfferwallScreen extends ConsumerStatefulWidget {
  const OfferwallScreen({super.key, required this.provider});

  final OfferwallProvider provider;

  @override
  ConsumerState<OfferwallScreen> createState() => _OfferwallScreenState();
}

class _OfferwallScreenState extends ConsumerState<OfferwallScreen> {
  WebViewController? _controller;
  Failure? _failure;
  bool _loading = true;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final result = await ref
        .read(offerwallServiceProvider)
        .urlFor(widget.provider);
    if (!mounted) return;

    result.when(
      success: (session) {
        if (!session.isValid) {
          setState(() {
            _loading = false;
            _failure = const OperationFailure(
              'That offerwall is unavailable right now.',
              code: 'bad-url',
            );
          });
          return;
        }
        _startWebView(session.url);
      },
      failure: (f) => setState(() {
        _loading = false;
        _failure = f;
      }),
    );
  }

  void _startWebView(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Sub-resource failures (a tracking pixel, an ad slot) are routine
            // inside these walls and must not blank the page. Only a failure
            // of the main document is worth surfacing.
            if (!error.isForMainFrame.isTrue) return;
            log.w('offerwall load error: ${error.description}');
            if (mounted) {
              setState(() {
                _loading = false;
                _failure = const NetworkFailure(
                  'Could not load the offerwall. Check your connection.',
                  code: 'webview',
                );
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() => _controller = controller);
  }

  Future<bool> _onBack() async {
    final controller = _controller;
    // Inside a survey, back should step back through the survey rather than
    // abandoning it — losing progress mid-survey means losing the payout.
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onBack() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.provider.displayName),
          bottom: _loading && _progress > 0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (_failure != null)
                ErrorView(failure: _failure!, onRetry: _load)
              else if (controller != null)
                WebViewWidget(controller: controller),
              if (_loading && _failure == null)
                const Center(child: PremiumLoader(message: 'Opening offers…')),
            ],
          ),
        ),
        bottomNavigationBar: widget.provider.supportsReversal
            ? null
            : const _NoReversalNotice(),
      ),
    );
  }
}

/// CPAlead has no reversal macro, so a rejected offer can only be clawed back
/// by hand. Saying so up front is better than a silent negative adjustment
/// appearing in the wallet days later.
class _NoReversalNotice extends StatelessWidget {
  const _NoReversalNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Text(
                'Offers can be reversed if the advertiser rejects them.',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on bool? {
  bool get isTrue => this ?? true;
}

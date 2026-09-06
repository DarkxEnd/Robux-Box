import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import 'app_background.dart';
import 'connectivity_banner.dart';

/// The standard page frame: ambient background, offline banner, safe area.
///
/// Used by every screen so the offline banner can never be forgotten — a
/// screen that silently fails while the device is offline is the single most
/// confusing state in this app.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.showBack = true,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding = EdgeInsets.zero,
    this.showBackground = true,
    this.onRefresh,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final bool showBackground;

  /// When provided, the body becomes pull-to-refreshable.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasAppBar = title != null || titleWidget != null || actions != null;

    Widget content = Padding(padding: padding, child: body);
    if (onRefresh != null) {
      content = RefreshIndicator(onRefresh: onRefresh!, child: content);
    }

    final scaffold = Scaffold(
      backgroundColor: showBackground ? Colors.transparent : null,
      extendBodyBehindAppBar: true,
      appBar: hasAppBar
          ? AppBar(
              title: titleWidget ?? (title == null ? null : Text(title!)),
              actions: actions,
              leading: leading,
              automaticallyImplyLeading: showBack,
              toolbarHeight: AppDimens.appBarHeight,
            )
          : null,
      body: SafeArea(
        top: !hasAppBar,
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(child: content),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );

    return showBackground ? AppBackground(child: scaffold) : scaffold;
  }
}

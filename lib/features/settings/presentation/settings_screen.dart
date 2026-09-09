import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/domain/auth_controller.dart';
import '../../profile/presentation/widgets/profile_menu_tile.dart';
import 'report_sheet.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prefs = ref.watch(preferencesProvider);
    final config = ref.watch(appConfigProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final version = ref.watch(_appVersionProvider).valueOrNull ?? '…';

    Future<void> open(String url) async {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) AppToast.error(context, l.errorGeneric);
      }
    }

    return AppScaffold(
      title: l.settingsTitle,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.xxl),
        children: [
          SectionHeader(title: l.settingsTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
              child: Column(
                children: [
                  ProfileMenuTile(
                    icon: Icons.language,
                    label: l.settingsLanguage,
                    badge:
                        localeNames[locale?.languageCode] ??
                        l.settingsThemeSystem,
                    onTap: () => _pickLanguage(context),
                  ),
                  ProfileMenuTile(
                    icon: Icons.brightness_6_outlined,
                    label: l.settingsTheme,
                    badge: switch (themeMode) {
                      ThemeMode.light => l.settingsThemeLight,
                      ThemeMode.dark => l.settingsThemeDark,
                      ThemeMode.system => l.settingsThemeSystem,
                    },
                    onTap: () => ref.read(themeModeProvider.notifier).cycle(),
                  ),
                  _SwitchTile(
                    icon: Icons.volume_up_outlined,
                    label: l.settingsSound,
                    value: prefs.soundEnabled,
                    onChanged: (v) async {
                      await prefs.setSoundEnabled(v);
                      // PreferencesService is a plain wrapper over
                      // SharedPreferences with no change notification, so the
                      // repaint has to be asked for explicitly.
                      if (mounted) setState(() {});
                    },
                  ),
                  _SwitchTile(
                    icon: Icons.vibration,
                    label: l.settingsHaptics,
                    value: prefs.hapticsEnabled,
                    onChanged: (v) async {
                      await prefs.setHapticsEnabled(v);
                      if (mounted) setState(() {});
                    },
                  ),
                  ProfileMenuTile(
                    icon: Icons.notifications_outlined,
                    label: l.settingsNotifications,
                    onTap: () async {
                      final granted = await ref
                          .read(notificationServiceProvider)
                          .requestPermission();
                      if (!context.mounted) return;
                      granted
                          ? AppToast.success(context, l.commonDone)
                          : AppToast.info(context, l.notificationsEnableBody);
                    },
                  ),
                ],
              ),
            ),
          ),

          SectionHeader(title: l.settingsSupport),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
              child: Column(
                children: [
                  ProfileMenuTile(
                    icon: Icons.flag_outlined,
                    label: l.settingsReport,
                    onTap: () => showReportSheet(context),
                  ),
                  ProfileMenuTile(
                    icon: Icons.mail_outline,
                    label: config.supportEmail,
                    onTap: () => open('mailto:${config.supportEmail}'),
                  ),
                  ProfileMenuTile(
                    icon: Icons.privacy_tip_outlined,
                    label: l.settingsPrivacy,
                    onTap: () => open(config.privacyUrl),
                  ),
                  ProfileMenuTile(
                    icon: Icons.description_outlined,
                    label: l.settingsTerms,
                    onTap: () => open(config.termsUrl),
                  ),
                ],
              ),
            ),
          ),

          SectionHeader(title: l.settingsVersion(version)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
              child: ProfileMenuTile(
                icon: Icons.delete_forever_outlined,
                label: l.settingsDeleteAccount,
                destructive: true,
                trailing: const SizedBox.shrink(),
                onTap: () => _confirmDelete(context, l),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final l = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l.settingsThemeSystem),
              onTap: () {
                ref.read(localeProvider.notifier).set(null);
                Navigator.of(context).pop();
              },
            ),
            for (final locale in supportedLocales)
              ListTile(
                title: Text(
                  localeNames[locale.languageCode] ?? locale.languageCode,
                ),
                onTap: () {
                  ref.read(localeProvider.notifier).set(locale);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Deleting is irreversible and takes the coin balance with it, so it needs
  /// an explicit typed confirmation rather than a single tap.
  Future<void> _confirmDelete(BuildContext context, AppLocalizations l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsDeleteAccount),
        content: const Text(
          'This permanently deletes your account and any remaining coins. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.settingsDeleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref.read(authControllerProvider.notifier).deleteAccount();
    if (!context.mounted) return;
    if (!ok) {
      // Firebase requires a recent sign-in for deletion; the mapper already
      // says so, this just makes sure the user sees something.
      AppToast.error(context, l.errorGeneric);
    }
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      secondary: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
        size: 21,
      ),
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../models/app_user.dart';
import '../../data/user_repository.dart';

Future<void> showEditProfileSheet(BuildContext context, AppUser user) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: EditProfileSheet(user: user),
      ),
    );

/// Edits the handful of profile fields a user is allowed to change.
///
/// VIP tier, balance, country and admin status are absent by design — the
/// rules reject a write touching any of them, so offering the field would only
/// produce a permission error.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName ?? '');
  late final _roblox =
      TextEditingController(text: widget.user.robloxUsername ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _roblox.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);

    final result = await ref.read(userRepositoryProvider).updateProfile(
          uid: widget.user.uid,
          displayName: _name.text,
          robloxUsername: _roblox.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) {
        Navigator.of(context).pop();
        AppToast.success(context, AppLocalizations.of(context).commonSave);
      },
      failure: (f) => AppToast.failure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.sm,
        AppDimens.xl,
        AppDimens.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.profileEdit, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimens.xl),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l.profileDisplayName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: Validators.displayName,
            ),
            const SizedBox(height: AppDimens.lg),
            TextFormField(
              controller: _roblox,
              decoration: InputDecoration(
                labelText: l.rewardsRobloxUsername,
                prefixIcon: const Icon(Icons.sports_esports_outlined),
              ),
              // Optional here — only required at redemption time, so an empty
              // value must pass.
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? null
                  : Validators.robloxUsername(v),
            ),
            const SizedBox(height: AppDimens.xl),
            GradientButton(
              label: l.commonSave,
              enabled: !_busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

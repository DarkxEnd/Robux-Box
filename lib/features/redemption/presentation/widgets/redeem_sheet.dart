import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/format_extensions.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../models/reward.dart';
import '../../../profile/data/user_repository.dart';
import '../../data/redemption_repository.dart';
import 'redeem_success.dart';

Future<void> showRedeemSheet(BuildContext context, Reward reward) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        // Lifts the sheet above the keyboard; without it the destination
        // field is hidden exactly when it is being typed into.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: RedeemSheet(reward: reward),
      ),
    );

/// Collects the delivery destination and confirms the cost.
class RedeemSheet extends ConsumerStatefulWidget {
  const RedeemSheet({super.key, required this.reward});

  final Reward reward;

  @override
  ConsumerState<RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends ConsumerState<RedeemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _destination = TextEditingController();
  bool _busy = false;

  bool get _isRobux => widget.reward.kind == RewardKind.robux;

  @override
  void initState() {
    super.initState();
    // Prefill from the profile so a returning user does not retype it, and so
    // a typo is less likely on the field that decides where the money goes.
    final user = ref.read(currentUserProfileForPrefill);
    _destination.text = _isRobux ? (user.$1 ?? '') : (user.$2 ?? '');
  }

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);

    final result = await ref
        .read(redemptionRepositoryProvider)
        .request(rewardId: widget.reward.id, destination: _destination.text);
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) {
        Navigator.of(context).pop();
        showRedeemSuccess(context, widget.reward);
      },
      failure: (f) => AppToast.failure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
            Text(l.rewardsConfirmTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppDimens.xs),
            Text(widget.reward.title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppDimens.xl),

            TextFormField(
              controller: _destination,
              keyboardType: _isRobux
                  ? TextInputType.text
                  : TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _isRobux
                    ? l.rewardsRobloxUsername
                    : l.rewardsEmailForCode,
                prefixIcon: Icon(
                  _isRobux ? Icons.person_outline : Icons.mail_outline,
                ),
              ),
              validator: _isRobux
                  ? Validators.robloxUsername
                  : Validators.email,
            ),

            const SizedBox(height: AppDimens.lg),
            Container(
              padding: const EdgeInsets.all(AppDimens.md),
              decoration: BoxDecoration(
                color: AppTheme.coin.withValues(alpha: 0.12),
                borderRadius: AppDimens.brMd,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    size: 18,
                    color: AppTheme.coin,
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Text(
                      l.rewardsConfirmBody(widget.reward.coinCost),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimens.xl),
            GradientButton(
              label: '${l.rewardsRedeem} · ${widget.reward.coinCost.compact}',
              enabled: !_busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// The user's saved Roblox username and email, for prefilling.
final currentUserProfileForPrefill = Provider<(String?, String?)>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return (user?.robloxUsername, user?.email);
});

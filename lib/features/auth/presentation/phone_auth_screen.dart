import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gradient_button.dart';
import '../domain/phone_auth_controller.dart';

/// Phone sign-in: enter a number, then the SMS code.
class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _phoneKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);

    ref.listen(phoneAuthControllerProvider, (_, next) {
      if (next.failure != null) AppToast.failure(context, next.failure!);
    });

    final enteringCode = state.step == PhoneAuthStep.enterCode;

    return AppScaffold(
      title: l.welcomeContinuePhone,
      // Back from the code step returns to the number, not out of the flow —
      // a mistyped number is the most common reason to go back here.
      leading: enteringCode
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: controller.backToNumber,
            )
          : null,
      padding: AppDimens.pagePadding,
      body: enteringCode
          ? _CodeStep(
              controller: _code,
              state: state,
              onSubmit: () async {
                context.unfocus();
                await controller.confirmCode(_code.text);
              },
              onResend: () => controller.sendCode(
                state.phoneNumber,
                resend: true,
              ),
            )
          : _NumberStep(
              formKey: _phoneKey,
              controller: _phone,
              state: state,
              onSubmit: () async {
                if (!(_phoneKey.currentState?.validate() ?? false)) return;
                context.unfocus();
                await controller.sendCode(_phone.text);
              },
            ),
    );
  }
}

class _NumberStep extends StatelessWidget {
  const _NumberStep({
    required this.formKey,
    required this.controller,
    required this.state,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final PhoneAuthState state;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Form(
      key: formKey,
      child: ListView(
        children: [
          const SizedBox(height: AppDimens.xl),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: InputDecoration(
              labelText: l.authPhoneNumber,
              hintText: '+20 100 000 0000',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            validator: Validators.phone,
          ),
          const SizedBox(height: AppDimens.xl),
          GradientButton(
            label: l.authSendCode,
            enabled: !state.busy,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.controller,
    required this.state,
    required this.onSubmit,
    required this.onResend,
  });

  final TextEditingController controller;
  final PhoneAuthState state;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onResend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      children: [
        const SizedBox(height: AppDimens.xl),
        Text(l.authCodeSent, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          state.phoneNumber,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppDimens.xl),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          // Lets Android's SMS autofill drop the code straight in.
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, letterSpacing: 10),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: ''),
          onChanged: (v) {
            if (v.length == 6) onSubmit();
          },
        ),
        const SizedBox(height: AppDimens.lg),
        GradientButton(
          label: l.authVerifyCode,
          enabled: !state.busy,
          onPressed: onSubmit,
        ),
        const SizedBox(height: AppDimens.sm),
        TextButton(
          onPressed: state.busy ? null : () => onResend(),
          child: Text(l.authSendCode),
        ),
      ],
    );
  }
}

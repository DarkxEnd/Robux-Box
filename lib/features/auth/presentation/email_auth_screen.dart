import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gradient_button.dart';
import '../domain/auth_controller.dart';

/// Email sign-in and registration, on one screen with a mode toggle.
///
/// One screen rather than two because the fields are almost identical, and a
/// user who typed their email into the wrong one would otherwise have to
/// retype it after navigating.
class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.unfocus();

    final controller = ref.read(authControllerProvider.notifier);
    final ok = _register
        ? await controller.register(_email.text, _password.text)
        : await controller.signInWithEmail(_email.text, _password.text);

    // The router redirects on success; nothing to do here. A failure is shown
    // by the listener in build().
    if (ok && mounted && _register) {
      AppToast.info(context, 'Check your inbox to verify your email.');
    }
  }

  Future<void> _resetPassword() async {
    final error = Validators.email(_email.text);
    if (error != null) {
      AppToast.error(context, 'Enter your email address first.');
      return;
    }
    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (ok && mounted) {
      AppToast.success(context, AppLocalizations.of(context).authResetSent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      final f = next.failure;
      if (f != null) {
        AppToast.failure(context, f);
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    return AppScaffold(
      title: _register ? l.authSignUp : l.authSignIn,
      padding: AppDimens.pagePadding,
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            const SizedBox(height: AppDimens.xl),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.authEmail,
                prefixIcon: const Icon(Icons.mail_outline),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: AppDimens.lg),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: [
                _register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              textInputAction: _register
                  ? TextInputAction.next
                  : TextInputAction.done,
              decoration: InputDecoration(
                labelText: l.authPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: Validators.password,
              onFieldSubmitted: (_) => _register ? null : _submit(),
            ),
            if (_register) ...[
              const SizedBox(height: AppDimens.lg),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l.authConfirmPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (v) => Validators.confirmPassword(v, _password.text),
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
            if (!_register)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: state.busy ? null : _resetPassword,
                  child: Text(l.authForgotPassword),
                ),
              ),
            const SizedBox(height: AppDimens.xl),
            GradientButton(
              label: _register ? l.authSignUp : l.authSignIn,
              enabled: !state.busy,
              onPressed: _submit,
            ),
            const SizedBox(height: AppDimens.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_register ? l.authHaveAccount : l.authNoAccount),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => setState(() => _register = !_register),
                  child: Text(_register ? l.authSignIn : l.authSignUp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

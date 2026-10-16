import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/responsive_content.dart';
import '../../providers/auth_provider.dart';

class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({super.key, this.email = ''});

  final String email;

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<bool> Function(AuthProvider auth, String email) action,
    String successMessage,
  ) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _success = false;
        _message = 'Enter a valid email address.';
      });
      return;
    }
    final auth = context.read<AuthProvider>();
    final succeeded = await action(auth, email);
    if (!mounted) return;
    setState(() {
      _success = succeeded;
      _message = succeeded ? successMessage : auth.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(strings.text('accountRecovery'))),
      body: SafeArea(
        child: ResponsiveContent(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Verify your email or reset your password using the 6-digit code sent to your inbox.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: strings.text('email'),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  prefixIcon: Icon(Icons.password_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '${strings.text('password')} (for password reset)',
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _success ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: auth.isLoading
                    ? null
                    : () => _run(
                          (auth, email) =>
                              auth.resendVerification(email: email),
                          'If this account needs verification, a code has been sent.',
                        ),
                child: const Text('Resend verification code'),
              ),
              ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () => _run(
                          (auth, email) => auth.verifyEmail(
                            email: email,
                            code: _codeController.text.trim(),
                          ),
                          'Email verified. You can now sign in.',
                        ),
                child: const Text('Verify email'),
              ),
              const Divider(height: 32),
              OutlinedButton(
                onPressed: auth.isLoading
                    ? null
                    : () => _run(
                          (auth, email) =>
                              auth.requestPasswordReset(email: email),
                          'If the account exists, a reset code has been sent.',
                        ),
                child: const Text('Send password reset code'),
              ),
              ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () => _run(
                          (auth, email) => auth.resetPassword(
                            email: email,
                            code: _codeController.text.trim(),
                            password: _passwordController.text,
                          ),
                          'Password reset. You can now sign in.',
                        ),
                child: const Text('Reset password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

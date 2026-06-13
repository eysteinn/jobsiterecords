import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../sync/sync_providers.dart';
import 'google_sign_in_button.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.inviteToken});

  final String? inviteToken;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _magicLinkSent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authSessionProvider.notifier);
      if (_signup) {
        await auth.signup(_email.text.trim(), _password.text, name: _name.text.trim());
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
      if (mounted) {
        final invite = widget.inviteToken;
        if (invite != null && invite.isNotEmpty) {
          context.go('/invite/accept?token=${Uri.encodeQueryComponent(invite)}');
        } else {
          context.pop();
        }
      }
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg.contains('TimeoutException')
          ? 'Could not reach the server at ${dotenv.env['API_BASE_URL'] ?? '10.0.2.2:8080'}. Check API_BASE_URL in .env and that Docker is running.'
          : msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendMagicLink() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _magicLinkSent = false;
    });
    try {
      await ref.read(authServiceProvider).requestMagicLink(_email.text.trim());
      if (mounted) setState(() => _magicLinkSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_signup ? 'Create account' : 'Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Sync jobs and notes with your workspace.',
            style: TextStyle(color: AppColors.subtle),
          ),
          const SizedBox(height: 20),
          const GoogleSignInButton(),
          if (GoogleSignInButton.isAvailable) const SizedBox(height: 16),
          Form(
            key: _form,
            child: Column(
              children: [
                if (_signup)
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) => (v == null || v.length < 10) ? 'At least 10 characters' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                if (_magicLinkSent) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'If that email is registered, a sign-in link is on its way. Open it on this device.',
                    style: TextStyle(color: AppColors.subtle),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_signup ? 'Sign up' : 'Sign in'),
                  ),
                ),
                if (!_signup) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _sendMagicLink,
                      child: const Text('Email me a sign-in link'),
                    ),
                  ),
                ],
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _signup = !_signup;
                            _error = null;
                          }),
                  child: Text(_signup ? 'Already have an account? Sign in' : 'Need an account? Sign up'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

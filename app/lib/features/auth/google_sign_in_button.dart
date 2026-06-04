import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../sync/sync_providers.dart';
import 'google_client_id.dart';

/// Google sign-in (hidden on iOS until Sign in with Apple ships — App Store rule).
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  static bool get isAvailable {
    if (Platform.isIOS) return false;
    return googleWebClientId() != null;
  }

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _busy = false;

  GoogleSignIn? get _google {
    final serverClientId = googleWebClientId();
    if (serverClientId == null) return null;
    return GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: serverClientId,
    );
  }

  String _friendlyError(Object e) {
    if (e is PlatformException) {
      final details = '${e.code} ${e.message ?? ''}'.toLowerCase();
      if (details.contains('10') ||
          details.contains('developer_error') ||
          details.contains('sign_in_failed')) {
        return 'Google Sign-In is not set up for this Android build. '
            'In Google Cloud Console, add your debug SHA-1 to the Android OAuth '
            'client for com.jobsiterecords.app (see app/README.md).';
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  Future<void> _signIn() async {
    final google = _google;
    if (google == null) return;

    setState(() => _busy = true);
    try {
      final account = await google.signIn();
      if (account == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in cancelled')),
          );
        }
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No ID token from Google. Check GOOGLE_WEB_CLIENT_ID in .env '
                'and the Android OAuth client SHA-1 in Google Cloud.',
              ),
            ),
          );
        }
        return;
      }

      await ref.read(authSessionProvider.notifier).oauthGoogle(idToken);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!GoogleSignInButton.isAvailable) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _busy ? null : _signIn,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Continue with Google'),
      ),
    );
  }
}

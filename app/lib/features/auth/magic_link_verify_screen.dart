import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../sync/sync_providers.dart';

class MagicLinkVerifyScreen extends ConsumerStatefulWidget {
  const MagicLinkVerifyScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<MagicLinkVerifyScreen> createState() => _MagicLinkVerifyScreenState();
}

class _MagicLinkVerifyScreenState extends ConsumerState<MagicLinkVerifyScreen> {
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      await ref.read(authSessionProvider.notifier).verifyMagicLink(widget.token);
      if (!mounted) return;
      setState(() => _done = true);
      final inviteToken = GoRouterState.of(context).uri.queryParameters['invite_token'];
      if (inviteToken != null && inviteToken.isNotEmpty) {
        context.go('/invite/accept?token=${Uri.encodeQueryComponent(inviteToken)}');
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/jobs');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signing in')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _verify, child: const Text('Try again')),
              ] else if (_done)
                const Text('Signed in!', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink))
              else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

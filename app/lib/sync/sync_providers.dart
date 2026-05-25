import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'auth_service.dart';

final apiClientProvider = Provider<ApiClient>((_) => ApiClient());
final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(apiClientProvider)),
);

final authSessionProvider = StateNotifierProvider<AuthSessionController, AsyncValue<AuthSession?>>(
  (ref) => AuthSessionController(ref.watch(authServiceProvider)),
);

class AuthSessionController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthSessionController(this._auth) : super(const AsyncValue.loading()) {
    restore();
  }

  final AuthService _auth;

  Future<void> restore() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _auth.loadSession());
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _auth.login(email, password));
  }

  Future<void> signup(String email, String password, {String? name}) async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _auth.signup(email, password, name: name));
  }

  Future<void> logout() async {
    final current = state.valueOrNull;
    if (current != null) {
      await _auth.logout(current.accessToken);
    }
    state = const AsyncValue.data(null);
  }
}

enum CaptureContextType { local, workspace }

class CaptureContext {
  const CaptureContext.local() : type = CaptureContextType.local, workspaceId = null, workspaceName = 'Local';

  const CaptureContext.workspace({required this.workspaceId, required this.workspaceName})
      : type = CaptureContextType.workspace;

  final CaptureContextType type;
  final String? workspaceId;
  final String workspaceName;

  bool get isLocal => type == CaptureContextType.local;
  bool get isWorkspace => type == CaptureContextType.workspace;
}

final captureContextProvider = StateNotifierProvider<CaptureContextController, CaptureContext>(
  (ref) => CaptureContextController(),
);

class CaptureContextController extends StateNotifier<CaptureContext> {
  CaptureContextController() : super(const CaptureContext.local()) {
    _restore();
  }

  static const _key = 'capture_context_workspace_id';
  static const _nameKey = 'capture_context_workspace_name';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    final name = prefs.getString(_nameKey);
    if (id != null && name != null) {
      state = CaptureContext.workspace(workspaceId: id, workspaceName: name);
    }
  }

  Future<void> selectLocal() async {
    state = const CaptureContext.local();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_nameKey);
  }

  Future<void> selectWorkspace({required String id, required String name}) async {
    state = CaptureContext.workspace(workspaceId: id, workspaceName: name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
    await prefs.setString(_nameKey, name);
  }
}

final syncWifiOnlyProvider = StateNotifierProvider<SyncWifiOnlyController, bool>(
  (ref) => SyncWifiOnlyController(),
);

class SyncWifiOnlyController extends StateNotifier<bool> {
  SyncWifiOnlyController() : super(false) {
    _restore();
  }

  static const _key = 'sync_wifi_only';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

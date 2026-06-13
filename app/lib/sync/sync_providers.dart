import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/storage_providers.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'sync_engine.dart';

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

  Future<void> oauthGoogle(String idToken) async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _auth.oauthGoogle(idToken));
  }

  Future<void> logout() async {
    final current = state.valueOrNull;
    if (current != null) {
      await _auth.logout(current.accessToken);
    }
    state = const AsyncValue.data(null);
  }

  Future<void> refreshMe() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      state = AsyncValue.data(await _auth.refreshMe(current.accessToken, current.refreshToken));
    } catch (_) {}
  }

  Future<void> verifyMagicLink(String token) async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _auth.verifyMagicLink(token));
  }

  Future<Map<String, dynamic>> acceptInvite(String token) async {
    final current = state.valueOrNull;
    if (current == null) {
      throw StateError('Sign in required');
    }
    return _auth.acceptInvite(current.accessToken, token);
  }

  Future<void> leaveWorkspace(String workspaceId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _auth.leaveWorkspace(current.accessToken, workspaceId);
    await refreshMe();
  }

  Future<void> deleteAccount() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _auth.deleteAccount(current.accessToken);
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

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    db: ref.watch(databaseProvider),
    api: ref.watch(apiClientProvider),
    auth: ref.watch(authServiceProvider),
    storage: ref.watch(mediaStorageProvider),
  );
});

final syncStatusProvider = StateProvider<SyncStatus>((_) => const SyncStatus.never());

/// Set when the active workspace is no longer in the session (member removed).
final workspaceRemovalMessageProvider = StateProvider<String?>((_) => null);

class SyncStatus {
  const SyncStatus({
    this.lastSyncedAt,
    this.pending = 0,
    this.quarantined = 0,
    this.error,
    this.changesSynced = 0,
    this.isSyncing = false,
    this.isOffline = false,
  });
  const SyncStatus.never() : this();

  final DateTime? lastSyncedAt;
  final int pending;
  final int quarantined;
  final String? error;
  final int changesSynced;
  final bool isSyncing;
  final bool isOffline;

  SyncStatus copyWith({
    DateTime? lastSyncedAt,
    int? pending,
    int? quarantined,
    Object? error = _unset,
    int? changesSynced,
    bool? isSyncing,
    bool? isOffline,
  }) {
    return SyncStatus(
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pending: pending ?? this.pending,
      quarantined: quarantined ?? this.quarantined,
      error: identical(error, _unset) ? this.error : error as String?,
      changesSynced: changesSynced ?? this.changesSynced,
      isSyncing: isSyncing ?? this.isSyncing,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

const _unset = Object();

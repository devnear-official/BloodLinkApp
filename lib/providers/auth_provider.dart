import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/network/socket_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/utils/error_mapper.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Owns the current session: the logged-in user, the JWT lifecycle, and
/// wiring the realtime socket connection up/down around login/logout.
///
/// Views never call [AuthService] directly — they call through here.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  AuthStatus status = AuthStatus.unknown;
  UserModel? currentUser;
  AppError? appError;
  String? get errorMessage => appError?.message;
  bool isLoading = false;

  String? _token;
  String? get token => _token;

  /// Called once at app startup to restore a persisted session, if any.
  ///
  /// Reading from local storage is close to instant, which meant the
  /// splash screen (shown only while [status] is [AuthStatus.unknown])
  /// could flash by too quickly to actually be seen. This enforces a
  /// small minimum display time so the splash always reads as an
  /// intentional screen rather than a flicker.
  Future<void> restoreSession() async {
    final started = DateTime.now();
    const minimumSplashDuration = Duration(milliseconds: 900);

    final token = await StorageService.instance.getToken();
    final userJson = await StorageService.instance.getUserJson();
    if (token != null && userJson != null) {
      _token = token;
      currentUser = UserModel.fromJson(userJson);
      status = AuthStatus.authenticated;
      SocketService.instance.connect(token);
      unawaited(PushNotificationService.identify(currentUser!.id));
    } else {
      status = AuthStatus.unauthenticated;
    }

    final elapsed = DateTime.now().difference(started);
    if (elapsed < minimumSplashDuration) {
      await Future.delayed(minimumSplashDuration - elapsed);
    }

    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) {
    return _runAuthAction(
      () => _authService.login(email: email, password: password),
    );
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? bloodGroup,
    String? division,
    String? district,
    String? subDistrict,
  }) {
    return _runAccountAction(
      () => _authService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
        bloodGroup: bloodGroup,
        division: division,
        district: district,
        subDistrict: subDistrict,
      ),
    );
  }

  Future<bool> verifyEmail({
    required String email,
    required String code,
  }) =>
      _runAccountAction(
        () => _authService.verifyEmail(email: email, code: code),
      );

  Future<bool> resendVerification({required String email}) =>
      _runAccountAction(() => _authService.resendVerification(email: email));

  Future<bool> requestPasswordReset({required String email}) =>
      _runAccountAction(() => _authService.requestPasswordReset(email: email));

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String password,
  }) =>
      _runAccountAction(
        () => _authService.resetPassword(
          email: email,
          code: code,
          password: password,
        ),
      );

  Future<bool> signInWithGoogle() async {
    isLoading = true;
    appError = null;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled the picker.
        isLoading = false;
        notifyListeners();
        return false;
      }
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Google sign-in did not return an ID token.');
      }
      final result = await _authService.googleAuth(idToken: idToken);
      await _persistSession(result.token, result.user);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      appError = mapError(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _runAuthAction(Future<AuthResult> Function() action) async {
    isLoading = true;
    appError = null;
    notifyListeners();
    try {
      final result = await action();
      await _persistSession(result.token, result.user);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      appError = mapError(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _runAccountAction(Future<void> Function() action) async {
    isLoading = true;
    appError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      appError = mapError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistSession(String token, UserModel user) async {
    _token = token;
    currentUser = user;
    status = AuthStatus.authenticated;
    await StorageService.instance.saveToken(token);
    await StorageService.instance.saveUserJson(user.toJson());
    SocketService.instance.connect(token);
    unawaited(PushNotificationService.identify(user.id));
  }

  /// Updates the in-memory + cached user after a profile edit, without
  /// requiring a fresh login.
  Future<void> updateCachedUser(UserModel user) async {
    currentUser = user;
    await StorageService.instance.saveUserJson(user.toJson());
    notifyListeners();
  }

  /// Called by the Dio auth interceptor on a 401, and by manual logout.
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Not signed in via Google — safe to ignore.
    }
    SocketService.instance.disconnect();
    await PushNotificationService.clearIdentity();
    await StorageService.instance.clearSession();
    _token = null;
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

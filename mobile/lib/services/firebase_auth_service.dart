import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class FirebaseAuthService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (!_initialized) {
      await Firebase.initializeApp();
      _initialized = true;
    }
  }

  static js.JsObject? get _auth => js.context['__firebaseAuth'];

  /// Send OTP to phone number (format: +919876543210)
  static Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(dynamic e) onFailed,
    required void Function(dynamic credential) onAutoRetrieved,
    required void Function(String verificationId) onCodeRetrieved,
  }) async {
    if (kIsWeb) {
      await _webSendOtp(
        phoneNumber: phoneNumber,
        onCodeSent: onCodeSent,
        onFailed: onFailed,
        onAutoRetrieved: onAutoRetrieved,
        onCodeRetrieved: onCodeRetrieved,
      );
    } else {
      await firebase_auth.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(minutes: 2),
        verificationCompleted: (cred) => onAutoRetrieved(cred),
        verificationFailed: (e) => onFailed(e),
        codeSent: (id, token) => onCodeSent(id, token),
        codeAutoRetrievalTimeout: (id) => onCodeRetrieved(id),
      );
    }
  }

  static Future<void> _webSendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(dynamic e) onFailed,
    required void Function(dynamic credential) onAutoRetrieved,
    required void Function(String verificationId) onCodeRetrieved,
  }) async {
    final auth = _auth;
    if (auth == null) {
      onFailed(Exception('Firebase Auth not initialized'));
      return;
    }

    final recaptchaVerifier = _getOrCreateRecaptchaVerifier();
    if (recaptchaVerifier == null) {
      onFailed(Exception('reCAPTCHA verifier not available'));
      return;
    }

    try {
      final confirmationResult = await auth.callMethod(
        'signInWithPhoneNumber',
        [phoneNumber, recaptchaVerifier],
      );

      js.context['firebase_confirmation_result'] = confirmationResult;
      html.window.sessionStorage['firebase_verification_id'] =
          confirmationResult['verificationId'].toString();

      onCodeSent(confirmationResult['verificationId'].toString(), null);
    } catch (e) {
      onFailed(e);
    }
  }

  static dynamic _getOrCreateRecaptchaVerifier() {
    final auth = _auth;
    if (auth == null) return null;

    final existing = js.context['firebase_recaptcha_verifier_obj'];
    if (existing != null) {
      return existing;
    }

    final container = html.document.createElement('div') as html.DivElement
      ..id = 'firebase-recaptcha-container'
      ..style.display = 'none';
    html.document.body?.append(container);

    final RecaptchaVerifier = js.context['firebase']['auth']['RecaptchaVerifier'];
    if (RecaptchaVerifier == null) return null;

    final verifier = RecaptchaVerifier.newInstance('firebase-recaptcha-container', {
      'size': 'invisible',
    });

    js.context['firebase_recaptcha_verifier_obj'] = verifier;
    return verifier;
  }

  /// Verify the 6-digit OTP entered by user
  static Future<dynamic> verifyOtp({
    required String smsCode,
    required String verificationId,
  }) async {
    if (kIsWeb) {
      return _webVerifyOtp(smsCode: smsCode, verificationId: verificationId);
    } else {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
    }
  }

  static Future<dynamic> _webVerifyOtp({
    required String smsCode,
    required String verificationId,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase Auth not initialized');
    }

    final confirmationResult = js.context['firebase_confirmation_result'];
    if (confirmationResult == null) {
      throw Exception('No verification session found. Please request OTP again.');
    }

    return await confirmationResult.callMethod('confirm', [smsCode]);
  }

  /// Get Firebase ID token to send to your FastAPI backend
  static Future<String?> getIdToken() async {
    if (kIsWeb) {
      final auth = _auth;
      if (auth == null) return null;
      final user = auth.callMethod('currentUser');
      if (user == null) return null;
      final token = await user.callMethod('getIdToken');
      return token.toString();
    } else {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      await user.reload();
      return await user.getIdToken();
    }
  }

  static Future<void> signOut() async {
    if (kIsWeb) {
      final auth = _auth;
      if (auth != null) await auth.callMethod('signOut');
    } else {
      await firebase_auth.FirebaseAuth.instance.signOut();
    }
  }

  static dynamic get currentUser {
    if (kIsWeb) {
      final auth = _auth;
      return auth != null ? auth.callMethod('currentUser') : null;
    } else {
      return firebase_auth.FirebaseAuth.instance.currentUser;
    }
  }

  /// Mobile-only: sign in with PhoneAuthCredential (auto-retrieval)
  static Future<dynamic> signInWithCredential(firebase_auth.PhoneAuthCredential credential) async {
    if (kIsWeb) {
      throw Exception('signInWithCredential not supported on web');
    }
    return await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
  }
}

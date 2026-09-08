import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import '../../core/constants/app_constants.dart';

/// Result of a biometric availability check.
enum BiometricAvailability {
  /// Hardware present and at least one biometric enrolled.
  available,

  /// No biometric hardware on this device.
  noHardware,

  /// Hardware present but no biometrics enrolled (user hasn't set up
  /// fingerprint / face unlock in device settings).
  notEnrolled,

  /// Biometric is currently unavailable (temporary lockout, in-call, etc.).
  unavailable,
}

/// Security service — owns PIN hashing, biometric checks, and app lock state.
///
/// **PIN storage:**
/// The PIN is NEVER persisted in plaintext. It is hashed with 10,000
/// iterations of SHA-256 using a per-install random 16-byte salt. Only
/// the salt and the resulting hash live in Android Keystore-backed
/// `flutter_secure_storage`. The original PIN cannot be recovered
/// from the stored data.
class SecurityService {
  SecurityService({FlutterSecureStorage? secureStorage, LocalAuthentication? auth})
      : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _secure;
  final LocalAuthentication _auth;

  // ---------------------------------------------------------------------
  // PIN management
  // ---------------------------------------------------------------------

  Future<bool> get isPinSet async {
    final hash = await _secure.read(key: AppConstants.securePinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Sets a new PIN. The previous PIN (if any) is overwritten.
  /// Throws [ArgumentError] if the PIN is not exactly 6 digits or
  /// contains non-digit characters.
  Future<void> setPin(String pin) async {
    if (pin.length != 6) {
      throw ArgumentError('PIN must be exactly 6 digits');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain only digits');
    }
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _secure.write(key: AppConstants.securePinSalt, value: salt);
    await _secure.write(key: AppConstants.securePinHash, value: hash);
  }

  Future<void> clearPin() async {
    await _secure.delete(key: AppConstants.securePinHash);
    await _secure.delete(key: AppConstants.securePinSalt);
  }

  /// Verifies a PIN against the stored hash. Returns false if no PIN
  /// is set or if the PIN doesn't match. Constant-time comparison is
  /// not strictly necessary here because the hash itself is salted
  /// and 10k-iteration — but we use a length-safe comparison anyway.
  Future<bool> verifyPin(String pin) async {
    final salt = await _secure.read(key: AppConstants.securePinSalt);
    final storedHash = await _secure.read(key: AppConstants.securePinHash);
    if (salt == null || storedHash == null) return false;
    final candidate = _hashPin(pin, salt);
    // Length-safe comparison to avoid timing side-channels.
    if (candidate.length != storedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return diff == 0;
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  /// 10,000 iterations of SHA-256 — fast enough for UX, slow enough
  /// to deter brute force on the resulting hash.
  String _hashPin(String pin, String salt) {
    var current = '$pin:$salt';
    for (var i = 0; i < 10000; i++) {
      final bytes = utf8.encode(current);
      current = crypto.sha256.convert(bytes).toString();
    }
    return current;
  }

  // ---------------------------------------------------------------------
  // Biometric
  // ---------------------------------------------------------------------

  /// Returns the availability of biometric authentication, distinguishing
  /// between "no hardware", "not enrolled", and "available". Use this
  /// instead of [canCheckBiometrics] when you need to give the user a
  /// specific reason why biometric can't be used.
  Future<BiometricAvailability> checkBiometricAvailability() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        // Either no hardware or no enrolled biometrics. canCheckBiometrics
        // returns false in both cases, so we need to look at the available
        // biometrics to distinguish.
        final enrolled = await _auth.getAvailableBiometrics();
        if (enrolled.isEmpty) {
          // Could be either "no hardware" or "no enrolled biometrics".
          // We treat both as "notEnrolled" for UX purposes since the
          // user-facing fix is the same: set up biometrics in device settings.
          return BiometricAvailability.notEnrolled;
        }
        return BiometricAvailability.unavailable;
      }
      return BiometricAvailability.available;
    } catch (_) {
      return BiometricAvailability.unavailable;
    }
  }

  /// Simple boolean check — kept for backwards compatibility. Prefer
  /// [checkBiometricAvailability] for richer diagnostics.
  Future<bool> get canCheckBiometrics async {
    return (await checkBiometricAvailability()) == BiometricAvailability.available;
  }

  /// Triggers the biometric authentication prompt. Returns true on
  /// success, false on failure / cancellation / unavailability.
  ///
  /// [reason] is shown to the user in the biometric prompt. The platform-
  /// specific messages are configured to use the localized reason on both
  /// Android (with BiometricPrompt) and iOS (with LocalAuthentication).
  Future<bool> authenticateBiometric({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Finlens',
            biometricHint: '',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
          ),
        ],
        options: const AuthenticationOptions(
          // Allow device PIN/password as fallback if biometric fails
          // repeatedly. This matches what banking apps do.
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

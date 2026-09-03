import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/constants/app_constants.dart';

/// Security service — owns PIN hashing, biometric checks, and app lock state.
///
/// PIN is hashed with 10k iterations of sha256 using a per-install random
/// salt stored alongside. The original PIN is NEVER persisted and NEVER
/// logged — only the hash and salt live in Android Keystore-backed storage.
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

  Future<void> setPin(String pin) async {
    if (pin.length < 4) throw ArgumentError('PIN must be at least 4 digits');
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _secure.write(key: AppConstants.securePinSalt, value: salt);
    await _secure.write(key: AppConstants.securePinHash, value: hash);
  }

  Future<void> clearPin() async {
    await _secure.delete(key: AppConstants.securePinHash);
    await _secure.delete(key: AppConstants.securePinSalt);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _secure.read(key: AppConstants.securePinSalt);
    final storedHash = await _secure.read(key: AppConstants.securePinHash);
    if (salt == null || storedHash == null) return false;
    final candidate = _hashPin(pin, salt);
    return candidate == storedHash;
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  /// 10k iterations of sha256 — fast enough for UX, slow enough to deter
  /// brute force on the resulting hash.
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

  Future<bool> get canCheckBiometrics async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

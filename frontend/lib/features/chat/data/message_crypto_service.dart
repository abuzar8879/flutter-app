import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MessageCryptoService {
  MessageCryptoService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _legacyPrivateKeyKey = 'chat_x25519_private_key';
  static const _legacyPublicKeyKey = 'chat_x25519_public_key';

  final FlutterSecureStorage _storage;
  final X25519 _keyExchange = X25519();
  final AesGcm _cipher = AesGcm.with256bits();

  String _privateKeyKey(String scopeKey) => 'chat_x25519_private_key_$scopeKey';
  String _publicKeyKey(String scopeKey) => 'chat_x25519_public_key_$scopeKey';

  Future<void> _migrateLegacyIfNeeded(String scopeKey) async {
    final scopedPrivate = await _storage.read(key: _privateKeyKey(scopeKey));
    final scopedPublic = await _storage.read(key: _publicKeyKey(scopeKey));
    if (scopedPrivate != null && scopedPublic != null) return;

    final legacyPrivate = await _storage.read(key: _legacyPrivateKeyKey);
    final legacyPublic = await _storage.read(key: _legacyPublicKeyKey);
    if (legacyPrivate == null || legacyPublic == null) return;

    await _storage.write(key: _privateKeyKey(scopeKey), value: legacyPrivate);
    await _storage.write(key: _publicKeyKey(scopeKey), value: legacyPublic);
  }

  Future<String> getOrCreatePublicKey({required String scopeKey}) async {
    await _migrateLegacyIfNeeded(scopeKey);

    final existingPublicKey = await _storage.read(key: _publicKeyKey(scopeKey));
    final existingPrivateKey = await _storage.read(key: _privateKeyKey(scopeKey));
    if (existingPublicKey != null && existingPrivateKey != null) {
      return existingPublicKey;
    }

    final keyPair = await _keyExchange.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    final publicValue = base64Encode(publicKey.bytes);
    await _storage.write(
      key: _privateKeyKey(scopeKey),
      value: base64Encode(privateBytes),
    );
    await _storage.write(key: _publicKeyKey(scopeKey), value: publicValue);
    return publicValue;
  }

  Future<String> encryptPayload({
    required String remotePublicKey,
    required Map<String, dynamic> payload,
    required String scopeKey,
  }) async {
    final senderPublicKey = await getOrCreatePublicKey(scopeKey: scopeKey);
    final secretKey = await _sharedSecret(remotePublicKey, scopeKey: scopeKey);
    final secretBox = await _cipher.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: secretKey,
    );

    return jsonEncode({
      'v': 2,
      'senderPublicKey': senderPublicKey,
      'recipientPublicKey': remotePublicKey,
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  /// Decrypt an encrypted chat payload.
  ///
  /// For v2+ blobs, [iAmSender] selects the correct DH peer ([recipientPublicKey]
  /// vs [senderPublicKey]) so decryption still works when profile keys change.
  /// Older v1 blobs fall back to [friendFallbackPublicKey].
  Future<Map<String, dynamic>> decryptPayload({
    required String encryptedPayload,
    required bool iAmSender,
    required String scopeKey,
    String? friendFallbackPublicKey,
  }) async {
    final decoded = jsonDecode(encryptedPayload) as Map<String, dynamic>;
    final senderPk = decoded['senderPublicKey'] as String?;
    final recipientPk = decoded['recipientPublicKey'] as String?;

    final String remotePublicKey;
    if (senderPk != null &&
        recipientPk != null &&
        senderPk.isNotEmpty &&
        recipientPk.isNotEmpty) {
      remotePublicKey = iAmSender ? recipientPk : senderPk;
    } else {
      remotePublicKey = friendFallbackPublicKey ?? '';
      if (remotePublicKey.isEmpty) {
        throw StateError('Missing public key for decryption.');
      }
    }

    final secretKey = await _sharedSecret(remotePublicKey, scopeKey: scopeKey);
    final clearBytes = await _cipher.decrypt(
      SecretBox(
        base64Decode(decoded['cipherText'] as String),
        nonce: base64Decode(decoded['nonce'] as String),
        mac: Mac(base64Decode(decoded['mac'] as String)),
      ),
      secretKey: secretKey,
    );

    return jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
  }

  Future<SecretKey> _sharedSecret(
    String remotePublicKey, {
    required String scopeKey,
  }) async {
    final privateValue = await _storage.read(key: _privateKeyKey(scopeKey));
    final publicValue = await _storage.read(key: _publicKeyKey(scopeKey));
    if (privateValue == null || publicValue == null) {
      await getOrCreatePublicKey(scopeKey: scopeKey);
    }

    final keyPair = SimpleKeyPairData(
      base64Decode((await _storage.read(key: _privateKeyKey(scopeKey)))!),
      publicKey: SimplePublicKey(
        base64Decode((await _storage.read(key: _publicKeyKey(scopeKey)))!),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );

    return _keyExchange.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        base64Decode(remotePublicKey),
        type: KeyPairType.x25519,
      ),
    );
  }
}

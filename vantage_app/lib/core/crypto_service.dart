import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../database/database_helper.dart';
import 'crypto.dart';

class CryptoService {
  static final _dbHelper = DatabaseHelper.instance;

  /// Generates a new keypair, saves it to database, and returns the hex-encoded public key.
  static Future<String> generateAndSaveKeyPair() async {
    final keyPair = await VantageCrypto.generateKeyPair();
    
    // Extract public key bytes
    final pubKey = await keyPair.extractPublicKey();
    final pubHex = _bytesToHex(pubKey.bytes);

    // Extract private key (seed) bytes
    final privKey = await keyPair.extractPrivateKeyBytes();
    final privHex = _bytesToHex(privKey);

    await _dbHelper.saveKeys(pubHex, privHex);
    return pubHex;
  }

  /// Checks if keys are already generated.
  static Future<bool> hasKeys() async {
    final keys = await _dbHelper.getLatestKeys();
    return keys != null;
  }

  /// Gets the stored public key hex.
  static Future<String?> getPublicKey() async {
    final keys = await _dbHelper.getLatestKeys();
    if (keys == null) return null;
    return keys['public_key'] as String;
  }

  /// Gets the stored user ID.
  static Future<String?> getUserId() async {
    final keys = await _dbHelper.getLatestKeys();
    if (keys == null) return null;
    return keys['user_id'] as String?;
  }

  /// Gets the stored display name.
  static Future<String?> getDisplayName() async {
    final keys = await _dbHelper.getLatestKeys();
    if (keys == null) return null;
    return keys['display_name'] as String?;
  }

  /// Updates local user registration details.
  static Future<void> updateRegisteredUser(String userId, String displayName) async {
    final pubKey = await getPublicKey();
    if (pubKey != null) {
      await _dbHelper.updateUserData(pubKey, userId, displayName);
    }
  }

  /// Signs a string message using the stored private key.
  /// Returns a hex-encoded signature.
  static Future<String> signMessage(String message) async {
    final keys = await _dbHelper.getLatestKeys();
    if (keys == null) {
      throw Exception("No cryptographic keys found on device. Generate keys first.");
    }
    
    final privHex = keys['private_key_data'] as String;
    final seedBytes = _hexToBytes(privHex);
    
    // Reconstruct the key pair
    final keyPair = await VantageCrypto.algorithm.newKeyPairFromSeed(seedBytes);
    
    final messageBytes = utf8.encode(message);
    final signature = await VantageCrypto.sign(Uint8List.fromList(messageBytes), keyPair);
    
    return _bytesToHex(signature.bytes);
  }

  /// Verifies a signature (hex) of a message against a public key (hex).
  static Future<bool> verifySignature(String message, String signatureHex, String publicKeyHex) async {
    try {
      final messageBytes = utf8.encode(message);
      final sigBytes = _hexToBytes(signatureHex);
      final pubBytes = _hexToBytes(publicKeyHex);
      
      final signature = Signature(sigBytes, publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519));
      return await VantageCrypto.verify(Uint8List.fromList(messageBytes), signature);
    } catch (_) {
      return false;
    }
  }

  // --- Helper Methods ---

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hexString) {
    final result = Uint8List(hexString.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hexString.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

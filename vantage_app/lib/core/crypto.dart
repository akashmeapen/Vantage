import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// VantageCrypto provides the cryptographic foundation for Project Vantage.
/// 
/// It uses Ed25519 for digital signatures, ensuring that vouchers and 
/// payment envelopes cannot be tampered with while offline.
class VantageCrypto {
  static final algorithm = Ed25519();

  /// Generates a new Ed25519 key pair for a user or the system.
  static Future<SimpleKeyPair> generateKeyPair() async {
    return await algorithm.newKeyPair();
  }

  /// Signs a message (e.g., a serialized Voucher) using a private key.
  static Future<Signature> sign(Uint8List message, SimpleKeyPair keyPair) async {
    return await algorithm.sign(
      message,
      keyPair: keyPair,
    );
  }

  /// Verifies a signature against a message and a public key.
  /// 
  /// The [signature] object must contain the public key against which
  /// the verification is performed.
  static Future<bool> verify(Uint8List message, Signature signature) async {
    return await algorithm.verify(
      message,
      signature: signature,
    );
  }

  /// Helper to convert a public key to a hex string for storage/display.
  static Future<String> publicKeyToHex(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    return publicKey.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

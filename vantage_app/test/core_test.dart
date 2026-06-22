import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_app/core/crypto.dart';
import 'package:vantage_app/core/models/voucher.dart';
import 'package:vantage_app/core/models/envelope.dart';

void main() {
  group('Vantage Core Security Tests', () {
    test('Ed25519 Key Generation and Hex Conversion', () async {
      final keyPair = await VantageCrypto.generateKeyPair();
      final hex = await VantageCrypto.publicKeyToHex(keyPair);
      
      expect(hex.length, 64, reason: 'Ed25519 public keys should be 32 bytes (64 hex chars)');
      print('Generated Public Key: $hex');
    });

    test('Voucher Signing and Verification', () async {
      final keyPair = await VantageCrypto.generateKeyPair();
      
      final voucher = Voucher(
        id: 'v-123',
        issuerId: await VantageCrypto.publicKeyToHex(keyPair),
        amount: 50.0,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      // 1. Sign the voucher
      final message = Uint8List.fromList(utf8.encode(voucher.signingData));
      final signature = await VantageCrypto.sign(message, keyPair);
      
      // 2. Verify the voucher
      final isValid = await VantageCrypto.verify(message, signature);
      expect(isValid, isTrue, reason: 'Signature should be valid for untampered data');

      // 3. Verify failure on tampering
      final tamperedMessage = Uint8List.fromList(utf8.encode(voucher.signingData.replaceFirst('50.0', '100.0')));
      final isTamperedValid = await VantageCrypto.verify(tamperedMessage, signature);
      expect(isTamperedValid, isFalse, reason: 'Signature must fail if amount is changed');
    });

    test('Envelope Wrapping and Sender Authentication', () async {
      final mintKeys = await VantageCrypto.generateKeyPair();
      final senderKeys = await VantageCrypto.generateKeyPair();
      final receiverId = 'receiver-public-key-hex';

      final voucher = Voucher(
        id: 'v-456',
        issuerId: await VantageCrypto.publicKeyToHex(mintKeys),
        amount: 25.0,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      final envelope = Envelope(
        id: 'env-789',
        voucher: voucher,
        senderId: await VantageCrypto.publicKeyToHex(senderKeys),
        receiverId: receiverId,
        timestamp: DateTime.now(),
      );

      // Sender signs the envelope hand-off
      final message = Uint8List.fromList(utf8.encode(envelope.signingData));
      final signature = await VantageCrypto.sign(message, senderKeys);
      
      final isValid = await VantageCrypto.verify(message, signature);
      expect(isValid, isTrue, reason: 'Receiver should be able to verify sender authenticity');
    });
  });
}

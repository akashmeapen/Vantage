import 'dart:math';
import 'crypto_service.dart';
import 'models/envelope.dart';
import 'models/voucher.dart';

class EnvelopeBuilder {
  /// Generates a secure random 128-bit hex string to use as a unique ID.
  static String generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Builds and signs a digital envelope enclosing a voucher.
  static Future<Envelope> buildAndSignEnvelope({
    required Voucher voucher,
    required String senderId,
    required String receiverId,
  }) async {
    final envelopeId = generateId();
    final timestamp = DateTime.now().toUtc();

    // Create an unsigned envelope first to generate the signing data
    final unsignedEnvelope = Envelope(
      id: envelopeId,
      voucher: voucher,
      senderId: senderId,
      receiverId: receiverId,
      timestamp: timestamp,
    );

    // Sign the envelope's signingData
    final signature = await CryptoService.signMessage(unsignedEnvelope.signingData);

    return Envelope(
      id: envelopeId,
      voucher: voucher,
      senderId: senderId,
      receiverId: receiverId,
      timestamp: timestamp,
      senderSignature: signature,
    );
  }
}

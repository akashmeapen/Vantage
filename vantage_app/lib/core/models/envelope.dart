import 'package:json_annotation/json_annotation.dart';
import 'voucher.dart';

part 'envelope.g.dart';

/// An Envelope wraps a Voucher with transport-specific metadata.
/// 
/// It is used to securely move value from one device to another offline.
/// The envelope itself might be signed by the sender to prove they are 
/// the one handing it over.
@JsonSerializable()
class Envelope {
  final String id;
  final Voucher voucher;
  final String senderId; // Public key of the current sender
  final String receiverId; // Public key of the intended receiver (optional)
  final DateTime timestamp;

  /// Hex-encoded signature of the envelope by the sender
  final String? senderSignature;

  Envelope({
    required this.id,
    required this.voucher,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    this.senderSignature,
  });

  factory Envelope.fromJson(Map<String, dynamic> json) => _$EnvelopeFromJson(json);
  Map<String, dynamic> toJson() => _$EnvelopeToJson(this);

  /// Returns the data string that should be signed by the sender.
  String get signingData => "$id|${voucher.id}|$senderId|$receiverId|${timestamp.toIso8601String()}";
}

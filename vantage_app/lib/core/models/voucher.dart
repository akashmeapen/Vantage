import 'package:json_annotation/json_annotation.dart';

part 'voucher.g.dart';

/// A Voucher represents a digital credit issued by a mint or user.
/// 
/// It contains its own value and a signature from the issuer certifying
/// that the credit is valid.
@JsonSerializable()
class Voucher {
  final String id;
  final String issuerId; // Public key of the issuer
  final double amount;
  final DateTime createdAt;
  final DateTime expiresAt;
  
  /// Hex-encoded signature of the voucher's data
  final String? signature;

  Voucher({
    required this.id,
    required this.issuerId,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
    this.signature,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) => _$VoucherFromJson(json);
  Map<String, dynamic> toJson() => _$VoucherToJson(this);

  /// Returns the data string that should be signed.
  String get signingData => "$id|$issuerId|$amount|${createdAt.toIso8601String()}|${expiresAt.toIso8601String()}";
}

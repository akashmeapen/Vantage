// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voucher.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Voucher _$VoucherFromJson(Map<String, dynamic> json) => Voucher(
      id: json['id'] as String,
      issuerId: json['issuerId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      payload: json['payload'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      signature: json['signature'] as String?,
    );

Map<String, dynamic> _$VoucherToJson(Voucher instance) => <String, dynamic>{
      'id': instance.id,
      'issuerId': instance.issuerId,
      'amount': instance.amount,
      'currency': instance.currency,
      'status': instance.status,
      'payload': instance.payload,
      'createdAt': instance.createdAt.toIso8601String(),
      'expiresAt': instance.expiresAt.toIso8601String(),
      'signature': instance.signature,
    };

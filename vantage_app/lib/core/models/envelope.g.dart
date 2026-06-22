// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Envelope _$EnvelopeFromJson(Map<String, dynamic> json) => Envelope(
      id: json['id'] as String,
      voucher: Voucher.fromJson(json['voucher'] as Map<String, dynamic>),
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      senderSignature: json['senderSignature'] as String?,
    );

Map<String, dynamic> _$EnvelopeToJson(Envelope instance) => <String, dynamic>{
      'id': instance.id,
      'voucher': instance.voucher,
      'senderId': instance.senderId,
      'receiverId': instance.receiverId,
      'timestamp': instance.timestamp.toIso8601String(),
      'senderSignature': instance.senderSignature,
    };

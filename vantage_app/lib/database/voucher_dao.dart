import '../core/models/voucher.dart';
import 'database_helper.dart';

class VoucherDao {
  final _dbHelper = DatabaseHelper.instance;

  /// Inserts or replaces a voucher in local storage.
  Future<void> saveVoucher(Voucher voucher) async {
    await _dbHelper.insertVoucher(voucher);
  }

  /// Retrieves all cached vouchers from local storage.
  Future<List<Voucher>> getVouchers() async {
    return await _dbHelper.getAllVouchers();
  }

  /// Retrieves a specific voucher by its ID.
  Future<Voucher?> getVoucherById(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'vouchers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    final json = result.first;
    return Voucher(
      id: json['id'] as String,
      issuerId: json['issuer_id'] as String,
      amount: json['amount'] as double,
      currency: json['currency'] as String,
      status: json['status'] as String,
      payload: json['payload'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      signature: json['signature'] as String,
    );
  }
}

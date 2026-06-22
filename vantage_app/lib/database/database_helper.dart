import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models/voucher.dart';
import '../core/models/envelope.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vantage.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Table for User Keys (Private and Public)
    await db.execute('''
      CREATE TABLE user_keys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        public_key TEXT NOT NULL,
        private_key_data TEXT NOT NULL, -- Hex or Base64 encoded
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Table for Received Vouchers
    await db.execute('''
      CREATE TABLE vouchers (
        id TEXT PRIMARY KEY,
        issuer_id TEXT NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        signature TEXT NOT NULL
      )
    ''');

    // 3. Table for Outgoing/Pending Envelopes
    await db.execute('''
      CREATE TABLE pending_sync (
        id TEXT PRIMARY KEY,
        envelope_json TEXT NOT NULL, -- Full JSON representation
        status TEXT DEFAULT 'pending', -- pending, synced, failed
        created_at TEXT NOT NULL
      )
    ''');
  }

  // --- CRUD Operations for Keys ---
  
  Future<void> saveKeys(String publicKey, String privateKeyData) async {
    final db = await instance.database;
    await db.insert('user_keys', {
      'public_key': publicKey,
      'private_key_data': privateKeyData,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getLatestKeys() async {
    final db = await instance.database;
    final maps = await db.query('user_keys', orderBy: 'id DESC', limit: 1);
    return maps.isNotEmpty ? maps.first : null;
  }

  // --- CRUD Operations for Vouchers ---

  Future<void> insertVoucher(Voucher voucher) async {
    final db = await instance.database;
    await db.insert(
      'vouchers',
      {
        'id': voucher.id,
        'issuer_id': voucher.issuerId,
        'amount': voucher.amount,
        'created_at': voucher.createdAt.toIso8601String(),
        'expires_at': voucher.expiresAt.toIso8601String(),
        'signature': voucher.signature ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Voucher>> getAllVouchers() async {
    final db = await instance.database;
    final result = await db.query('vouchers');
    return result.map((json) {
      return Voucher(
        id: json['id'] as String,
        issuerId: json['issuer_id'] as String,
        amount: json['amount'] as double,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        signature: json['signature'] as String,
      );
    }).toList();
  }

  // --- CRUD Operations for Syncing ---

  Future<void> queueEnvelopeForSync(Envelope envelope) async {
    final db = await instance.database;
    await db.insert('pending_sync', {
      'id': envelope.id,
      'envelope_json': jsonEncode(envelope.toJson()),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> close() async {
    final db = await _database;
    if (db != null) await db.close();
  }
}
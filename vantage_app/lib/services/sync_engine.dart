import 'dart:convert';
import 'dart:developer' as developer;
import '../database/database_helper.dart';
import '../core/models/envelope.dart';
import 'api_client.dart';

class SyncEngine {
  final ApiClient _apiClient;
  bool _isSyncing = false;

  SyncEngine({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Starts the sync process to upload all pending payment envelopes.
  Future<void> syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final db = await DatabaseHelper.instance.database;
      
      // Fetch pending sync transactions
      final List<Map<String, dynamic>> pendingList = await db.query(
        'pending_sync',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );

      if (pendingList.isEmpty) {
        _isSyncing = false;
        return;
      }

      developer.log('SyncEngine: Found ${pendingList.length} pending settlements to sync.');

      for (final row in pendingList) {
        final id = row['id'] as String;
        final envelopeJsonStr = row['envelope_json'] as String;

        try {
          final envelopeMap = jsonDecode(envelopeJsonStr) as Map<String, dynamic>;
          final envelope = Envelope.fromJson(envelopeMap);

          // Attempt to settle payment on the server
          await _apiClient.settlePayment(envelope);

          // Success: Mark as synced
          await db.update(
            'pending_sync',
            {'status': 'synced'},
            where: 'id = ?',
            whereArgs: [id],
          );
          developer.log('SyncEngine: Successfully synced envelope $id.');
        } catch (e) {
          final errStr = e.toString();
          if (errStr.contains('DUPLICATE')) {
            // Already settled on server: Mark as synced (idempotency safety)
            await db.update(
              'pending_sync',
              {'status': 'synced'},
              where: 'id = ?',
              whereArgs: [id],
            );
            developer.log('SyncEngine: Envelope $id was already settled on server. Marked as synced.');
          } else {
            // Still offline or transient error: Halt sync to retry later
            developer.log('SyncEngine: Sync failed for envelope $id. Error: $e. Halting sync.');
            break;
          }
        }
      }
    } catch (e) {
      developer.log('SyncEngine: Error in sync engine run: $e');
    } finally {
      _isSyncing = false;
    }
  }
}

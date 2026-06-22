import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/user_model.dart';
import '../core/models/envelope.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = 'http://10.0.2.2:8080'}); // Default to Android emulator loopback, configurable

  /// Checks the backend health. Returns true if healthy, false otherwise.
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      }
    } catch (_) {
      // Offline or error
    }
    return false;
  }

  /// Registers a user using their display name and public key.
  /// Returns the registered User or throws an exception on failure.
  Future<User> register(String displayName, String publicKey) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'display_name': displayName,
        'public_key': publicKey,
      }),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 201) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      try {
        final Map<String, dynamic> err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Registration failed with status: ${response.statusCode}');
      } catch (_) {
        throw Exception('Registration failed with status: ${response.statusCode}');
      }
    }
  }

  /// Sends a signed envelope containing a voucher to be minted on the backend.
  Future<void> mintVoucher(Envelope envelope) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mint-voucher'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(envelope.toJson()),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 201) {
      try {
        final Map<String, dynamic> err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Minting failed with status: ${response.statusCode}');
      } catch (_) {
        throw Exception('Minting failed with status: ${response.statusCode}');
      }
    }
  }

  /// Sends a signed envelope to settle a payment on the backend.
  Future<void> settlePayment(Envelope envelope) async {
    final response = await http.post(
      Uri.parse('$baseUrl/settle-payment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(envelope.toJson()),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 409) {
      throw Exception('DUPLICATE: This payment has already been settled');
    } else if (response.statusCode != 200) {
      try {
        final Map<String, dynamic> err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Settlement failed with status: ${response.statusCode}');
      } catch (_) {
        throw Exception('Settlement failed with status: ${response.statusCode}');
      }
    }
  }
}

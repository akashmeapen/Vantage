import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/crypto_service.dart';
import '../core/envelope_builder.dart';
import '../core/models/envelope.dart';
import '../core/models/voucher.dart';
import '../database/voucher_dao.dart';
import '../services/api_client.dart';

class MintScreen extends StatefulWidget {
  const MintScreen({super.key});

  @override
  State<MintScreen> createState() => _MintScreenState();
}

class _MintScreenState extends State<MintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _apiClient = ApiClient();
  final _voucherDao = VoucherDao();
  
  String _selectedCurrency = 'USD';
  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'INR', 'JPY'];
  
  bool _isLoading = false;
  Voucher? _mintedVoucher;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _mintVoucher() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _mintedVoucher = null;
    });

    try {
      final amount = double.parse(_amountController.text.trim());
      final pubKey = await CryptoService.getPublicKey();
      if (pubKey == null) {
        throw Exception("Identity keypair not found. Please set up keys first.");
      }

      final voucherId = EnvelopeBuilder.generateId();
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(const Duration(days: 30));

      // 1. Create unsigned Voucher
      final tempVoucher = Voucher(
        id: voucherId,
        issuerId: pubKey,
        amount: amount,
        currency: _selectedCurrency,
        status: 'minted',
        payload: 'Vantage Voucher - $amount $_selectedCurrency',
        createdAt: now,
        expiresAt: expiresAt,
      );

      // 2. Sign the Voucher signing data
      final voucherSignature = await CryptoService.signMessage(tempVoucher.signingData);

      // 3. Create fully signed Voucher
      final signedVoucher = Voucher(
        id: voucherId,
        issuerId: pubKey,
        amount: amount,
        currency: _selectedCurrency,
        status: 'minted',
        payload: tempVoucher.payload,
        createdAt: now,
        expiresAt: expiresAt,
        signature: voucherSignature,
      );

      // 4. Wrap inside Envelope and Sign the Envelope
      final envelope = await EnvelopeBuilder.buildAndSignEnvelope(
        voucher: signedVoucher,
        senderId: pubKey,
        receiverId: '', // Blank receiver since it's newly minted (open voucher)
      );

      // 5. Send to Go Backend
      await _apiClient.mintVoucher(envelope);

      // 6. Save locally on success
      await _voucherDao.saveVoucher(signedVoucher);

      setState(() {
        _mintedVoucher = signedVoucher;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voucher successfully minted & registered! ✓'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mint voucher: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mint Voucher',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF1E1035),
              Color(0xFF0F0C20),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Create New Digital Value',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Minted vouchers are signed with your key and registered on the network.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Currency dropdown
                  Text(
                    'CURRENCY',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8E2DE2),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        dropdownColor: const Color(0xFF1E1035),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                        isExpanded: true,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCurrency = newValue;
                            });
                          }
                        },
                        items: _currencies.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Amount field
                  Text(
                    'AMOUNT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8E2DE2),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.35)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF8E2DE2), width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFEF4444)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an amount';
                      }
                      final amt = double.tryParse(value);
                      if (amt == null || amt <= 0) {
                        return 'Please enter a valid positive number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),
                  // Mint button
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _mintVoucher,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E2DE2),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF8E2DE2).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : Text(
                              'Generate & Sign Voucher',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Success card
                  if (_mintedVoucher != null) ...[
                    Text(
                      'MINTED VOUCHER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vantage Credit',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: Text(
                                  'MINTED',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '${_mintedVoucher!.amount.toStringAsFixed(2)} ${_mintedVoucher!.currency}',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 12),
                          _buildDetailRow('Voucher ID', _mintedVoucher!.id),
                          const SizedBox(height: 8),
                          _buildDetailRow('Issuer Key', _mintedVoucher!.issuerId.substring(0, 16) + '...'),
                          const SizedBox(height: 8),
                          _buildDetailRow('Expires At', _mintedVoucher!.expiresAt.toString().substring(0, 10)),
                          const SizedBox(height: 8),
                          _buildDetailRow('Signature', _mintedVoucher!.signature!.substring(0, 16) + '...'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        Text(
          value,
          style: GoogleFonts.firaCode(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }
}

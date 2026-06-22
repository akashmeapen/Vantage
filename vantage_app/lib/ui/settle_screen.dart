import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/crypto_service.dart';
import '../core/envelope_builder.dart';
import '../core/models/envelope.dart';
import '../core/models/voucher.dart';
import '../database/database_helper.dart';
import '../database/voucher_dao.dart';
import '../services/api_client.dart';

class SettleScreen extends StatefulWidget {
  const SettleScreen({super.key});

  @override
  State<SettleScreen> createState() => _SettleScreenState();
}

class _SettleScreenState extends State<SettleScreen> {
  final _apiClient = ApiClient();
  final _voucherDao = VoucherDao();
  final _receiverController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Voucher> _vouchers = [];
  Voucher? _selectedVoucher;
  bool _isLoading = false;
  bool _isSuccess = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  @override
  void dispose() {
    _receiverController.dispose();
    super.dispose();
  }

  Future<void> _loadVouchers() async {
    final list = await _voucherDao.getVouchers();
    // Filter only those not settled locally
    final available = list.where((v) => v.status == 'minted').toList();
    setState(() {
      _vouchers = available;
      if (available.isNotEmpty) {
        _selectedVoucher = available.first;
      } else {
        _selectedVoucher = null;
      }
    });
  }

  Future<void> _settlePayment() async {
    if (_selectedVoucher == null) return;

    setState(() {
      _isLoading = true;
      _isSuccess = false;
      _statusMessage = '';
    });

    try {
      final pubKey = await CryptoService.getPublicKey();
      if (pubKey == null) {
        throw Exception("Identity keypair not found. Please setup keys first.");
      }

      final receiverId = _receiverController.text.trim();

      // 1. Build and sign digital envelope
      final envelope = await EnvelopeBuilder.buildAndSignEnvelope(
        voucher: _selectedVoucher!,
        senderId: pubKey,
        receiverId: receiverId,
      );

      try {
        // 2. Attempt settlement with server
        await _apiClient.settlePayment(envelope);

        // 3. Success: Update local status to settled
        final updatedVoucher = Voucher(
          id: _selectedVoucher!.id,
          issuerId: _selectedVoucher!.issuerId,
          amount: _selectedVoucher!.amount,
          currency: _selectedVoucher!.currency,
          status: 'settled',
          payload: _selectedVoucher!.payload,
          createdAt: _selectedVoucher!.createdAt,
          expiresAt: _selectedVoucher!.expiresAt,
          signature: _selectedVoucher!.signature,
        );
        await _voucherDao.saveVoucher(updatedVoucher);

        setState(() {
          _isSuccess = true;
          _statusMessage = 'Payment successfully settled on the server! ✓';
        });
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('DUPLICATE')) {
          // Voucher already settled on server: Update local status
          final updatedVoucher = Voucher(
            id: _selectedVoucher!.id,
            issuerId: _selectedVoucher!.issuerId,
            amount: _selectedVoucher!.amount,
            currency: _selectedVoucher!.currency,
            status: 'settled',
            payload: _selectedVoucher!.payload,
            createdAt: _selectedVoucher!.createdAt,
            expiresAt: _selectedVoucher!.expiresAt,
            signature: _selectedVoucher!.signature,
          );
          await _voucherDao.saveVoucher(updatedVoucher);

          setState(() {
            _isSuccess = true;
            _statusMessage = 'This voucher has already been settled on the server.';
          });
        } else {
          // Offline / Network error: Queue for sync
          await DatabaseHelper.instance.queueEnvelopeForSync(envelope);
          
          // Also mark voucher as settled locally since the envelope has been signed and handed over
          final updatedVoucher = Voucher(
            id: _selectedVoucher!.id,
            issuerId: _selectedVoucher!.issuerId,
            amount: _selectedVoucher!.amount,
            currency: _selectedVoucher!.currency,
            status: 'settled', // Set to settled locally
            payload: _selectedVoucher!.payload,
            createdAt: _selectedVoucher!.createdAt,
            expiresAt: _selectedVoucher!.expiresAt,
            signature: _selectedVoucher!.signature,
          );
          await _voucherDao.saveVoucher(updatedVoucher);

          setState(() {
            _isSuccess = true;
            _statusMessage = 'Device offline. Signed envelope queued. Will sync when online! ✓';
          });
        }
      }

      await _loadVouchers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement failed: $e'),
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
          'Buyer Wallet',
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
                    'Settle Payments Offline-First',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a voucher from your wallet and sign the envelope to settle it.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_vouchers.isEmpty) ...[
                    // Empty wallet state
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 48, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'Your wallet is empty',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mint vouchers in Merchant Mode first to load credits.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Voucher selector dropdown
                    Text(
                      'SELECT VOUCHER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00C6FF),
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
                        child: DropdownButton<Voucher>(
                          value: _selectedVoucher,
                          dropdownColor: const Color(0xFF1E1035),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                          isExpanded: true,
                          onChanged: (Voucher? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedVoucher = newValue;
                              });
                            }
                          },
                          items: _vouchers.map<DropdownMenuItem<Voucher>>((Voucher v) {
                            return DropdownMenuItem<Voucher>(
                              value: v,
                              child: Text(
                                '${v.amount.toStringAsFixed(2)} ${v.currency} (ID: ${v.id.substring(0, 8)}...)',
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Receiver public key field
                    Text(
                      'RECEIVER IDENTITY KEY (OPTIONAL)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00C6FF),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _receiverController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter receiver public key hex',
                        hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.35)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF00C6FF), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Settle Button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _settlePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C6FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF00C6FF).withOpacity(0.4),
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
                                'Settle Voucher',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  // Success feedback card
                  if (_isSuccess) ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 32, color: Color(0xFF10B981)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Settlement Event',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _statusMessage,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/crypto_service.dart';
import 'home_screen.dart';

class KeySetupScreen extends StatefulWidget {
  const KeySetupScreen({super.key});

  @override
  State<KeySetupScreen> createState() => _KeySetupScreenState();
}

class _KeySetupScreenState extends State<KeySetupScreen> {
  bool _isGenerating = false;
  String? _publicKeyHex;

  Future<void> _generateKeys() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      // Simulate slight delay for premium animation feel
      await Future.delayed(const Duration(milliseconds: 800));
      final pubKey = await CryptoService.generateAndSaveKeyPair();
      setState(() {
        _publicKeyHex = pubKey;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate keys: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6200EE).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6200EE).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _publicKeyHex != null ? Icons.verified_user_rounded : Icons.security_rounded,
                    size: 72,
                    color: _publicKeyHex != null ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _publicKeyHex != null ? 'Security Keys Configured' : 'Setup Vantage Security Keys',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _publicKeyHex != null
                      ? 'Your unique Ed25519 identity key pair has been generated and saved locally. Keep it secure!'
                      : 'Vantage requires Ed25519 cryptographic keys to mint and settle vouchers completely offline.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                if (_publicKeyHex != null) ...[
                  // Public key display card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'YOUR PUBLIC IDENTITY KEY',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF8B5CF6),
                                letterSpacing: 1.5,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _publicKeyHex!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Public key copied to clipboard!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              color: Colors.white.withOpacity(0.6),
                              tooltip: 'Copy key',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _publicKeyHex!,
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
                // Action Buttons
                if (_isGenerating)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                  )
                else if (_publicKeyHex == null)
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _generateKeys,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Generate Identity Keypair',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue to App',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

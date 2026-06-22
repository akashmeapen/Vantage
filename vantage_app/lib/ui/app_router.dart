import 'package:flutter/material.dart';
import 'landing_screen.dart';
import 'home_screen.dart';
import 'key_setup_screen.dart';
import 'register_screen.dart';
import 'mint_screen.dart';
import 'settle_screen.dart';
import '../core/crypto_service.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: CryptoService.hasKeys(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0C20),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),
          );
        }

        final hasKeys = snapshot.data ?? false;
        if (!hasKeys) {
          return const LandingScreen();
        }

        return FutureBuilder<String?>(
          future: CryptoService.getUserId(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0F0C20),
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                  ),
                ),
              );
            }

            final registered = userSnapshot.data != null;
            if (!registered) {
              return const RegisterScreen();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }

  // Navigation helpers
  static void navigateToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  static void navigateToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  static void navigateToMint(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MintScreen()),
    );
  }

  static void navigateToSettle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettleScreen()),
    );
  }
}

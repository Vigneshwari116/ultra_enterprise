import 'package:flutter/material.dart';

import '../widgets/enterprise_widgets.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool obscurePass = true;

  static const _fieldFill = Color(0xFFF3F5F8);
  static const _labelGray = Color(0xFF8B95A5);
  static const _signInTeal = Color(0xFF11B9B5);

  static const _validEmail = 'ultra.engineering@gmail.com';
  static const _validPassword = '12345678';

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  void _enterPlatform() {
    final id = email.text.trim();
    final key = pass.text;
    if (id != _validEmail || key != _validPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid account identification or security key.')),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool focused = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF9AA5B4)),
      filled: true,
      fillColor: _fieldFill,
      prefixIcon: Icon(prefixIcon, size: 20, color: focused ? _signInTeal : _labelGray),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: focused ? _signInTeal : Colors.transparent, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _signInTeal, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: compact ? 28 : 48, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'System Sign In',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Provide certified credentials below to sync ledger registries.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _labelGray,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'ACCOUNT IDENTIFICATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _labelGray,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.username],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: navy),
                    decoration: _fieldDecoration(
                      hint: 'Enter account email',
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'ACCOUNT SECURITY KEY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _labelGray,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pass,
                    obscureText: obscurePass,
                    autofillHints: const [AutofillHints.password],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: navy),
                    decoration: _fieldDecoration(
                      hint: 'Enter security key',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscurePass = !obscurePass),
                        icon: Icon(
                          obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: _signInTeal,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _enterPlatform,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _signInTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'AUTHENTICATE FINANCE ARCHITECTURE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Center(
                    child: Text(
                      'FINANCIAL CONTEXT DESCRIPTOR APP CORE ENGINE v1.1.0-STABLE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB8C0CC),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

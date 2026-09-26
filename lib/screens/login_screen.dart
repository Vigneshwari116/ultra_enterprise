import 'package:flutter/material.dart';

import '../widgets/enterprise_widgets.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'ultra.engineering@gmail.com');
  final pass = TextEditingController(text: '12345678');
  bool obscurePass = true;

  static const _leftBg = Color(0xFF0A1424);
  static const _fieldFill = Color(0xFFF3F5F8);
  static const _labelGray = Color(0xFF8B95A5);
  static const _signInTeal = Color(0xFF11B9B5);

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  void _enterPlatform() {
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
      hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF39485A)),
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

  Widget _brandPanel({required bool compact}) {
    return Container(
      color: _leftBg,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 28 : 56,
        vertical: compact ? 32 : 48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/ultra_logo.png',
            height: compact ? 52 : 64,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
          SizedBox(height: compact ? 16 : 24),
          Row(
            children: const [
              Icon(Icons.account_balance_outlined, color: _signInTeal, size: 22),
              SizedBox(width: 10),
              Text(
                'CORE FINANCE LOGISTICS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 24 : 40),
          Text(
            'Commercial Ledger &\nAuditing Portal Engine.',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 28 : 38,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Secure multi-tenant accounting core gateway. Enter corporate digital certificates signature keys to sync unified data directories ledger sheets.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: compact ? 13 : 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 28 : 48),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: const [
              _StatusBadge(label: 'AES-256 BANKING ENCRYPTION'),
              _StatusBadge(label: 'COMPLIANT TAX WORKSPACE'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _signInPanel({required bool compact}) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 28 : 72,
        vertical: compact ? 32 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: navy),
                decoration: _fieldDecoration(
                  hint: 'ultra.engineering@gmail.com',
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: navy),
                decoration: _fieldDecoration(
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  focused: true,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;

    return Scaffold(
      body: compact
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brandPanel(compact: true),
                  _signInPanel(compact: true),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _brandPanel(compact: false)),
                Expanded(child: _signInPanel(compact: false)),
              ],
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

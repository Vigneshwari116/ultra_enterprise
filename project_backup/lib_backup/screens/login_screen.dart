import 'package:flutter/material.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController(text: 'SUPERUSER');
  final pass = TextEditingController();
  @override
  void dispose() { user.dispose(); pass.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10233F),
      body: Center(
        child: SizedBox(
          width: 420,
          child: Card(
            elevation: 12,
            margin: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('COMMERCIAL ENTERPRISE PLATFORM ENGINE',
                    style: TextStyle(color: Color(0xFF10233F), fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('SECURE ACCESS TERMINAL',
                    style: TextStyle(color: Color(0xFF748094), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 26),
                TextField(controller: user, decoration: const InputDecoration(labelText: 'USERNAME')),
                const SizedBox(height: 14),
                TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'PASSWORD')),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell())),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10233F), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                  child: const Text('ENTER PLATFORM'),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

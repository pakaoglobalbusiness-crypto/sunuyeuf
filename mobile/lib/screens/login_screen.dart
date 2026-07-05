import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'home_screen.dart';
import 'complete_profile_screen.dart';
import 'terms_screen.dart';

/// Connexion par numéro de téléphone + OTP SMS (F1).
/// Pas de mot de passe : simplicité maximale.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String? _devCode;

  Future<void> _requestOtp() async {
    setState(() => (_loading = true, _error = null));
    try {
      final res = await Api.post('/auth/otp/request', body: {'phone': _phoneCtrl.text});
      setState(() {
        _codeSent = true;
        _devCode = res['devCode'];
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() => (_loading = true, _error = null));
    try {
      final res = await Api.post('/auth/otp/verify', body: {
        'phone': _phoneCtrl.text,
        'code': _codeCtrl.text,
      });
      await Api.setSession(res['token'], res['user']);
      if (!mounted) return;
      final u = res['user'] ?? {};
      final hasName = (u['firstName'] as String?)?.isNotEmpty ?? false;
      final accepted = u['acceptedTermsAt'] != null;
      // 1) profil (prénom/nom) obligatoire, 2) conditions, 3) app
      final next = !hasName
          ? const CompleteProfileScreen()
          : (accepted ? const HomeScreen() : const TermsScreen());
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: gologuiTeal,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/icon/icon.png', height: 110),
                    ),
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(text: 'Golo'),
                        TextSpan(text: 'gui', style: TextStyle(color: gologuiOrange)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Villas et voitures à louer, partout au Sénégal',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          if (!_codeSent) ...[
                            TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Numéro de téléphone',
                                hintText: '+221, +33, +1... (format international)',
                                prefixIcon: Icon(Icons.phone),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _loading ? null : _requestOtp,
                              child: Text(_loading ? 'Envoi…' : 'Recevoir le code SMS'),
                            ),
                          ] else ...[
                            if (_devCode != null)
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9D6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Mode démo — votre code : $_devCode',
                                  style: const TextStyle(color: Color(0xFF5C4B00)),
                                ),
                              ),
                            TextField(
                              controller: _codeCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                labelText: 'Code reçu par SMS',
                                counterText: '',
                                prefixIcon: Icon(Icons.sms),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _loading ? null : _verify,
                              child: Text(_loading ? 'Vérification…' : 'Se connecter'),
                            ),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(() => _codeSent = false),
                              child: const Text('Changer de numéro'),
                            ),
                          ],
                        ],
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

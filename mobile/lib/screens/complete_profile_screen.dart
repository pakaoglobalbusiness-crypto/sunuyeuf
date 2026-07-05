import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'home_screen.dart';
import 'terms_screen.dart';

/// Complétion obligatoire du profil juste après l'OTP :
/// prénom + nom requis, e-mail optionnel. Le téléphone vient de l'OTP.
/// Style identique à l'écran de connexion (fond vert, logo, carte).
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;
  String? _emailError;

  bool get _valid =>
      _firstCtrl.text.trim().isNotEmpty && _lastCtrl.text.trim().isNotEmpty;

  bool _emailOk(String e) =>
      e.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    if (!_emailOk(email)) {
      setState(() => _emailError = 'Adresse e-mail invalide');
      return;
    }
    setState(() => _saving = true);
    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    try {
      await Api.patch('/users/me', body: {
        'firstName': first,
        'lastName': last,
        'name': '$first $last',
        if (email.isNotEmpty) 'email': email,
      });
      final me = await Api.get('/users/me');
      Api.currentUser = me;
      if (!mounted) return;
      final termsOk = me['acceptedTermsAt'] != null;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => termsOk ? const HomeScreen() : const TermsScreen(),
        ),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                        child: Image.asset('assets/icon/icon.png', height: 90),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Faisons connaissance 👋',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ces informations rassurent les autres utilisateurs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _firstCtrl,
                              onChanged: (_) => setState(() {}),
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Prénom *',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _lastCtrl,
                              onChanged: (_) => setState(() {}),
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Nom *',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _emailCtrl,
                              onChanged: (_) => setState(() => _emailError = null),
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'E-mail (optionnel)',
                                prefixIcon: const Icon(Icons.mail_outline),
                                errorText: _emailError,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Votre numéro (${Api.currentUser?['phone'] ?? ''}) '
                              'est déjà vérifié.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: !_valid || _saving ? null : _save,
                              child: Text(_saving ? 'Un instant…' : 'Continuer'),
                            ),
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
      ),
    );
  }
}

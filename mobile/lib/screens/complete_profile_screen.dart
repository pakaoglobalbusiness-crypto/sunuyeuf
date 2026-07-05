import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'home_screen.dart';
import 'terms_screen.dart';

/// Complétion obligatoire du profil juste après l'OTP :
/// prénom + nom requis, e-mail optionnel. Le téléphone vient de l'OTP.
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
      // Puis conditions d'utilisation si pas encore acceptées
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
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Votre profil'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Faisons connaissance 👋',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Ces informations rassurent les autres utilisateurs et sont '
              'nécessaires pour réserver ou publier.',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 8),
            Text(
              'Votre numéro de téléphone (${Api.currentUser?['phone'] ?? ''}) '
              'est déjà vérifié.',
              style: TextStyle(
                  fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: !_valid || _saving ? null : _save,
              child: Text(_saving ? 'Un instant…' : 'Continuer'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';

/// Paiement in-app (F5) : Wave, Orange Money, Free Money, carte.
/// En dev, l'agrégateur est simulé et confirme automatiquement après ~2 s ;
/// l'écran interroge le statut jusqu'à confirmation (comme un vrai webhook).
class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const PaymentScreen({super.key, required this.booking});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'wave';
  String _state = 'idle'; // idle | paying | done | error
  String? _error;
  Timer? _pollTimer;

  static const methods = [
    ('wave', 'Wave', '🌊'),
    ('orange_money', 'Orange Money', '🟠'),
    ('free_money', 'Free Money', '🔴'),
    ('carte', 'Carte bancaire', '💳'),
  ];

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => (_state = 'paying', _error = null));
    try {
      final res = await Api.post('/payments/initiate', body: {
        'bookingId': widget.booking['id'],
        'method': _method,
      });
      final paymentId = res['paymentId'];
      _pollTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        try {
          final s = await Api.get('/payments/$paymentId/status');
          if (s['status'] == 'confirmed') {
            t.cancel();
            if (mounted) setState(() => _state = 'done');
          } else if (s['status'] == 'failed') {
            t.cancel();
            if (mounted) {
              setState(() => (_state = 'error', _error = 'Paiement refusé'));
            }
          }
        } catch (_) {}
      });
    } on ApiException catch (e) {
      setState(() => (_state = 'error', _error = e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final total = b['totalPriceFcfa'] as num;

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _state == 'done'
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: senegalGreen, size: 90),
                    const SizedBox(height: 16),
                    const Text(
                      'Paiement confirmé !',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Votre réservation est confirmée. L’adresse exacte et la '
                      'messagerie avec le propriétaire sont maintenant débloquées.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      child: const Text('Voir mes réservations'),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total à payer',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            fcfa(total),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: senegalGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fonds sécurisés par Sunuyeuf, versés au propriétaire '
                            'après le début de la location.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Moyen de paiement',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  for (final (value, label, emoji) in methods)
                    RadioListTile<String>(
                      value: value,
                      groupValue: _method,
                      onChanged: _state == 'paying'
                          ? null
                          : (v) => setState(() => _method = v!),
                      title: Text('$emoji  $label'),
                      activeColor: senegalGreen,
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _state == 'paying' ? null : _pay,
                    child: Text(
                      _state == 'paying'
                          ? 'Validation en cours sur votre téléphone…'
                          : 'Payer ${fcfa(total)}',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

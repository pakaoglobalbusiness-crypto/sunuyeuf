import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';

/// Mes revenus (propriétaire) : total encaissé en FCFA + détail des versements.
class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  List<dynamic> _payouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.get('/payments/payouts/mine');
      if (mounted) setState(() => _payouts = res);
    } on ApiException {
      // pull-to-refresh disponible
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Total versé (déjà envoyé) et total à venir (programmé)
    final sent = _payouts
        .where((p) => p['status'] == 'sent')
        .fold<num>(0, (s, p) => s + (p['amountFcfa'] as num));
    final scheduled = _payouts
        .where((p) => p['status'] == 'scheduled')
        .fold<num>(0, (s, p) => s + (p['amountFcfa'] as num));
    final total = sent + scheduled;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes revenus')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Carte total (somme actuelle en FCFA)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [gologuiTeal, Color(0xFF0A6E5E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total de vos revenus',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          fcfa(total),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: 'Déjà versé',
                                value: fcfa(sent),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 34,
                              color: Colors.white24,
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: 'À venir',
                                value: fcfa(scheduled),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Détail des versements',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (_payouts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'Aucun revenu pour le moment.\n'
                          'Vos gains apparaîtront ici après vos premières locations.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  for (final p in _payouts)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: gologuiTeal.withValues(alpha: 0.12),
                          child: const Icon(Icons.payments_outlined,
                              color: gologuiTeal),
                        ),
                        title: Text(
                          fcfa(p['amountFcfa']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          p['booking']?['listing']?['title'] ?? 'Location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _StatusChip(status: p['status']),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Les gains sont versés sur votre compte Wave / Orange Money '
                    'à J+1 après le début de chaque location (commission Gologui : 10 %).',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'sent' => ('Versé', const Color(0xFFD9F0E3), gologuiTeal),
      'scheduled' => ('Programmé', const Color(0xFFFFF4CE), const Color(0xFF8A6D00)),
      _ => ('Échoué', const Color(0xFFFBDCDD), const Color(0xFFE31B23)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

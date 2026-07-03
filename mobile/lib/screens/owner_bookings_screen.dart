import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';

/// Côté propriétaire : accepter / refuser les demandes (F12),
/// suivre les locations et l'état des lieux voiture (F17).
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.get('/bookings/owner');
      setState(() => _bookings = res);
    } on ApiException {
      // pull-to-refresh disponible
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(String id, String action) async {
    try {
      await Api.post('/bookings/$id/respond', body: {'action': action});
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _checkin(String id, String type) async {
    try {
      await Api.post('/bookings/$id/car-checkin', body: {
        'type': type,
        'photos': ['https://demo.sunuyeuf.sn/checkin/$type.jpg'],
        'km': 45000,
        'fuelLevel': 'plein',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          type == 'remise'
              ? 'État des lieux de remise enregistré — location démarrée.'
              : 'Retour enregistré — location terminée, caution en cours de remboursement.',
        ),
      ));
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes et locations')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(child: Text('Aucune demande pour le moment'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bookings.length,
                    itemBuilder: (_, i) {
                      final b = _bookings[i];
                      final status = b['status'] as String;
                      final isCar = b['listing']['type'] == 'voiture';
                      final net =
                          (b['totalPriceFcfa'] as num) - (b['commissionFcfa'] as num);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b['listing']['title'],
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Locataire : ${b['renter']['name'] ?? b['renter']['phone']}',
                              ),
                              Text(
                                '${dateFr(b['startDate'])} → ${dateFr(b['endDate'])}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              Text(
                                'Vous recevrez ${fcfa(net)} '
                                '(total ${fcfa(b['totalPriceFcfa'])} − 10 %)',
                                style: const TextStyle(
                                  color: senegalGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bookingStatusLabels[status] ?? status,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (status == 'requested') ...[
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                            minimumSize: const Size(0, 42)),
                                        onPressed: () => _respond(b['id'], 'accept'),
                                        child: const Text('Accepter'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          minimumSize: const Size(0, 42),
                                        ),
                                        onPressed: () => _respond(b['id'], 'reject'),
                                        child: const Text('Refuser'),
                                      ),
                                    ),
                                  ],
                                  if (isCar && status == 'paid')
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                            minimumSize: const Size(0, 42)),
                                        onPressed: () => _checkin(b['id'], 'remise'),
                                        child: const Text('📸 État des lieux — remise'),
                                      ),
                                    ),
                                  if (isCar && status == 'ongoing')
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                            minimumSize: const Size(0, 42)),
                                        onPressed: () => _checkin(b['id'], 'retour'),
                                        child: const Text('📸 État des lieux — retour'),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

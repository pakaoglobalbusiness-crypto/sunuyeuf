import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'payment_screen.dart';

/// Mes réservations (locataire) : suivi, paiement, annulation, avis (F7–F9).
class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
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
      final res = await Api.get('/bookings/mine');
      setState(() => _bookings = res);
    } on ApiException {
      // silencieux : pull-to-refresh permet de réessayer
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: const Text(
          'Le remboursement dépend de la politique d’annulation de l’annonce.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await Api.post('/bookings/${b['id']}/cancel');
      if (!mounted) return;
      final refund = res['refundFcfa'] as num? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          refund > 0
              ? 'Réservation annulée. Remboursement : ${fcfa(refund)}'
              : 'Réservation annulée.',
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

  Future<void> _review(Map<String, dynamic> b) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Votre avis'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setDialogState(() => rating = i),
                      icon: Icon(
                        i <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 30,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(hintText: 'Commentaire (optionnel)'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Plus tard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publier'),
            ),
          ],
        ),
      ),
    );
    if (sent != true) return;
    try {
      await Api.post('/reviews', body: {
        'bookingId': b['id'],
        'rating': rating,
        if (commentCtrl.text.isNotEmpty) 'comment': commentCtrl.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Merci pour votre avis !')));
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
      appBar: AppBar(title: const Text('Mes réservations')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(
                  child: Text('Aucune réservation.\nExplorez les annonces !',
                      textAlign: TextAlign.center),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bookings.length,
                    itemBuilder: (_, i) {
                      final b = _bookings[i];
                      final l = b['listing'];
                      final status = b['status'] as String;
                      final hasReview = (b['payments'] as List?) != null &&
                          status == 'completed';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l['title'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  _StatusBadge(status: status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${dateFr(b['startDate'])} → ${dateFr(b['endDate'])}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              Text(
                                fcfa(b['totalPriceFcfa']),
                                style: const TextStyle(
                                  color: senegalGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (status == 'accepted')
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                      ),
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                PaymentScreen(booking: b),
                                          ),
                                        );
                                        _load();
                                      },
                                      child: const Text('Payer maintenant'),
                                    ),
                                  if (status == 'completed' && hasReview)
                                    OutlinedButton(
                                      onPressed: () => _review(b),
                                      child: const Text('Laisser un avis'),
                                    ),
                                  const Spacer(),
                                  if (['requested', 'accepted', 'paid']
                                      .contains(status))
                                    TextButton(
                                      onPressed: () => _cancel(b),
                                      child: const Text(
                                        'Annuler',
                                        style: TextStyle(color: Colors.red),
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'paid' || 'ongoing' || 'completed' => (const Color(0xFFD9F0E3), senegalGreen),
      'cancelled' || 'rejected' || 'disputed' => (
          const Color(0xFFFBDCDD),
          const Color(0xFFE31B23)
        ),
      _ => (const Color(0xFFFFF4CE), const Color(0xFF8A6D00)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        bookingStatusLabels[status] ?? status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

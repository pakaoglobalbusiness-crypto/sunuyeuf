import 'package:flutter/material.dart';

import '../api.dart';
import '../favorites.dart';
import '../main.dart';
import 'payment_screen.dart';

/// Fiche annonce (F3) + demande de réservation avec dates (F4).
class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Map<String, dynamic>? _listing;
  String? _error;
  DateTimeRange? _dates;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.get('/listings/${widget.listingId}');
      setState(() => _listing = res);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr'),
      helpText: 'Dates de la location',
    );
    if (range != null) setState(() => _dates = range);
  }

  int get _days => _dates == null ? 0 : _dates!.duration.inDays;

  Future<void> _book() async {
    if (_dates == null) {
      await _pickDates();
      if (_dates == null) return;
    }
    setState(() => _booking = true);
    try {
      final res = await Api.post('/bookings', body: {
        'listingId': widget.listingId,
        'startDate': _dates!.start.toIso8601String().substring(0, 10),
        'endDate': _dates!.end.toIso8601String().substring(0, 10),
      });
      if (!mounted) return;
      if (res['status'] == 'accepted') {
        // Réservation instantanée : on passe directement au paiement
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PaymentScreen(booking: res)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Demande envoyée ! Le propriétaire a 24 h pour répondre. '
            'Suivez-la dans l’onglet Réservations.',
          ),
        ));
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    }
    final l = _listing;
    if (l == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final photos = l['photos'] as List;
    final isVilla = l['type'] == 'villa';
    final villa = l['villaDetails'];
    final car = l['carDetails'];
    final owner = l['owner'];

    return Scaffold(
      appBar: AppBar(
        title: Text(isVilla ? 'Logement' : 'Voiture'),
        actions: [
          IconButton(
            onPressed: () async {
              await Favorites.toggle(widget.listingId);
              if (mounted) setState(() {});
            },
            icon: Icon(
              Favorites.contains(widget.listingId)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: Favorites.contains(widget.listingId)
                  ? const Color(0xFFFF5A5F)
                  : null,
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (photos.isNotEmpty)
            SizedBox(
              height: 230,
              child: PageView(
                children: [
                  for (final p in photos)
                    Image.network(
                      p['url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey.shade300),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l['title'],
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: gologuiTeal),
                    Text(
                      ' ${l['city']}${l['district'] != null ? ' · ${l['district']}' : ''}',
                    ),
                    const Spacer(),
                    if ((l['avgRating'] as num) > 0) ...[
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(' ${l['avgRating']} (${l['ratingCount']} avis)'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Adresse exacte communiquée après paiement',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const Divider(height: 28),
                // Équipements / caractéristiques
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (villa != null) ...[
                      _Chip('🛏 ${villa['bedrooms']} chambres'),
                      _Chip('🚿 ${villa['bathrooms']} SDB'),
                      _Chip('👥 ${villa['capacity']} pers.'),
                      if (villa['pool'] == true) const _Chip('🏊 Piscine'),
                      if (villa['wifi'] == true) const _Chip('📶 Wifi'),
                      if (villa['ac'] == true) const _Chip('❄️ Clim'),
                      if (villa['guard'] == true) const _Chip('💂 Gardien'),
                    ],
                    if (car != null) ...[
                      _Chip([
                        car['brand'],
                        car['model'],
                        car['year'],
                      ].where((e) => e != null && '$e'.isNotEmpty).join(' ')),
                      _Chip('⚙️ ${car['gearbox']}'),
                      _Chip('⛽ ${car['fuel']}'),
                      if (car['withDriver'] == true) const _Chip('🧑‍✈️ Chauffeur possible'),
                      _Chip(
                        car['kmIncludedDay'] == 0
                            ? '∞ km illimité'
                            : '${car['kmIncludedDay']} km/jour inclus',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(l['description'], style: const TextStyle(height: 1.5)),
                if ((l['depositFcfa'] as num) > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9D6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Caution : ${fcfa(l['depositFcfa'])} '
                      '(remboursée sous 48 h après le retour sans litige)',
                      style: const TextStyle(color: Color(0xFF5C4B00)),
                    ),
                  ),
                ],
                const Divider(height: 28),
                // Propriétaire
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: gologuiTeal,
                      child: Text(
                        (owner['name'] ?? '?')[0],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          owner['name'] ?? 'Propriétaire',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (owner['kycStatus'] == 'verified')
                          const Text(
                            '✓ Identité vérifiée',
                            style: TextStyle(color: gologuiTeal, fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDates,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${fcfa(l['pricePerDayFcfa'])} / jour',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        _dates == null
                            ? 'Choisir les dates'
                            : '$_days jour${_days > 1 ? 's' : ''} · ${fcfa(_days * (l['pricePerDayFcfa'] as num))}',
                        style: const TextStyle(
                          color: gologuiTeal,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: FilledButton(
                  onPressed: _booking ? null : _book,
                  child: Text(
                    _booking
                        ? '…'
                        : l['instantBooking'] == true
                            ? 'Réserver'
                            : 'Demander',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: scheme.onSurface),
      ),
    );
  }
}

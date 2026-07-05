import 'package:flutter/material.dart';

import '../api.dart';
import '../favorites.dart';
import '../main.dart';
import '../widgets/verified_badge.dart';
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
  List<dynamic> _reviews = [];
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
      final reviews = await Api.get('/reviews/listing/${widget.listingId}');
      if (mounted) setState(() => _reviews = reviews);
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
            _PhotoCarousel(
              urls: [for (final p in photos) p['url'] as String],
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
                    Expanded(
                      child: Text(
                        ' ${[
                          l['commune'],
                          l['department'],
                          l['city'],
                        ].where((e) => e != null && '$e'.isNotEmpty).join(', ')}',
                      ),
                    ),
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
                        Row(
                          children: [
                            Text(
                              owner['name'] ?? 'Propriétaire',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            VerifiedBadge(kycStatus: owner['kycStatus']),
                          ],
                        ),
                        if (owner['kycStatus'] == 'verified')
                          const Text(
                            'Identité vérifiée',
                            style: TextStyle(color: gologuiTeal, fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                ),
                // Avis des locataires (pour conseiller ou éviter)
                const Divider(height: 28),
                Row(
                  children: [
                    const Text('Avis des locataires',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if ((l['avgRating'] as num) > 0)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 18, color: gologuiOrange),
                          Text(' ${l['avgRating']} · ${l['ratingCount']} avis',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_reviews.isEmpty)
                  Text(
                    'Aucun avis pour le moment. Soyez le premier à donner votre '
                    'avis après votre location.',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55)),
                  )
                else
                  for (final r in _reviews) _ReviewTile(review: r),
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

/// Carrousel de photos avec indicateurs : compteur (1/4), points en bas,
/// et flèches gauche/droite pour signaler qu'on peut changer d'image.
class _PhotoCarousel extends StatefulWidget {
  final List<String> urls;
  const _PhotoCarousel({required this.urls});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i < 0 || i >= widget.urls.length) return;
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.urls.length;
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: n,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Image.network(
              widget.urls[i],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
            ),
          ),
          if (n > 1) ...[
            // Compteur en haut à droite (ex. « 2/5 »)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      '${_index + 1}/$n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Flèche gauche (masquée sur la première image)
            if (_index > 0)
              Positioned(
                left: 8,
                child: _NavArrow(
                  icon: Icons.chevron_left,
                  onTap: () => _go(_index - 1),
                ),
              ),
            // Flèche droite (masquée sur la dernière image)
            if (_index < n - 1)
              Positioned(
                right: 8,
                child: _NavArrow(
                  icon: Icons.chevron_right,
                  onTap: () => _go(_index + 1),
                ),
              ),
            // Points indicateurs en bas
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < n; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

/// Un avis (note + commentaire + auteur).
class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] ?? 0) as int;
    final author = review['author'] ?? {};
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: gologuiTeal,
                backgroundImage: author['photoUrl'] != null
                    ? NetworkImage(author['photoUrl'])
                    : null,
                child: author['photoUrl'] == null
                    ? Text((author['name'] ?? '?')[0],
                        style: const TextStyle(color: Colors.white, fontSize: 13))
                    : null,
              ),
              const SizedBox(width: 8),
              Text(author['name'] ?? 'Locataire',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 16, color: gologuiOrange),
                ],
              ),
            ],
          ),
          if ((review['comment'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 40),
              child: Text(review['comment'], style: const TextStyle(height: 1.4)),
            ),
        ],
      ),
    );
  }
}

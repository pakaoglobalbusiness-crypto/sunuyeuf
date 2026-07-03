import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'listing_detail_screen.dart';

/// Recherche par type, ville et budget (F2) — 3 clics max jusqu'à la demande
/// de réservation : 1) choisir l'annonce 2) dates 3) réserver.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  String _type = 'villa';
  String? _city;
  int? _maxPrice;
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  static const cities = ['Dakar', 'Saly', 'Mbour', 'Saint-Louis', 'Touba', 'Ziguinchor'];

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => (_loading = true, _error = null));
    try {
      final res = await Api.get('/listings', query: {
        'type': _type,
        if (_city != null) 'city': _city!,
        if (_maxPrice != null) 'maxPrice': '$_maxPrice',
      });
      setState(() => _items = res['items']);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gologui'),
        actions: [
          IconButton(onPressed: _search, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: gologuiTeal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.white,
                    selectedBackgroundColor: gologuiOrange,
                  ),
                  segments: const [
                    ButtonSegment(value: 'villa', label: Text('🏠 Villas')),
                    ButtonSegment(value: 'voiture', label: Text('🚗 Voitures')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) {
                    _type = s.first;
                    _search();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _city,
                        decoration: const InputDecoration(
                          labelText: 'Ville',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Toutes')),
                          ...cities.map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                        ],
                        onChanged: (v) {
                          _city = v;
                          _search();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _maxPrice,
                        decoration: const InputDecoration(
                          labelText: 'Budget max/jour',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Illimité')),
                          DropdownMenuItem(value: 25000, child: Text('25 000 F')),
                          DropdownMenuItem(value: 50000, child: Text('50 000 F')),
                          DropdownMenuItem(value: 100000, child: Text('100 000 F')),
                        ],
                        onChanged: (v) {
                          _maxPrice = v;
                          _search();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? const Center(child: Text('Aucune annonce trouvée'))
                        : RefreshIndicator(
                            onRefresh: _search,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _items.length,
                              itemBuilder: (_, i) => _ListingCard(
                                listing: _items[i],
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ListingDetailScreen(
                                      listingId: _items[i]['id'],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onTap;
  const _ListingCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final photos = listing['photos'] as List;
    final rating = (listing['avgRating'] as num).toDouble();
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty)
              Image.network(
                photos.first['url'],
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.photo, size: 48),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing['title'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing['city']}${listing['district'] != null ? ' · ${listing['district']}' : ''}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${fcfa(listing['pricePerDayFcfa'])} / jour',
                        style: const TextStyle(
                          color: gologuiTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      if (rating > 0) ...[
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        Text(' $rating (${listing['ratingCount']})'),
                      ] else
                        Text('Nouveau', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

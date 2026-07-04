import 'package:flutter/material.dart';

import '../api.dart';
import '../favorites.dart';
import '../widgets/listing_card.dart';
import 'filter_sheet.dart';
import 'listing_detail_screen.dart';

/// Accueil / Explorer — type, filtres avancés, cartes immersives (F2).
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  String _type = 'villa';
  Filters _filters = Filters();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Favorites.load().then((_) => mounted ? setState(() {}) : null);
    _search();
  }

  Future<void> _search() async {
    setState(() => (_loading = true, _error = null));
    try {
      final res = await Api.get('/listings', query: _filters.toQuery(_type));
      setState(() => _items = res['items']);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<Filters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FilterSheet(filters: _filters, type: _type),
    );
    if (result != null) {
      _filters = result;
      _search();
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    final name = (Api.currentUser?['name'] as String?)?.split(' ').first;
    final salut = h < 18 ? 'Bonjour' : 'Bonsoir';
    return name == null ? '$salut 👋' : '$salut, $name 👋';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _search,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: scheme.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Où allez-vous ?',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset('assets/icon/icon.png', height: 42),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Bascule logement / voiture
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            for (final (value, label) in [
                              ('villa', '🏠  Logements'),
                              ('voiture', '🚗  Voitures'),
                            ])
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (_type != value) {
                                      _type = value;
                                      _search();
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    decoration: BoxDecoration(
                                      color: _type == value ? scheme.surface : Colors.transparent,
                                      borderRadius: BorderRadius.circular(13),
                                      boxShadow: _type == value
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight:
                                            _type == value ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Bouton Filtres (avec compteur) + résumé
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openFilters,
                              icon: const Icon(Icons.tune, size: 20),
                              label: Text(
                                _filters.count(_type) == 0
                                    ? 'Filtres'
                                    : 'Filtres (${_filters.count(_type)})',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: _filters.count(_type) > 0
                                    ? scheme.primary
                                    : scheme.onSurface,
                                side: BorderSide(
                                  color: _filters.count(_type) > 0
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  width: _filters.count(_type) > 0 ? 1.5 : 1,
                                ),
                              ),
                            ),
                          ),
                          if (_filters.count(_type) > 0) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Effacer les filtres',
                              onPressed: () {
                                setState(() => _filters = Filters());
                                _search();
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(child: Center(child: Text(_error!)))
              else if (_items.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('Aucune annonce trouvée')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => ListingCard(
                      listing: _items[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ListingDetailScreen(listingId: _items[i]['id']),
                        ),
                      ),
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


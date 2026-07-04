import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'create_listing_screen.dart';

/// Mes annonces (propriétaire) : liste avec modification et suppression.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  List<dynamic> _listings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.get('/listings/mine');
      if (mounted) setState(() => _listings = res);
    } on ApiException {
      // pull-to-refresh disponible
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> listing) async {
    Map<String, dynamic> full = listing;
    try {
      full = await Api.get('/listings/${listing['id']}');
    } on ApiException {
      // à défaut, on édite avec les données de la liste
    }
    if (!mounted) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateListingScreen(existing: full)),
    );
    if (updated == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: Text(
          '« ${listing['title']} » sera retirée de Gologui. '
          'Si elle a déjà des réservations, elle sera archivée '
          '(l’historique est conservé).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE31B23)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.delete('/listings/${listing['id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Annonce supprimée')));
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
      appBar: AppBar(
        title: const Text('Mes annonces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Publier',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(
                  builder: (_) => const CreateListingScreen(),
                ))
                .then((_) => _load()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _listings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.home_work_outlined, size: 56),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucune annonce publiée',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Appuyez sur + pour publier votre première annonce.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _listings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final l = _listings[i];
                      final photos = (l['photos'] as List?) ?? [];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (photos.isNotEmpty)
                              Image.network(
                                photos.first['url'],
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 150,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(Icons.photo_outlined),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(l['type'] == 'villa' ? '🏠 ' : '🚗 '),
                                      Expanded(
                                        child: Text(
                                          l['title'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${fcfa(l['pricePerDayFcfa'])}/jour · ${switch (l['status']) {
                                      'published' => 'En ligne ✓',
                                      'in_moderation' => 'En modération…',
                                      'suspended' => 'Suspendue',
                                      _ => 'Brouillon',
                                    }}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _edit(l),
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        label: const Text('Modifier'),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 40),
                                          foregroundColor: gologuiTeal,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () => _delete(l),
                                        icon: const Icon(Icons.delete_outline,
                                            color: Color(0xFFE31B23)),
                                        tooltip: 'Supprimer',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

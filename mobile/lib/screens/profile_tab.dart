import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../favorites.dart';
import '../main.dart';
import 'create_listing_screen.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import 'owner_bookings_screen.dart';

/// Profil + bascule de rôle propriétaire (tout dans la même app, spec §2.3) :
/// KYC (F15), mes annonces (F10-F11), demandes reçues (F12), revenus (F13-F14).
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _me;
  List<dynamic> _myListings = [];
  List<dynamic> _payouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.get('/users/me');
      final listings = await Api.get('/listings/mine');
      final payouts = await Api.get('/payments/payouts/mine');
      if (mounted) {
        setState(() {
          _me = me;
          _myListings = listings;
          _payouts = payouts;
        });
      }
    } on ApiException {
      // pull-to-refresh disponible
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _me?['name'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Votre nom'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await Api.patch('/users/me', body: {'name': ctrl.text.trim()});
      _load();
    }
  }

  Future<String?> _pickAndUpload(String prompt) async {
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(prompt)));
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, // caméra sur téléphone, galerie en dev web
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return Api.uploadBytes(await picked.readAsBytes(), picked.name);
  }

  // Photo de profil : galerie/caméra → upload → PATCH /users/me
  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    try {
      final url = await Api.uploadBytes(await picked.readAsBytes(), picked.name);
      await Api.patch('/users/me', body: {'photoUrl': url});
      // Met à jour la session locale pour l'avatar ailleurs dans l'app
      final me = await Api.get('/users/me');
      Api.currentUser = me;
      if (mounted) {
        setState(() => _me = me);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour ✓')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  // Vérification d'identité : recto + verso de la CNI ou du permis de conduire
  Future<void> _submitKyc() async {
    final docType = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quel document utilisez-vous ?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Carte nationale d’identité'),
              onTap: () => Navigator.pop(ctx, 'cni'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('Permis de conduire'),
              onTap: () => Navigator.pop(ctx, 'permis'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (docType == null) return;
    final label = docType == 'cni' ? 'votre carte d’identité' : 'votre permis de conduire';
    try {
      final rectoUrl = await _pickAndUpload('Photo du RECTO de $label');
      if (rectoUrl == null) return;
      final versoUrl = await _pickAndUpload('Maintenant, photo du VERSO de $label');
      if (versoUrl == null) return;
      final selfieUrl = await _pickAndUpload('Pour finir, un selfie bien éclairé 🤳');
      if (selfieUrl == null) return;
      await Api.post('/users/me/kyc', body: {
        'documents': [
          {'type': '${docType}_recto', 'fileUrl': rectoUrl},
          {'type': '${docType}_verso', 'fileUrl': versoUrl},
          {'type': 'selfie', 'fileUrl': selfieUrl},
        ],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Documents envoyés ! Vérification sous 24 h.'),
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
    final me = _me;
    final totalEarned = _payouts
        .where((p) => p['status'] != 'failed')
        .fold<num>(0, (s, p) => s + (p['amountFcfa'] as num));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: me == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Identité + photo de profil
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: gologuiTeal,
                            backgroundImage: me['photoUrl'] != null
                                ? NetworkImage(me['photoUrl'])
                                : null,
                            child: me['photoUrl'] == null
                                ? Text(
                                    (me['name'] ?? '?')[0],
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 26),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: gologuiOrange,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _changePhoto,
                                child: const Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Icon(Icons.photo_camera,
                                      size: 15, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              me['name'] ?? 'Compléter mon profil',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            Text(me['phone'],
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: _editName, icon: const Icon(Icons.edit)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Favoris
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.favorite, color: Color(0xFFFF5A5F)),
                      title: const Text('Mes favoris'),
                      subtitle: Text(
                        Favorites.ids.isEmpty
                            ? 'Les annonces que vous aimez'
                            : '${Favorites.ids.length} annonce(s) enregistrée(s)',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (_) => const FavoritesScreen(),
                          ))
                          .then((_) => setState(() {})),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // KYC
                  Card(
                    child: ListTile(
                      leading: Icon(
                        me['kycStatus'] == 'verified'
                            ? Icons.verified
                            : Icons.badge_outlined,
                        color: me['kycStatus'] == 'verified'
                            ? gologuiTeal
                            : Colors.orange,
                      ),
                      title: Text(switch (me['kycStatus']) {
                        'verified' => 'Identité vérifiée',
                        'pending' => 'Vérification en cours…',
                        'rejected' => 'Vérification refusée',
                        _ => 'Vérifier mon identité',
                      }),
                      subtitle: me['kycStatus'] == 'none'
                          ? const Text('Obligatoire pour publier une annonce')
                          : null,
                      trailing: ['none', 'rejected'].contains(me['kycStatus'])
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40)),
                              onPressed: _submitKyc,
                              child: const Text('Envoyer'),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Espace propriétaire
                  const Text(
                    'Espace propriétaire',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add_home_work, color: gologuiTeal),
                          title: const Text('Publier une annonce'),
                          subtitle: const Text('Villa ou voiture, en 5 étapes'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                builder: (_) => const CreateListingScreen(),
                              ))
                              .then((_) => _load()),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.inbox, color: gologuiTeal),
                          title: const Text('Demandes et locations reçues'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OwnerBookingsScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.account_balance_wallet,
                              color: gologuiTeal),
                          title: const Text('Mes revenus'),
                          subtitle: Text(
                            _payouts.isEmpty
                                ? 'Aucun versement pour le moment'
                                : 'Total : ${fcfa(totalEarned)} · versés sur Wave',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_myListings.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Mes annonces',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    for (final l in _myListings)
                      Card(
                        child: ListTile(
                          leading: Text(
                            l['type'] == 'villa' ? '🏠' : '🚗',
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(l['title'], maxLines: 1),
                          subtitle: Text(
                            '${fcfa(l['pricePerDayFcfa'])}/jour · ${switch (l['status']) {
                              'published' => 'En ligne ✓',
                              'in_moderation' => 'En modération…',
                              'suspended' => 'Suspendue',
                              _ => 'Brouillon',
                            }}',
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Api.logout();
                      Favorites.reset();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Déconnexion'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

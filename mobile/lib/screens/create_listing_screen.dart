import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../main.dart';

/// Création d'annonce guidée en 5 étapes max (F10) :
/// type → photos → description → prix → publication.
class CreateListingScreen extends StatefulWidget {
  // Si existing != null → mode modification (formulaire pré-rempli, PATCH)
  final Map<String, dynamic>? existing;
  const CreateListingScreen({super.key, this.existing});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  int _step = 0;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  // Étape 1 : type
  String _type = 'villa';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) return;
    // Pré-remplissage en mode modification
    _type = e['type'];
    _titleCtrl.text = e['title'] ?? '';
    _descCtrl.text = e['description'] ?? '';
    _city = e['city'] ?? 'Dakar';
    _districtCtrl.text = e['district'] ?? '';
    _priceCtrl.text = '${e['pricePerDayFcfa'] ?? ''}';
    _depositCtrl.text = '${e['depositFcfa'] ?? 0}';
    _policy = e['cancellationPolicy'] ?? 'moderate';
    _instant = e['instantBooking'] ?? false;
    _photos.addAll(
      ((e['photos'] as List?) ?? []).map((p) => p['url'] as String),
    );
    final v = e['villaDetails'];
    if (v != null) {
      _bedrooms = v['bedrooms'] ?? 2;
      _bathrooms = v['bathrooms'] ?? 1;
      _capacity = v['capacity'] ?? 4;
      _pool = v['pool'] ?? false;
      _wifi = v['wifi'] ?? true;
      _ac = v['ac'] ?? true;
      _guard = v['guard'] ?? false;
    }
    final c = e['carDetails'];
    if (c != null) {
      _brandCtrl.text = c['brand'] ?? '';
      _yearCtrl.text = '${c['year'] ?? 2022}';
      _gearbox = c['gearbox'] ?? 'manuelle';
      _fuel = c['fuel'] ?? 'essence';
      _delivery = c['deliveryPlace'] ?? 'domicile';
      _withDriver = c['withDriver'] ?? false;
    }
    // On saute l'étape « type » (non modifiable)
    _step = 1;
  }

  // Étape 2 : photos — galerie/appareil photo, uploadées vers l'API.
  // Minimum 5 (logement) ou 3 (voiture), maximum 7.
  final List<String> _photos = [];
  bool _uploading = false;

  int get _minPhotos => _type == 'villa' ? 5 : 3;

  // Photo unique (appareil photo)
  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 82, // compression (connexions 3G, spec §3)
    );
    if (picked == null) return;
    await _uploadAll([picked]);
  }

  // Sélection MULTIPLE depuis la galerie (sans ressortir à chaque photo)
  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked.isEmpty) return;
    final remaining = 7 - _photos.length;
    if (picked.length > remaining) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Vous pouvez ajouter $remaining photo(s) de plus (7 max). '
            'Les premières sont conservées.',
          ),
        ));
      }
    }
    await _uploadAll(picked.take(remaining).toList());
  }

  Future<void> _uploadAll(List<XFile> files) async {
    setState(() => _uploading = true);
    try {
      for (final f in files) {
        final url = await Api.uploadBytes(await f.readAsBytes(), f.name);
        if (mounted) setState(() => _photos.add(url));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Étape 3 : description
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _city = 'Dakar';
  final _districtCtrl = TextEditingController();
  // Villa
  int _bedrooms = 2, _bathrooms = 1, _capacity = 4;
  bool _pool = false, _wifi = true, _ac = true, _guard = false;
  // Voiture
  final _brandCtrl = TextEditingController();
  final _yearCtrl = TextEditingController(text: '2022');
  String _gearbox = 'manuelle', _fuel = 'essence', _delivery = 'domicile';
  bool _withDriver = false;

  // Étape 4 : prix
  final _priceCtrl = TextEditingController();
  final _depositCtrl = TextEditingController(text: '0');
  String _policy = 'moderate';
  bool _instant = false;

  static const cities = ['Dakar', 'Saly', 'Mbour', 'Saint-Louis', 'Touba', 'Ziguinchor'];

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final body = {
      if (!_isEditing) 'type': _type,
      'title': _titleCtrl.text,
      'description': _descCtrl.text,
      if (!_isEditing) 'city': _city,
      if (_districtCtrl.text.isNotEmpty) 'district': _districtCtrl.text,
      'pricePerDayFcfa': int.tryParse(_priceCtrl.text) ?? 0,
      'depositFcfa': int.tryParse(_depositCtrl.text) ?? 0,
      'cancellationPolicy': _policy,
      'instantBooking': _instant,
      'photoUrls': _photos,
      if (_type == 'villa')
        'villaDetails': {
          'bedrooms': _bedrooms,
          'bathrooms': _bathrooms,
          'capacity': _capacity,
          'pool': _pool,
          'wifi': _wifi,
          'ac': _ac,
          'guard': _guard,
        },
      if (_type == 'voiture')
        'carDetails': {
          'brand': _brandCtrl.text,
          'year': int.tryParse(_yearCtrl.text) ?? 2020,
          'gearbox': _gearbox,
          'fuel': _fuel,
          'withDriver': _withDriver,
          'kmIncludedDay': 200,
          'deliveryPlace': _delivery,
        },
    };
    try {
      if (_isEditing) {
        await Api.patch('/listings/${widget.existing!['id']}', body: body);
      } else {
        await Api.post('/listings', body: body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _isEditing
              ? 'Annonce mise à jour ✓'
              : 'Annonce envoyée en modération ! Elle sera en ligne après '
                  'validation par notre équipe.',
        ),
      ));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _counter(String label, int value, void Function(int) onChanged, {int min = 1}) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > min ? () => setState(() => onChanged(value - 1)) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: () => setState(() => onChanged(value + 1)),
          icon: const Icon(Icons.add_circle_outline, color: gologuiTeal),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      // 1. Type de bien
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Que proposez-vous à la location ?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          for (final (value, emoji, label, sub) in [
            ('villa', '🏠', 'Un logement', 'Villa, maison ou appartement'),
            ('voiture', '🚗', 'Une voiture', 'Avec ou sans chauffeur'),
          ])
            Card(
              color: _type == value
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: _type == value
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: _type == value ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: Text(emoji, style: const TextStyle(fontSize: 30)),
                title: Text(label),
                subtitle: Text(sub),
                onTap: () => setState(() => _type = value),
              ),
            ),
        ],
      ),
      // 2. Photos
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ajoutez des photos réelles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Minimum ${_type == 'villa' ? 5 : 3} photos, maximum 7. '
            'Des photos authentiques inspirent confiance et accélèrent '
            'la validation de votre annonce.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
          ),
          const SizedBox(height: 12),
          // Compteur de progression
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _photos.length >= _minPhotos
                  ? const Color(0xFFEDF5EF)
                  : const Color(0xFFFFF9D6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _photos.length >= _minPhotos
                      ? Icons.check_circle
                      : Icons.info_outline,
                  size: 18,
                  color: _photos.length >= _minPhotos
                      ? gologuiTeal
                      : const Color(0xFF8A6D00),
                ),
                const SizedBox(width: 8),
                Text(
                  _photos.length >= _minPhotos
                      ? '${_photos.length}/7 photos — c’est bon ✓'
                      : '${_photos.length}/$_minPhotos photos minimum',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _photos.length >= _minPhotos
                        ? const Color(0xFF0B4F47)
                        : const Color(0xFF5C4B00),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading || _photos.length >= 7
                      ? null
                      : _takePhoto,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Appareil photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading || _photos.length >= 7
                      ? null
                      : _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie (plusieurs)'),
                ),
              ),
            ],
          ),
          if (_photos.length >= 7)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Maximum de 7 photos atteint — supprimez-en une pour en changer.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12.5),
              ),
            ),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 12),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _photos[i],
                        width: 140,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        iconSize: 16,
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _photos.removeAt(i)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // 3. Description
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Décrivez votre bien',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Titre de l’annonce'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _city,
                  decoration: const InputDecoration(labelText: 'Ville'),
                  items: [
                    for (final c in cities)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _city = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _districtCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Quartier'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_type == 'villa') ...[
            _counter('Chambres', _bedrooms, (v) => _bedrooms = v),
            _counter('Salles de bain', _bathrooms, (v) => _bathrooms = v),
            _counter('Capacité (personnes)', _capacity, (v) => _capacity = v),
            SwitchListTile(
              value: _pool,
              onChanged: (v) => setState(() => _pool = v),
              title: const Text('Piscine'),
              activeThumbColor: gologuiTeal,
            ),
            SwitchListTile(
              value: _wifi,
              onChanged: (v) => setState(() => _wifi = v),
              title: const Text('Wifi'),
              activeThumbColor: gologuiTeal,
            ),
            SwitchListTile(
              value: _ac,
              onChanged: (v) => setState(() => _ac = v),
              title: const Text('Climatisation'),
              activeThumbColor: gologuiTeal,
            ),
            SwitchListTile(
              value: _guard,
              onChanged: (v) => setState(() => _guard = v),
              title: const Text('Gardien'),
              activeThumbColor: gologuiTeal,
            ),
          ] else ...[
            TextField(
              controller: _brandCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Marque'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _yearCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Année'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gearbox,
              decoration: const InputDecoration(labelText: 'Boîte de vitesses'),
              items: const [
                DropdownMenuItem(value: 'manuelle', child: Text('Manuelle')),
                DropdownMenuItem(value: 'automatique', child: Text('Automatique')),
              ],
              onChanged: (v) => setState(() => _gearbox = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fuel,
              decoration: const InputDecoration(labelText: 'Carburant'),
              items: const [
                DropdownMenuItem(value: 'essence', child: Text('Essence')),
                DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                DropdownMenuItem(value: 'hybride', child: Text('Hybride')),
                DropdownMenuItem(value: 'electrique', child: Text('Électrique')),
              ],
              onChanged: (v) => setState(() => _fuel = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _delivery,
              decoration: const InputDecoration(labelText: 'Lieu de remise'),
              items: const [
                DropdownMenuItem(value: 'domicile', child: Text('À domicile')),
                DropdownMenuItem(value: 'aeroport_aibd', child: Text('Aéroport AIBD')),
                DropdownMenuItem(value: 'agence', child: Text('En agence')),
              ],
              onChanged: (v) => setState(() => _delivery = v!),
            ),
            SwitchListTile(
              value: _withDriver,
              onChanged: (v) => setState(() => _withDriver = v),
              title: const Text('Chauffeur possible'),
              activeThumbColor: gologuiTeal,
            ),
          ],
        ],
      ),
      // 4. Prix
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Fixez votre prix',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Prix par jour (FCFA)',
              suffixText: 'FCFA',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (_type == 'voiture')
            TextField(
              controller: _depositCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Caution (FCFA)',
                suffixText: 'FCFA',
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _policy,
            decoration: const InputDecoration(labelText: 'Politique d’annulation'),
            items: const [
              DropdownMenuItem(
                value: 'flexible',
                child: Text('Flexible — 100 % remboursé jusqu’à la veille'),
              ),
              DropdownMenuItem(
                value: 'moderate',
                child: Text('Modérée — 100 % à J-5, 50 % à J-1'),
              ),
              DropdownMenuItem(
                value: 'strict',
                child: Text('Stricte — 100 % à J-14, 50 % à J-7'),
              ),
            ],
            onChanged: (v) => setState(() => _policy = v!),
          ),
          SwitchListTile(
            value: _instant,
            onChanged: (v) => setState(() => _instant = v),
            title: const Text('Réservation instantanée'),
            subtitle: const Text('Sans validation manuelle de votre part'),
            activeThumbColor: gologuiTeal,
          ),
          if (int.tryParse(_priceCtrl.text) != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF5EF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Vous recevrez ${fcfa((int.parse(_priceCtrl.text) * 0.9).round())} '
                'par jour loué (commission Gologui : 10 %).',
                style: const TextStyle(color: Color(0xFF0B4F47)),
              ),
            ),
          ],
        ],
      ),
      // 5. Récapitulatif
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Récapitulatif',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_type == 'villa' ? '🏠' : '🚗'} ${_titleCtrl.text}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text('$_city${_districtCtrl.text.isNotEmpty ? ' · ${_districtCtrl.text}' : ''}'),
                  Text('${_photos.length} photo(s)'),
                  Text(
                    '${fcfa(int.tryParse(_priceCtrl.text) ?? 0)} / jour',
                    style: const TextStyle(
                        color: gologuiTeal, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Votre annonce sera vérifiée par notre équipe avant publication '
            '(sous 24 h en général).',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    ];

    // Champs obligatoires par étape : le bouton reste bloqué tant qu'ils
    // ne sont pas remplis.
    final canNext = switch (_step) {
      1 => _photos.length >= _minPhotos && _photos.length <= 7,
      2 => _titleCtrl.text.trim().isNotEmpty &&
          _descCtrl.text.trim().isNotEmpty &&
          _districtCtrl.text.trim().isNotEmpty &&
          (_type == 'villa' ||
              (_brandCtrl.text.trim().isNotEmpty &&
                  (int.tryParse(_yearCtrl.text) ?? 0) >= 1990)),
      3 => (int.tryParse(_priceCtrl.text) ?? 0) >= 1000,
      _ => true,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Modifier l’annonce'
            : 'Nouvelle annonce — étape ${_step + 1}/5'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / 5,
            color: gologuiTeal,
            backgroundColor: Colors.grey.shade200,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: steps[_step],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // En modification, on ne redescend pas sous l'étape 1 (type figé)
                  if (_step > (_isEditing ? 1 : 0))
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Retour'),
                      ),
                    ),
                  if (_step > (_isEditing ? 1 : 0)) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: !canNext || _submitting
                          ? null
                          : _step == 4
                              ? _submit
                              : () => setState(() => _step++),
                      child: Text(
                        _step == 4
                            ? (_submitting
                                ? 'Enregistrement…'
                                : (_isEditing
                                    ? 'Enregistrer les modifications'
                                    : 'Publier l’annonce'))
                            : 'Continuer',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

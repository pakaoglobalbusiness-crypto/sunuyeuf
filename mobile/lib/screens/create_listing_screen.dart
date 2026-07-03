import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';

/// Création d'annonce guidée en 5 étapes max (F10) :
/// type → photos → description → prix → publication.
class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  int _step = 0;
  bool _submitting = false;

  // Étape 1 : type
  String _type = 'villa';

  // Étape 2 : photos (URLs en dev ; upload caméra/galerie en prod)
  final _photoCtrl = TextEditingController();
  final List<String> _photos = [];

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
  final _modelCtrl = TextEditingController();
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
    try {
      await Api.post('/listings', body: {
        'type': _type,
        'title': _titleCtrl.text,
        'description': _descCtrl.text,
        'city': _city,
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
            'model': _modelCtrl.text,
            'year': int.tryParse(_yearCtrl.text) ?? 2020,
            'gearbox': _gearbox,
            'fuel': _fuel,
            'withDriver': _withDriver,
            'kmIncludedDay': 200,
            'deliveryPlace': _delivery,
          },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Annonce envoyée en modération ! Elle sera en ligne après validation '
          'par notre équipe.',
        ),
      ));
      Navigator.of(context).pop();
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
          icon: const Icon(Icons.add_circle_outline, color: senegalGreen),
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
              color: _type == value ? const Color(0xFFEDF5EF) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: _type == value ? senegalGreen : Colors.grey.shade300,
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
            'Des photos authentiques inspirent confiance. '
            '(En version finale : appareil photo / galerie.)',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _photoCtrl,
                  decoration: const InputDecoration(hintText: 'URL de la photo'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: senegalGreen),
                onPressed: () {
                  if (_photoCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _photos.add(_photoCtrl.text.trim());
                      _photoCtrl.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, url) in _photos.indexed)
            ListTile(
              dense: true,
              leading: const Icon(Icons.photo),
              title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => setState(() => _photos.removeAt(i)),
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
            decoration: const InputDecoration(labelText: 'Titre de l’annonce'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
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
              activeThumbColor: senegalGreen,
            ),
            SwitchListTile(
              value: _wifi,
              onChanged: (v) => setState(() => _wifi = v),
              title: const Text('Wifi'),
              activeThumbColor: senegalGreen,
            ),
            SwitchListTile(
              value: _ac,
              onChanged: (v) => setState(() => _ac = v),
              title: const Text('Climatisation'),
              activeThumbColor: senegalGreen,
            ),
            SwitchListTile(
              value: _guard,
              onChanged: (v) => setState(() => _guard = v),
              title: const Text('Gardien'),
              activeThumbColor: senegalGreen,
            ),
          ] else ...[
            TextField(
              controller: _brandCtrl,
              decoration: const InputDecoration(labelText: 'Marque'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(labelText: 'Modèle'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _yearCtrl,
              keyboardType: TextInputType.number,
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
              activeThumbColor: senegalGreen,
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
            activeThumbColor: senegalGreen,
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
                'par jour loué (commission Sunuyeuf : 10 %).',
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
                        color: senegalGreen, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Votre annonce sera vérifiée par notre équipe avant publication '
            '(sous 24 h en général).',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    ];

    final canNext = switch (_step) {
      2 => _titleCtrl.text.isNotEmpty && _descCtrl.text.isNotEmpty,
      3 => (int.tryParse(_priceCtrl.text) ?? 0) >= 1000,
      _ => true,
    };

    return Scaffold(
      appBar: AppBar(title: Text('Nouvelle annonce — étape ${_step + 1}/5')),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / 5,
            color: senegalGreen,
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
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Retour'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
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
                            ? (_submitting ? 'Envoi…' : 'Publier l’annonce')
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

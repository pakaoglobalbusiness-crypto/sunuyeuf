import 'package:flutter/material.dart';

import '../main.dart';
import '../senegal_data.dart';

/// Marques de voitures courantes au Sénégal (filtre section voiture).
const carBrands = [
  'Toyota', 'Hyundai', 'Peugeot', 'Renault', 'Mercedes', 'Kia', 'Nissan',
  'Ford', 'Volkswagen', 'Honda', 'Suzuki', 'Dacia', 'Mitsubishi', 'BMW',
  'Audi', 'Land Rover', 'Citroën', 'Fiat',
];

/// État des filtres de recherche.
class Filters {
  String? region;
  String? department;
  String? commune;
  int? minPrice;
  int? maxPrice;
  double? minRating;
  bool instant = false;
  // Logements
  int? minBedrooms;
  int? minCapacity;
  bool pool = false;
  bool wifi = false;
  bool ac = false;
  bool guard = false;
  // Voitures
  String? brand;
  String? gearbox;
  String? fuel;
  bool withDriver = false;

  Filters clone() {
    return Filters()
      ..region = region
      ..department = department
      ..commune = commune
      ..minPrice = minPrice
      ..maxPrice = maxPrice
      ..minRating = minRating
      ..instant = instant
      ..minBedrooms = minBedrooms
      ..minCapacity = minCapacity
      ..pool = pool
      ..wifi = wifi
      ..ac = ac
      ..guard = guard
      ..brand = brand
      ..gearbox = gearbox
      ..fuel = fuel
      ..withDriver = withDriver;
  }

  /// Nombre de filtres actifs (pour le badge du bouton).
  int count(String type) {
    var n = 0;
    if (region != null) n++;
    if (department != null) n++;
    if (commune != null) n++;
    if (minPrice != null || maxPrice != null) n++;
    if (minRating != null) n++;
    if (instant) n++;
    if (type == 'villa') {
      if (minBedrooms != null) n++;
      if (minCapacity != null) n++;
      if (pool) n++;
      if (wifi) n++;
      if (ac) n++;
      if (guard) n++;
    } else {
      if (brand != null) n++;
      if (gearbox != null) n++;
      if (fuel != null) n++;
      if (withDriver) n++;
    }
    return n;
  }

  /// Construit les paramètres de requête pour l'API.
  Map<String, String> toQuery(String type) {
    return {
      'type': type,
      if (region != null) 'city': region!,
      if (department != null) 'department': department!,
      if (commune != null) 'commune': commune!,
      if (minPrice != null) 'minPrice': '$minPrice',
      if (maxPrice != null) 'maxPrice': '$maxPrice',
      if (minRating != null) 'minRating': '$minRating',
      if (instant) 'instant': 'true',
      if (type == 'villa') ...{
        if (minBedrooms != null) 'minBedrooms': '$minBedrooms',
        if (minCapacity != null) 'minCapacity': '$minCapacity',
        if (pool) 'pool': 'true',
        if (wifi) 'wifi': 'true',
        if (ac) 'ac': 'true',
        if (guard) 'guard': 'true',
      },
      if (type == 'voiture') ...{
        if (brand != null) 'brand': brand!,
        if (gearbox != null) 'gearbox': gearbox!,
        if (fuel != null) 'fuel': fuel!,
        if (withDriver) 'withDriver': 'true',
      },
    };
  }
}

/// Panneau de filtres (bottom sheet) contextuel au type (logement/voiture).
class FilterSheet extends StatefulWidget {
  final Filters filters;
  final String type;
  const FilterSheet({super.key, required this.filters, required this.type});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Filters f;

  @override
  void initState() {
    super.initState();
    f = widget.filters.clone();
  }

  @override
  Widget build(BuildContext context) {
    final isVilla = widget.type == 'villa';
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                const Text('Filtres',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => f = Filters()),
                  child: const Text('Réinitialiser'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                // Localisation
                _label('Localisation'),
                DropdownButtonFormField<String>(
                  initialValue: f.region,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Région'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Toutes')),
                    for (final r in Senegal.regions)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => setState(() {
                    f.region = v;
                    f.department = null;
                    f.commune = null;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: f.department,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Département'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    for (final d in Senegal.departments(f.region))
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: f.region == null
                      ? null
                      : (v) => setState(() {
                            f.department = v;
                            f.commune = null;
                          }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: f.commune,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Commune'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Toutes')),
                    for (final c in Senegal.communes(f.region, f.department))
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: f.department == null
                      ? null
                      : (v) => setState(() => f.commune = v),
                ),
                const SizedBox(height: 20),

                // Budget
                _label('Budget par jour (FCFA)'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (min, max, lbl) in [
                      (null, 25000, '≤ 25 000'),
                      (25000, 50000, '25–50k'),
                      (50000, 100000, '50–100k'),
                      (100000, null, '≥ 100 000'),
                    ])
                      _chip(
                        lbl,
                        f.minPrice == min && f.maxPrice == max,
                        () => setState(() {
                          if (f.minPrice == min && f.maxPrice == max) {
                            f.minPrice = null;
                            f.maxPrice = null;
                          } else {
                            f.minPrice = min;
                            f.maxPrice = max;
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Note minimale
                _label('Note minimale'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in [3.0, 4.0, 4.5])
                      _chip('${r == r.toInt() ? r.toInt() : r} ★', f.minRating == r,
                          () => setState(() => f.minRating = f.minRating == r ? null : r)),
                  ],
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: f.instant,
                  onChanged: (v) => setState(() => f.instant = v),
                  title: const Text('Réservation instantanée'),
                  activeThumbColor: gologuiTeal,
                ),
                const Divider(height: 24),

                if (isVilla) ...[
                  _label('Logement'),
                  _counter('Chambres (min.)', f.minBedrooms ?? 0,
                      (v) => setState(() => f.minBedrooms = v == 0 ? null : v)),
                  _counter('Capacité (min.)', f.minCapacity ?? 0,
                      (v) => setState(() => f.minCapacity = v == 0 ? null : v)),
                  const SizedBox(height: 8),
                  _label('Équipements'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('🏊 Piscine', f.pool, () => setState(() => f.pool = !f.pool)),
                      _chip('📶 Wifi', f.wifi, () => setState(() => f.wifi = !f.wifi)),
                      _chip('❄️ Clim', f.ac, () => setState(() => f.ac = !f.ac)),
                      _chip('💂 Gardien', f.guard, () => setState(() => f.guard = !f.guard)),
                    ],
                  ),
                ] else ...[
                  _label('Voiture'),
                  DropdownButtonFormField<String>(
                    initialValue: f.brand,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Marque'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Toutes')),
                      for (final b in carBrands)
                        DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() => f.brand = v),
                  ),
                  const SizedBox(height: 12),
                  _label('Boîte de vitesses'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final g in ['manuelle', 'automatique'])
                        _chip(g[0].toUpperCase() + g.substring(1), f.gearbox == g,
                            () => setState(() => f.gearbox = f.gearbox == g ? null : g)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _label('Carburant'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in ['essence', 'diesel', 'hybride', 'electrique'])
                        _chip(c[0].toUpperCase() + c.substring(1), f.fuel == c,
                            () => setState(() => f.fuel = f.fuel == c ? null : c)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: f.withDriver,
                    onChanged: (v) => setState(() => f.withDriver = v),
                    title: const Text('Avec chauffeur'),
                    activeThumbColor: gologuiTeal,
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(f),
                child: const Text('Voir les résultats'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? scheme.onPrimary : scheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _counter(String label, int value, void Function(int) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(value == 0 ? '—' : '$value',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline, color: gologuiTeal),
        ),
      ],
    );
  }
}

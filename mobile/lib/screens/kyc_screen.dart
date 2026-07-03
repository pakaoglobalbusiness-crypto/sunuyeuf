import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';

/// Vérification d'identité (F15) en 3 étapes :
/// 1. choix du document (CNI ou permis)
/// 2. recto + verso avec aperçu des photos
/// 3. selfie avec aperçu, puis envoi
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  int _step = 0;
  String _docType = 'cni'; // cni | permis
  String? _rectoUrl;
  String? _versoUrl;
  String? _selfieUrl;
  bool _uploading = false;
  bool _submitting = false;

  String get _docLabel =>
      _docType == 'cni' ? 'Carte nationale d’identité' : 'Permis de conduire';

  Future<String?> _pickAndUpload({bool selfie = false}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, // caméra sur téléphone, galerie sur le web
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    setState(() => _uploading = true);
    try {
      return await Api.uploadBytes(await picked.readAsBytes(), picked.name);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await Api.post('/users/me/kyc', body: {
        'documents': [
          {'type': '${_docType}_recto', 'fileUrl': _rectoUrl},
          {'type': '${_docType}_verso', 'fileUrl': _versoUrl},
          {'type': 'selfie', 'fileUrl': _selfieUrl},
        ],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Documents envoyés ! Vérification sous 24 h.'),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final steps = <Widget>[
      // ---- Étape 1 : choix du document ----
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quel document utilisez-vous ?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Le document doit être en cours de validité et lisible.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 20),
          for (final (value, emoji, label) in [
            ('cni', '🪪', 'Carte nationale d’identité'),
            ('permis', '🚗', 'Permis de conduire'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: _docType == value ? scheme.primary : scheme.outlineVariant,
                    width: _docType == value ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: Text(emoji, style: const TextStyle(fontSize: 30)),
                  title: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _docType == value
                      ? Icon(Icons.check_circle, color: scheme.primary)
                      : null,
                  onTap: () => setState(() => _docType = value),
                ),
              ),
            ),
        ],
      ),
      // ---- Étape 2 : recto + verso avec aperçus ----
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _docLabel,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Photographiez les deux faces du document.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 20),
          _PhotoSlot(
            label: 'RECTO',
            hint: 'Face avec votre photo',
            url: _rectoUrl,
            uploading: _uploading,
            onTap: () async {
              final url = await _pickAndUpload();
              if (url != null) setState(() => _rectoUrl = url);
            },
          ),
          const SizedBox(height: 14),
          _PhotoSlot(
            label: 'VERSO',
            hint: 'Face arrière du document',
            url: _versoUrl,
            uploading: _uploading,
            onTap: () async {
              final url = await _pickAndUpload();
              if (url != null) setState(() => _versoUrl = url);
            },
          ),
        ],
      ),
      // ---- Étape 3 : selfie ----
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Un selfie pour finir 🤳',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Visage bien éclairé, sans lunettes de soleil ni chapeau. '
            'Notre équipe le comparera à votre document.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: _uploading
                  ? null
                  : () async {
                      final url = await _pickAndUpload(selfie: true);
                      if (url != null) setState(() => _selfieUrl = url);
                    },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: Border.all(
                    color: _selfieUrl != null ? scheme.primary : scheme.outlineVariant,
                    width: 3,
                  ),
                  image: _selfieUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_selfieUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selfieUrl == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_uploading)
                            const CircularProgressIndicator()
                          else ...[
                            Icon(Icons.add_a_photo_outlined,
                                size: 40,
                                color: scheme.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            const Text('Prendre le selfie'),
                          ],
                        ],
                      )
                    : null,
              ),
            ),
          ),
          if (_selfieUrl != null)
            TextButton.icon(
              onPressed: () async {
                final url = await _pickAndUpload(selfie: true);
                if (url != null) setState(() => _selfieUrl = url);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reprendre la photo'),
            ),
        ],
      ),
    ];

    final canContinue = switch (_step) {
      0 => true,
      1 => _rectoUrl != null && _versoUrl != null,
      _ => _selfieUrl != null,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Vérification d’identité')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: steps[_step],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => setState(() => _step--),
                        child: const Text('Retour'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: !canContinue || _uploading || _submitting
                          ? null
                          : _step == 2
                              ? _submit
                              : () => setState(() => _step++),
                      child: Text(
                        _step == 2
                            ? (_submitting ? 'Envoi…' : 'Envoyer mes documents')
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

/// Emplacement photo avec aperçu (format carte d'identité).
class _PhotoSlot extends StatelessWidget {
  final String label;
  final String hint;
  final String? url;
  final bool uploading;
  final VoidCallback onTap;
  const _PhotoSlot({
    required this.label,
    required this.hint,
    required this.url,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: AspectRatio(
        aspectRatio: 1.7, // format carte
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: url != null ? scheme.primary : scheme.outlineVariant,
              width: url != null ? 2 : 1,
            ),
            image: url != null
                ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
                : null,
          ),
          child: url != null
              ? Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$label ✓',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child:
                              Icon(Icons.edit, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (uploading)
                      const CircularProgressIndicator()
                    else ...[
                      Icon(Icons.add_a_photo_outlined,
                          size: 34, color: scheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(height: 6),
                      Text(label,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

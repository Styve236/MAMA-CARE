import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import 'app_theme.dart';

/// Affiche une photo de profil distante, ou une icone de repli.
///
/// Utilisee partout ou l on liste des patients ou des medecins.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    this.url,
    this.radius = 30,
    this.fallbackIcon = Icons.person,
  });

  final String? url;
  final double radius;
  final IconData fallbackIcon;

  bool get _hasImage => url != null && url!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.lightBurgundy,
      child: Icon(
        fallbackIcon,
        size: radius * 1.4,
        color: AppColors.burgundy,
      ),
    );
    if (!_hasImage) return fallback;
    return ClipOval(
      child: Image.network(
        url!.trim(),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        // En cas de photo cassee ou absente, on retombe sur l icone.
        errorBuilder: (context, error, stack) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

/// Avatar cliquable : permet de choisir, retirer ou remplacer sa photo.
///
/// L image est reduite a [maxDimension] et compressee avant l envoi, ce qui
/// evite de saturer la base et le stockage.
class AvatarEditor extends StatefulWidget {
  const AvatarEditor({
    super.key,
    required this.isDoctor,
    required this.avatarUrl,
    required this.onSaved,
    this.radius = 45,
  });

  final bool isDoctor;
  final String? avatarUrl;
  final ValueChanged<String?> onSaved;
  final double radius;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  static const int maxDimension = 512;
  static const int jpegQuality = 80;
  static const int maxUploadBytes = 2 * 1024 * 1024;

  final ImagePicker _picker = ImagePicker();

  String? _url;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _url = widget.avatarUrl;
  }

  @override
  void didUpdateWidget(covariant AvatarEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.avatarUrl != oldWidget.avatarUrl) {
      _url = widget.avatarUrl;
    }
  }

  Future<void> _openMenu() async {
    if (_busy) return;
    final hasImage = _url != null && _url!.trim().isNotEmpty;
    // La camera n existe pas sur le web : defaultTargetPlatform est sur en
    // web, contrairement a dart:io Platform qui leve UnsupportedError.
    final cameraAvailable = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir une photo'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (cameraAvailable)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
            if (hasImage)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                title: Text(
                  'Retirer la photo',
                  style: TextStyle(color: Colors.red.shade700),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            ListTile(
              title: const Text('Annuler'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;
    if (action == 'remove') {
      await _remove();
    } else {
      await _pick(action == 'camera' ? ImageSource.camera : ImageSource.gallery);
    }
  }

  Future<void> _pick(ImageSource source) async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: maxDimension.toDouble(),
        maxHeight: maxDimension.toDouble(),
        imageQuality: jpegQuality,
      );
    } catch (_) {
      _notify('Selection de l image impossible.', error: true);
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _notify('Image vide.', error: true);
        return;
      }
      if (bytes.length > maxUploadBytes) {
        _notify('Photo trop volumineuse. Choisissez une image plus legere.',
            error: true);
        return;
      }
      final url = await ApiClient.uploadAvatar(
        isDoctor: widget.isDoctor,
        dataBase64: base64Encode(bytes),
        contentType: _contentTypeOf(picked.mimeType),
      );
      if (!mounted) return;
      setState(() => _url = url);
      widget.onSaved(url);
      _notify('Photo de profil mise a jour.');
    } on ApiException catch (error) {
      if (!mounted) return;
      _notify(error.message, error: true);
    } catch (_) {
      if (!mounted) return;
      _notify('Envoi de la photo impossible.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ApiClient.deleteAvatar(isDoctor: widget.isDoctor);
      if (!mounted) return;
      setState(() => _url = null);
      widget.onSaved(null);
      _notify('Photo de profil retiree.');
    } on ApiException catch (error) {
      if (!mounted) return;
      _notify(error.message, error: true);
    } catch (_) {
      if (!mounted) return;
      _notify('Suppression impossible.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Le serveur n accepte que JPEG, PNG et WebP : on force le bon type MIME
  /// plutot que de rejeter une photo prise sur un iPhone (HEIC).
  String _contentTypeOf(String? mimeType) {
    const allowed = {'image/jpeg', 'image/png', 'image/webp'};
    final value = mimeType?.trim().toLowerCase();
    if (value != null && allowed.contains(value)) return value;
    return 'image/jpeg';
  }

  void _notify(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        GestureDetector(
          onTap: _openMenu,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AvatarCircle(url: _url, radius: widget.radius),
              if (_busy)
                Container(
                  width: widget.radius * 2,
                  height: widget.radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  child: const Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.burgundy,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        IgnorePointer(
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.burgundy,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: widget.radius * 0.36,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
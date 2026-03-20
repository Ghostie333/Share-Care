import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/models/annoucement.dart';

class AnnouncementFormSheet extends StatefulWidget {
  final Announcement? existingAd;
  final String ownerName;
  final void Function(
    String title,
    String description,
    String location,
    double? deposit,
    List<XFile> images,
  ) onSubmit;

  const AnnouncementFormSheet({
    super.key,
    this.existingAd,
    required this.ownerName,
    required this.onSubmit,
  });

  @override
  State<AnnouncementFormSheet> createState() => _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState extends State<AnnouncementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _depositController;

  final List<XFile> _selectedImages = [];
  final Map<String, Uint8List> _imageBytesByPath = {};

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingAd?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingAd?.description ?? '');
    _locationController =
        TextEditingController(text: widget.existingAd?.location ?? '');
    _depositController = TextEditingController(
      text: widget.existingAd?.deposit?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existingAd;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null
                    ? 'Dodaj nowe ogłoszenie'
                    : 'Edytuj ogłoszenie',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tytuł ogłoszenia',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj tytuł ogłoszenia';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Opis',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj opis ogłoszenia';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Lokalizacja',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj lokalizację';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildImagesPicker(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kaucja (opcjonalnie)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _onSavePressed,
                  child: const Text('Zapisz ogłoszenie'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagesPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Zdjęcia (max 8)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${_selectedImages.length}/8'),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo_library),
              label: const Text('Dodaj'),
            ),
            if (_selectedImages.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectedImages.clear();
                  _imageBytesByPath.clear();
                }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Wyczyść'),
              ),
          ],
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: GridView.builder(
              itemCount: _selectedImages.length,
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _imageBytesByPath.containsKey(image.path)
                            ? Image.memory(
                                _imageBytesByPath[image.path]!,
                                fit: BoxFit.cover,
                              )
                            : const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                ),
                                child: Center(
                                  child: Icon(Icons.image, color: Colors.black38),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          final image = _selectedImages[index];
                          setState(() {
                            _selectedImages.removeAt(index);
                            _imageBytesByPath.remove(image.path);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickImages() async {
    final remaining = 8 - _selectedImages.length;
    if (remaining <= 0) return;

    final ImagePicker picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(
      imageQuality: 80,
    );

    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).toList();
    final newBytes = <String, Uint8List>{};
    for (final image in toAdd) {
      try {
        newBytes[image.path] = await image.readAsBytes();
      } catch (_) {
        // Jeśli odczyt bajtów się nie powiedzie, podgląd nie zostanie
        // wyświetlony, ale zdjęcie nadal trafi do formularza.
      }
    }

    setState(() {
      _imageBytesByPath.addAll(newBytes);
      _selectedImages.addAll(toAdd);
    });
  }

  void _onSavePressed() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final double? deposit = double.tryParse(
      _depositController.text.replaceAll(',', '.'),
    );

    widget.onSubmit(
      _titleController.text.trim(),
      _descriptionController.text.trim(),
      _locationController.text.trim(),
      deposit,
      _selectedImages,
    );

    Navigator.of(context).pop();
  }
}

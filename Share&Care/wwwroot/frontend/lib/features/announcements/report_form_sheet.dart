import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/annoucement.dart';

class ReportFormSheet extends StatefulWidget {
  final Announcement? existingAd;
  final String ownerName;

  final void Function(
    String title,
    String description,
    String location,
    double? deposit,
    List<XFile> images,
    String category,
    String type,
    bool isUrgent,
    DateTime? expiresAt,
  )
  onSubmit;

  final List<String> categories;
  final List<String> types;

  final String initialCategory;
  final String initialType;

  const ReportFormSheet({
    super.key,
    this.existingAd,
    required this.ownerName,
    required this.onSubmit,
    required this.categories,
    required this.types,
    required this.initialCategory,
    required this.initialType,
  });

  @override
  State<ReportFormSheet> createState() => _ReportFormSheetState();
}

class _ReportFormSheetState extends State<ReportFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _depositController;
  late final TextEditingController _expiresAtController;

  final List<XFile> _selectedImages = [];
  final Map<String, Uint8List> _imageBytesByPath = {};

  late String _selectedCategory;
  late String _selectedType;
  bool _isUrgent = false;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingAd?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingAd?.description ?? '',
    );
    _locationController = TextEditingController(
      text: widget.existingAd?.location ?? '',
    );
    _depositController = TextEditingController(
      text: widget.existingAd?.deposit?.toString() ?? '',
    );

    _expiresAtController = TextEditingController();

    _selectedCategory = widget.initialCategory;
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _depositController.dispose();
    _expiresAtController.dispose();
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
                    ? 'Dodaj nowe zgloszenie'
                    : 'Edytuj zgloszenie',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Kategoria',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedCategory = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Typ',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.types
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedType = v);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tytul',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj tytul';
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
                    return 'Podaj opis';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Lokalizacja',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj lokalizacje';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isUrgent,
                onChanged: (v) {
                  setState(() {
                    _isUrgent = v ?? false;
                  });
                },
                title: const Text('Zgłoszenie pilne'),
              ),

              TextFormField(
                controller: _expiresAtController,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Wyświetlaj zgłoszenie do (DD.MM.RRRR)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: () => _pickExpiryDate(context),
                  ),
                ),
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  if (raw.isEmpty) {
                    return null; // pole opcjonalne
                  }
                  final dateRegex = RegExp(r'^\d{2}\.\d{2}\.\d{4}$');
                  if (!dateRegex.hasMatch(raw)) {
                    return 'Format daty: DD.MM.RRRR';
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
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _onSavePressed(),
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
                  child: const Text('Zapisz'),
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
              'Zdjecia (max 8)',
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
                label: const Text('Wyczysc'),
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
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
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
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 80);

    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).toList();
    final newBytes = <String, Uint8List>{};
    for (final image in toAdd) {
      try {
        newBytes[image.path] = await image.readAsBytes();
      } catch (_) {}
    }

    setState(() {
      _imageBytesByPath.addAll(newBytes);
      _selectedImages.addAll(toAdd);
    });
  }

  void _onSavePressed() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final double? deposit = double.tryParse(
      _depositController.text.replaceAll(',', '.'),
    );

    DateTime? expiresAt = _expiresAt;
    final raw = _expiresAtController.text.trim();
    if (expiresAt == null && raw.isNotEmpty) {
      try {
        final parts = raw.split('.');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          expiresAt = DateTime(year, month, day);
        }
      } catch (_) {
        // Jeśli parsowanie się nie uda – zostawiamy null.
      }
    }

    widget.onSubmit(
      _titleController.text.trim(),
      _descriptionController.text.trim(),
      _locationController.text.trim(),
      deposit,
      _selectedImages,
      _selectedCategory,
      _selectedType,
      _isUrgent,
      expiresAt,
    );

    Navigator.of(context).pop();
  }

  Future<void> _pickExpiryDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = _expiresAt ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (selected == null) return;

    setState(() {
      _expiresAt = selected;
      final day = selected.day.toString().padLeft(2, '0');
      final month = selected.month.toString().padLeft(2, '0');
      final year = selected.year.toString();
      _expiresAtController.text = '$day.$month.$year';
    });
  }
}

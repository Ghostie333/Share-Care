import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/models/annoucement.dart';
import 'announcement_metadata.dart';

class AnnouncementFormSheet extends StatefulWidget {
  final Announcement? existingAd;
  final String ownerName;

  final List<String> categories;
  final List<String> types;
  final List<String> offerKinds;

  final String? initialCategory;
  final String? initialType;
  final String? initialOfferKind;
  final String? initialCity;
  final String? initialPhoneNumber;

  final void Function(
    String title,
    String description,
    String location,
    double? deposit,
    List<XFile> images,
    String category,
    String type,
    String offerKind,
    String contactNumber,
    DateTime? expirationDate,
  )
  onSubmit;

  const AnnouncementFormSheet({
    super.key,
    this.existingAd,
    required this.ownerName,
    required this.categories,
    required this.types,
    required this.offerKinds,
    this.initialCategory,
    this.initialType,
    this.initialOfferKind,
    this.initialCity,
    this.initialPhoneNumber,
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
  late final TextEditingController _contactNumberController;
  late final TextEditingController _expirationController;

  final List<XFile> _selectedImages = [];
  final Map<String, Uint8List> _imageBytesByPath = {};

  late String _selectedCategory;
  late String _selectedType;
  late String _selectedOfferKind;
  bool _useProfileCity = false;
  bool _useProfilePhone = false;

  bool get _isBorrow => _selectedOfferKind == 'Borrow';
  bool get _isFoodCategory => _selectedCategory == 'Jedzenie';

  DateTime? _expirationDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAd;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _locationController = TextEditingController(
      text: existing?.location ?? (widget.initialCity ?? ''),
    );
    _depositController = TextEditingController(
      text: existing?.deposit?.toString() ?? '',
    );
    _contactNumberController = TextEditingController(
      text: widget.initialPhoneNumber ?? '',
    );
    _expirationController = TextEditingController();

    final existingCategoryEncoded = existing?.category ?? '';

    _selectedCategory = existingCategoryEncoded.trim().isNotEmpty
      ? AnnouncementMetadata.parseCategory(existingCategoryEncoded)
      : (widget.initialCategory ?? AnnouncementMetadata.defaultCategory);
    _selectedType = existingCategoryEncoded.trim().isNotEmpty
      ? AnnouncementMetadata.parseType(existingCategoryEncoded)
      : (widget.initialType ?? AnnouncementMetadata.defaultAnnouncementType);
    _selectedOfferKind =
      widget.initialOfferKind ?? AnnouncementMetadata.offerKinds.first;

    if (!_isBorrow) {
      _depositController.clear();
    }

    _expirationDate = existing?.expiresAt;
    _expirationController.text = _formatDate(_expirationDate);

    _useProfileCity = (widget.initialCity ?? '').isNotEmpty;
    _useProfilePhone = (widget.initialPhoneNumber ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _depositController.dispose();
    _contactNumberController.dispose();
    _expirationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existingAd;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 520;

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
              Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      existing == null
                          ? 'Dodaj nowe ogłoszenie'
                          : 'Edytuj ogłoszenie',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zamknij',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Tytuł ogłoszenia',
                  helperText: 'Maksymalnie 50 znaków',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj tytuł ogłoszenia';
                  }
                  if (value.trim().length > 50) {
                    return 'Tytuł może mieć maksymalnie 50 znaków';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Opis',
                  helperText: 'Maksymalnie 300 znaków',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj opis ogłoszenia';
                  }
                  if (value.trim().length > 300) {
                    return 'Opis może mieć maksymalnie 300 znaków';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              isNarrow
                  ? Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategoria',
                            border: OutlineInputBorder(),
                          ),
                          items: widget.categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedCategory = v;
                              if (!_isFoodCategory) {
                                _expirationDate = null;
                                _expirationController.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Typ',
                            border: OutlineInputBorder(),
                          ),
                          items: widget.types
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedType = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedOfferKind,
                          decoration: const InputDecoration(
                            labelText: 'Rodzaj',
                            border: OutlineInputBorder(),
                          ),
                          items: widget.offerKinds
                              .map(
                                (k) => DropdownMenuItem(
                                  value: k,
                                  child: Text(
                                    AnnouncementMetadata.offerKindLabel(k),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedOfferKind = v;
                              if (!_isBorrow) {
                                _depositController.clear();
                              }
                            });
                          },
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Kategoria',
                              border: OutlineInputBorder(),
                            ),
                            items: widget.categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _selectedCategory = v;
                                if (!_isFoodCategory) {
                                  _expirationDate = null;
                                  _expirationController.clear();
                                }
                              });
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
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _selectedType = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedOfferKind,
                            decoration: const InputDecoration(
                              labelText: 'Rodzaj',
                              border: OutlineInputBorder(),
                            ),
                            items: widget.offerKinds
                                .map(
                                  (k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(
                                      AnnouncementMetadata.offerKindLabel(k),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _selectedOfferKind = v;
                                if (!_isBorrow) {
                                  _depositController.clear();
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                readOnly: _useProfileCity,
                textInputAction: TextInputAction.next,
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
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _useProfileCity,
                onChanged: (v) {
                  setState(() {
                    _useProfileCity = v ?? false;
                    if (_useProfileCity) {
                      _locationController.text = widget.initialCity ?? '';
                    }
                  });
                },
                title: Text(
                  'Użyj miasta z profilu (${(widget.initialCity ?? '').isEmpty ? 'brak' : widget.initialCity})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactNumberController,
                readOnly: _useProfilePhone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Numer telefonu do kontaktu',
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _useProfilePhone,
                onChanged: (v) {
                  setState(() {
                    _useProfilePhone = v ?? false;
                    if (_useProfilePhone) {
                      _contactNumberController.text =
                          widget.initialPhoneNumber ?? '';
                    }
                  });
                },
                title: Text(
                  'Użyj numeru telefonu z profilu (${(widget.initialPhoneNumber ?? '').isEmpty ? 'brak' : widget.initialPhoneNumber})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              _buildImagesPicker(),
              if (_isFoodCategory) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expirationController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Termin ważności',
                    helperText: 'Wymagane dla kategorii Jedzenie',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expirationDate ?? now,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: DateTime(now.year + 10),
                    );
                    if (picked == null) return;
                    setState(() {
                      _expirationDate = picked;
                      _expirationController.text = _formatDate(picked);
                    });
                  },
                  validator: (_) {
                    if (_isFoodCategory && _expirationDate == null) {
                      return 'Podaj termin ważności';
                    }
                    return null;
                  },
                ),
              ],
              if (_isBorrow) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _depositController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _onSavePressed(),
                  decoration: const InputDecoration(
                    labelText: 'Kaucja (wymagana)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Wymagana kaucja dla wypożyczenia';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: isNarrow ? double.infinity : null,
                  child: ElevatedButton(
                    onPressed: _onSavePressed,
                    child: const Text('Zapisz ogłoszenie'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagesPicker() {
    final isNarrow = MediaQuery.of(context).size.width < 520;

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
            height: isNarrow ? 200 : 170,
            child: GridView.builder(
              itemCount: _selectedImages.length,
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isNarrow ? 3 : 4,
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
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 80);

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

    final double? deposit = _isBorrow
        ? double.tryParse(_depositController.text.replaceAll(',', '.'))
        : null;

    widget.onSubmit(
      _titleController.text.trim(),
      _descriptionController.text.trim(),
      _locationController.text.trim(),
      deposit,
      _selectedImages,
      _selectedCategory,
      _selectedType,
      _selectedOfferKind,
      _contactNumberController.text.trim(),
      _expirationDate,
    );

    Navigator.of(context).pop();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

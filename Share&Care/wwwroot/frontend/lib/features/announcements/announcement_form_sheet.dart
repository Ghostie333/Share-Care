import 'package:flutter/material.dart';

import '../../features/models/annoucement.dart';

class AnnouncementFormSheet extends StatefulWidget {
  final Announcement? existingAd;
  final String ownerName;
  final void Function(
    String title,
    String description,
    String location,
    double? deposit,
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
    );
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
    );

    Navigator.of(context).pop();
  }
}

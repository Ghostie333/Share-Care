import 'package:flutter/material.dart';

import '../../core/classic_style.dart';
import '../announcements/announcement_metadata.dart';
import 'search_filters.dart';

class FiltersPage extends StatefulWidget {
  final SearchFilters initial;

  const FiltersPage({super.key, required this.initial});

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  late SortOption? _sortOption;
  late String? _category;
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _locationController = TextEditingController();
  final _radiusController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sortOption = widget.initial.sortOption;
    _category = widget.initial.category;
    if (widget.initial.minDeposit != null) {
      _minPriceController.text = widget.initial.minDeposit!.toStringAsFixed(0);
    }
    if (widget.initial.maxDeposit != null) {
      _maxPriceController.text = widget.initial.maxDeposit!.toStringAsFixed(0);
    }
    if (widget.initial.location != null) {
      _locationController.text = widget.initial.location!;
    }
    if (widget.initial.radiusKm != null) {
      _radiusController.text = widget.initial.radiusKm!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _locationController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _apply() {
    final minPrice = double.tryParse(_minPriceController.text.replaceAll(',', '.'));
    final maxPrice = double.tryParse(_maxPriceController.text.replaceAll(',', '.'));
    final radius = double.tryParse(_radiusController.text.replaceAll(',', '.'));

    final filters = SearchFilters(
      sortOption: _sortOption,
      category: _category,
      minDeposit: minPrice,
      maxDeposit: maxPrice,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      radiusKm: radius,
    );

    Navigator.of(context).pop<SearchFilters>(filters);
  }

  void _clear() {
    setState(() {
      _sortOption = null;
      _category = null;
      _minPriceController.clear();
      _maxPriceController.clear();
      _locationController.clear();
      _radiusController.clear();
    });
    Navigator.of(context).pop<SearchFilters>(const SearchFilters());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtry'),
        backgroundColor: ClassicStyle.my_dark_green,
        foregroundColor: Colors.white,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sortowanie',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('Domyślne'),
                    selected: _sortOption == null,
                    onSelected: (_) {
                      setState(() => _sortOption = null);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Nazwa A-Z'),
                    selected: _sortOption == SortOption.nameAsc,
                    onSelected: (_) {
                      setState(() => _sortOption = SortOption.nameAsc);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Nazwa Z-A'),
                    selected: _sortOption == SortOption.nameDesc,
                    onSelected: (_) {
                      setState(() => _sortOption = SortOption.nameDesc);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Kaucja rosnąco'),
                    selected: _sortOption == SortOption.depositAsc,
                    onSelected: (_) {
                      setState(() => _sortOption = SortOption.depositAsc);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Kaucja malejąco'),
                    selected: _sortOption == SortOption.depositDesc,
                    onSelected: (_) {
                      setState(() => _sortOption = SortOption.depositDesc);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text(
                'Kategoria',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _category,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                hint: const Text('Wszystkie kategorie'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Wszystkie kategorie'),
                  ),
                  ...AnnouncementMetadata.categories.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c,
                      child: Text(c),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _category = value);
                },
              ),

              const SizedBox(height: 24),
              Text(
                'Cena (kaucja)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text(
                'Lokalizacja',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Miasto / lokalizacja',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _radiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Promień (km)',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clear,
                      child: const Text('Wyczyść'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClassicStyle.my_light_green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Zastosuj'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/classic_style.dart';
import 'announcement_metadata.dart';
import '../models/annoucement.dart';

class AnnouncementDetailsDialog extends StatefulWidget {
  final Announcement ad;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onChat;
  final VoidCallback? onClose; // oznaczenie ogłoszenia jako nieaktywne

  const AnnouncementDetailsDialog({
    super.key,
    required this.ad,
    this.onEdit,
    this.onDelete,
    this.onChat,
    this.onClose,
  });

  @override
  State<AnnouncementDetailsDialog> createState() =>
      _AnnouncementDetailsDialogState();
}

class _AnnouncementDetailsDialogState
    extends State<AnnouncementDetailsDialog> {
  late final PageController _pageController;
  late int _currentIndex;
  Timer? _timer;

  List<String> get _images =>
      widget.ad.imageUrls.isEmpty ? ['placeholder'] : widget.ad.imageUrls;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _pageController = PageController();

    if (_images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % _images.length;
        });
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String type = AnnouncementMetadata.parseType(widget.ad.category);
    final String category =
        AnnouncementMetadata.parseCategory(widget.ad.category);

    final media = MediaQuery.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: media.size.width * 0.9,
        height: media.size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final bool useColumnLayout = maxWidth < 800;

              final imageSection = Expanded(
                flex: 3,
                child: _buildImagesSection(),
              );

              final detailsSection = Expanded(
                flex: 4,
                child: _buildDetailsSection(
                  type: type,
                  category: category,
                  maxWidth: maxWidth,
                ),
              );

              if (useColumnLayout) {
                return Column(
                  children: [
                    imageSection,
                    const SizedBox(height: 16),
                    detailsSection,
                  ],
                );
              }

              return Row(
                children: [
                  imageSection,
                  const SizedBox(width: 16),
                  detailsSection,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (_, index) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image,
                    size: 72,
                    color: Colors.black45,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final isSelected = index == _currentIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                  });
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? ClassicStyle.my_light_green
                          : Colors.grey,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.image,
                    size: 32,
                    color: Colors.black38,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection({
    required String type,
    required String category,
    required double maxWidth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.ad.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Typ: $type',
              style: const TextStyle(fontSize: 14),
            ),
            if (category.isNotEmpty)
              Text(
                'Kategoria: $category',
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Ogłoszeniodawca: ${widget.ad.ownerName}',
          style: const TextStyle(fontSize: 14),
        ),
        if ((widget.ad.contactNumber ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Telefon: ${widget.ad.contactNumber}',
            style: const TextStyle(fontSize: 14),
          ),
        ],
        const SizedBox(height: 8),
        if (widget.ad.deposit != null)
          Text(
            'Kaucja: ${widget.ad.deposit!.toStringAsFixed(2)} zł',
            style: const TextStyle(fontSize: 14),
          ),
        const SizedBox(height: 8),
        Text(
          'Lokalizacja: ${widget.ad.location}',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        const Text(
          'Opis',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              widget.ad.description,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildActionsRow(maxWidth),
      ],
    );
  }

  Widget _buildActionsRow(double maxWidth) {
    final bool ultraCompact = maxWidth < 420;
    final bool compact = maxWidth < 640;

    Widget buildAdaptiveButton({
      required VoidCallback onPressed,
      required IconData icon,
      required String label,
      Color? foregroundColor,
    }) {
      final color = foregroundColor ?? ClassicStyle.my_dark_green;

      if (ultraCompact) {
        return IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color),
          tooltip: label,
        );
      }

      if (compact) {
        return InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }

      return TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        label: Text(label),
      );
    }

    final List<Widget> buttons = [];

    buttons.add(
      buildAdaptiveButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icons.close,
        label: 'Zamknij',
      ),
    );

    if (widget.onChat != null) {
      buttons.add(
        buildAdaptiveButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onChat?.call();
          },
          icon: Icons.chat_bubble_outline,
          label: 'Czat',
        ),
      );
    }

    if (widget.ad.isOwner) {
      if (widget.onEdit != null) {
        buttons.add(
          buildAdaptiveButton(
            onPressed: widget.onEdit!,
            icon: Icons.edit,
            label: 'Edytuj',
          ),
        );
      }

      if (widget.onClose != null) {
        buttons.add(
          buildAdaptiveButton(
            onPressed: widget.onClose!,
            icon: Icons.visibility_off,
            label: 'Nieaktywne',
          ),
        );
      }

      if (widget.onDelete != null) {
        buttons.add(
          buildAdaptiveButton(
            onPressed: widget.onDelete!,
            icon: Icons.delete_outline,
            label: 'Usuń',
          ),
        );
      }
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        children: buttons,
      ),
    );
  }
}

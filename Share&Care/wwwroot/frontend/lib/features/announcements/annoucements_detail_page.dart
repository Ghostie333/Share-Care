import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/classic_style.dart';
import '../models/annoucement.dart';

class AnnouncementDetailsDialog extends StatefulWidget {
  final Announcement ad;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onChat;

  const AnnouncementDetailsDialog({
    super.key,
    required this.ad,
    this.onEdit,
    this.onDelete,
    this.onChat,
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
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
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
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ad.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ogłoszeniodawca: ${widget.ad.ownerName}',
                      style: const TextStyle(fontSize: 14),
                    ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Zamknij'),
                        ),
                        if (widget.onChat != null)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onChat?.call();
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Czat'),
                          ),
                        if (widget.ad.isOwner)
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: widget.onEdit,
                                icon: const Icon(Icons.edit),
                                label: const Text('Edytuj'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: widget.onDelete,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Usuń'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'announcement_metadata.dart';
import '../models/annoucement.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../profile/public_profile_page.dart';
import '../profile/profile_page.dart';

class AnnouncementDetailsDialog extends StatefulWidget {
  final Announcement ad;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onChat;
  final VoidCallback? onPayment;
  final VoidCallback? onClose; // oznaczenie ogłoszenia jako nieaktywne

  const AnnouncementDetailsDialog({
    super.key,
    required this.ad,
    this.onEdit,
    this.onDelete,
    this.onChat,
    this.onPayment,
    this.onClose,
  });

  @override
  State<AnnouncementDetailsDialog> createState() =>
      _AnnouncementDetailsDialogState();
}

class _AnnouncementDetailsDialogState extends State<AnnouncementDetailsDialog> {
  late final PageController _pageController;
  late int _currentIndex;
  Timer? _timer;

  List<String> get _images =>
      widget.ad.imageUrls.isEmpty ? ['placeholder'] : widget.ad.imageUrls;

  bool get _hasImages => widget.ad.imageUrls.isNotEmpty;
  int get _imageCount => _hasImages ? widget.ad.imageUrls.length : 1;

  String _resolveImageUrl(String idOrUrl) {
    final v = idOrUrl.trim();
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    return '${AppConfig.apiBaseUrl}/offer/image/$v';
  }

  Widget _imagePlaceholder(ThemeData theme) => Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
      child: Icon(
        Icons.image,
        size: 72,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _pageController = PageController();

    if (widget.ad.imageUrls.length > 1) {
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
    final theme = Theme.of(context);
    final String type = AnnouncementMetadata.parseType(widget.ad.category);
    final String category = AnnouncementMetadata.parseCategory(
      widget.ad.category,
    );

    final media = MediaQuery.of(context);
    final bool verySmallPhone = media.size.width < 380;
    final bool shortHeight = media.size.height < 700;

    return Dialog(
      insetPadding: EdgeInsets.all(verySmallPhone ? 8 : 16),
      child: SizedBox(
        width: media.size.width * (verySmallPhone ? 0.97 : 0.9),
        height: media.size.height * (shortHeight ? 0.86 : 0.72),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final bool useColumnLayout = maxWidth < 800;

              final imageSection = Expanded(
                flex: 3,
                child: _buildImagesSection(theme),
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

  Widget _buildImagesSection(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _imageCount,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (_, index) {
              if (!_hasImages) return _imagePlaceholder(theme);

              final url = _resolveImageUrl(widget.ad.imageUrls[index]);
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(theme),
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
            itemCount: _imageCount,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final isSelected = index == _currentIndex;

              return GestureDetector(
                onTap: !_hasImages
                    ? null
                    : () {
                        setState(() => _currentIndex = index);
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: !_hasImages
                      ? Icon(
                          Icons.image,
                          size: 32,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : Image.network(
                          _resolveImageUrl(widget.ad.imageUrls[index]),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image,
                            size: 32,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
    final theme = Theme.of(context);
    final bool compact = maxWidth < 420;

    TextStyle? labelStyle(TextStyle? base) =>
        base?.copyWith(fontWeight: FontWeight.w600);

    Widget infoLine(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: labelStyle(theme.textTheme.bodyLarge),
              ),
              TextSpan(text: value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.ad.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: compact ? 19 : 22,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 8),
          infoLine('Typ', type),
          if (category.isNotEmpty) infoLine('Kategoria', category),
          if (widget.ad.userId != null && widget.ad.userId!.isNotEmpty)
            InkWell(
              onTap: () async {
                Navigator.of(context).pop();

                final auth = await AuthService.getStoredAuthResult();
                final currentUserId = (auth?.userId ?? '').trim();
                final ownerId = widget.ad.userId!.trim();

                if (currentUserId.isNotEmpty && currentUserId == ownerId) {
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfileScreen(authResult: auth!),
                    ),
                  );
                  return;
                }

                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PublicProfilePage(userId: ownerId),
                  ),
                );
              },
              child: infoLine('Ogłoszeniodawca', widget.ad.ownerName),
            )
          else
            infoLine('Ogłoszeniodawca', widget.ad.ownerName),
          infoLine(
            'Rodzaj',
            widget.ad.offerKind == 'Give' ? 'Oddanie' : 'Wypożyczenie',
          ),
          if ((widget.ad.contactNumber ?? '').isNotEmpty)
            infoLine('Telefon', widget.ad.contactNumber ?? ''),
          if (widget.ad.offerKind == 'Borrow' && widget.ad.deposit != null)
            infoLine('Kaucja', '${widget.ad.deposit!.toStringAsFixed(2)} zł'),
          if (widget.ad.location.trim().isNotEmpty)
            infoLine('Lokalizacja', widget.ad.location),
          const SizedBox(height: 10),
          Text(
            'Opis',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.ad.description,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
          ),
          if (widget.ad.offerKind == 'Borrow' && widget.ad.deposit != null)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Kaucja: ${widget.ad.deposit!.toStringAsFixed(2)} zł',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          const SizedBox(height: 8),
          _buildActionsRow(
            maxWidth,
            isAnnouncement:
                type == AnnouncementMetadata.defaultAnnouncementType,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(double maxWidth, {required bool isAnnouncement}) {
    final bool ultraCompact = maxWidth < 420;
    final bool compact = maxWidth < 640;

    Widget buildAdaptiveButton({
      required VoidCallback onPressed,
      required IconData icon,
      required String label,
      Color? foregroundColor,
    }) {
      final color = foregroundColor ?? Theme.of(context).colorScheme.primary;

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
                Text(label, style: const TextStyle(fontSize: 11)),
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

    if (isAnnouncement &&
        !widget.ad.isOwner &&
        widget.onPayment != null &&
        widget.ad.offerKind == 'Borrow') {
      buttons.add(
        buildAdaptiveButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onPayment?.call();
          },
          icon: Icons.payment,
          label: widget.ad.offerKind == 'Give'
              ? 'Poproś o oddanie'
              : 'Wypożycz',
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
            icon: widget.ad.isActive ? Icons.visibility_off : Icons.visibility,
            label: widget.ad.isActive ? 'Nieaktywne' : 'Aktywne',
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

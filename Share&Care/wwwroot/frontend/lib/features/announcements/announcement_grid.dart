import 'package:flutter/material.dart';

import '../models/annoucement.dart';
import '../../config/app_config.dart';
import 'announcement_metadata.dart';

/// Lista / siatka ogłoszeń użytkownika.
class AnnouncementGrid extends StatelessWidget {
  final List<Announcement> announcements;
  final void Function(Announcement) onTap;

  const AnnouncementGrid({
    super.key,
    required this.announcements,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) {
      return Text(
        'Brak aktywnych ogłoszeń.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 420
          ? 1
          : width < 720
          ? 2
          : 3;
        final childAspectRatio = width < 420
          ? 1.45
          : width < 520
          ? 1.2
          : width < 720
          ? 1.0
          : 0.9;

        return GridView.builder(
          itemCount: announcements.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final ad = announcements[index];
            return _AnnouncementCard(ad: ad, onTap: () => onTap(ad));
          },
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement ad;
  final VoidCallback onTap;

  const _AnnouncementCard({required this.ad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPhone = MediaQuery.of(context).size.width < 400;
    final firstImageId = ad.imageUrls.isNotEmpty ? ad.imageUrls.first : null;
    final imageUrl = firstImageId == null ? null : _resolveImageUrl(firstImageId);

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final depositStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: isPhone ? 11 : null,
    );
    final typeLabel = AnnouncementMetadata.parseType(ad.category);

    return Card(
      color: theme.cardColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: imageUrl == null
                      ? Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.image,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: theme.colorScheme.surfaceVariant,
                              child: Icon(
                                Icons.image,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                ad.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text(ad.isActive ? 'Aktywne' : 'Zakończone'),
                            backgroundColor: ad.isActive
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceVariant,
                            labelStyle: theme.textTheme.labelMedium?.copyWith(
                              color: ad.isActive
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Chip(
                            label: Text(typeLabel),
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                            labelStyle: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (ad.offerKind == 'Borrow' && ad.deposit != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 2),
                        child: Text(
                          'Kaucja: ${ad.deposit!.toStringAsFixed(2)} zł',
                          style: depositStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
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

  String _resolveImageUrl(String idOrUrl) {
    final v = idOrUrl.trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    return '${AppConfig.apiBaseUrl}/offer/image/$v';
  }
}

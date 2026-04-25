import 'package:flutter/material.dart';

import '../../models/annoucement.dart';
import '../../../config/app_config.dart';

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
        final crossAxisCount = width < 520 ? 2 : 3;

        return GridView.builder(
          itemCount: announcements.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: width < 520 ? 0.82 : 0.9,
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
    final hasImages = ad.imageUrls.isNotEmpty;
    final firstImageId = hasImages ? ad.imageUrls.first : null;
    final imageUrl = firstImageId == null
        ? null
        : '${AppConfig.apiBaseUrl}/offer/image/$firstImageId';

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final depositStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );

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
              Expanded(
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Chip(
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
                    ),
                    if (ad.deposit != null)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          'Kaucja: ${ad.deposit!.toStringAsFixed(2)} zł',
                          style: depositStyle,
                          textAlign: TextAlign.right,
                        ),
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

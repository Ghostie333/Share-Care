import 'package:flutter/material.dart';

import '../../models/annoucement.dart';
import '../../../core/classic_style.dart';
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
			return const Text('Brak aktywnych ogłoszeń.');
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
						return _AnnouncementCard(
							ad: ad,
							onTap: () => onTap(ad),
						);
					},
				);
			},
		);
	}
}

class _AnnouncementCard extends StatelessWidget {
	final Announcement ad;
	final VoidCallback onTap;

	const _AnnouncementCard({
		required this.ad,
		required this.onTap,
	});

	@override
	Widget build(BuildContext context) {
		final hasImages = ad.imageUrls.isNotEmpty;
		final firstImageId = hasImages ? ad.imageUrls.first : null;
		final imageUrl = firstImageId == null
			? null
			: '${AppConfig.apiBaseUrl}/offer/image/$firstImageId';

		return Card(
			color: ClassicStyle.my_beige,
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
											color: Colors.grey[200],
											child: const Icon(Icons.image, color: Colors.black38),
										)
										: Image.network(
											imageUrl,
											fit: BoxFit.cover,
											errorBuilder: (_, __, ___) {
												return Container(
													color: Colors.grey[200],
													child: const Icon(Icons.image, color: Colors.black38),
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
								style: const TextStyle(
									fontWeight: FontWeight.bold,
								),
							),
							const SizedBox(height: 6),
							if (ad.deposit != null)
								Text(
									'Kaucja: ${ad.deposit!.toStringAsFixed(2)} zł',
									style: const TextStyle(fontSize: 12),
								),
							const SizedBox(height: 8),
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceBetween,
								children: [
									ad.isActive
										? const Chip(
											label: Text('Aktywne'),
											backgroundColor: Colors.greenAccent,
										)
										: const Chip(
											label: Text('Zakończone'),
											backgroundColor: Colors.grey,
										),
									IconButton(
										padding: EdgeInsets.zero,
										iconSize: 20,
										onPressed: onTap,
										icon: const Icon(Icons.chevron_right),
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


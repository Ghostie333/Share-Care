import 'package:flutter/material.dart';

import '../../models/annoucement.dart';
import '../../../core/classic_style.dart';

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

		return Column(
			children: announcements
					.map(
						(ad) => _AnnouncementCard(
							ad: ad,
							onTap: () => onTap(ad),
						),
					)
					.toList(),
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
		return Card(
			margin: const EdgeInsets.only(bottom: 12),
			color: ClassicStyle.my_beige,
			child: ListTile(
				title: Text(ad.title),
				subtitle: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(
							ad.description,
							maxLines: 2,
							overflow: TextOverflow.ellipsis,
						),
						const SizedBox(height: 4),
						Text(
							'Dodano: ${ad.createdAt.toLocal()}',
							style: const TextStyle(fontSize: 12, color: Colors.black54),
						),
					],
				),
				trailing: ad.isActive
						? const Chip(
								label: Text('Aktywne'),
								backgroundColor: Colors.greenAccent,
							)
						: const Chip(
								label: Text('Zakończone'),
								backgroundColor: Colors.grey,
							),
				onTap: onTap,
			),
		);
	}
}


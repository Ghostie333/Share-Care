import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/announcement_service.dart';
import '../../services/user_profile_service.dart';
import '../models/annoucement.dart';
import 'announcement_metadata.dart';
import 'report_form_sheet.dart';

/// Dolny sheet do tworzenia "zgłoszenia" (tu mapowane na Offer kategorię).
Future<void> showCreateReportSheet({
  required BuildContext context,
  required AuthResult authResult,
  required String initialCategory,
  required String initialType,
  required List<String> categories,
  required List<String> types,
  required Future<void> Function(Announcement created) onCreated,
}) async {
  final userId = authResult.userId;
  if (userId == null || userId.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brak identyfikatora użytkownika - nie można zapisać ogłoszenia.'),
        ),
      );
    }
    return;
  }

  final scaffoldMessenger = ScaffoldMessenger.of(context);
  UserProfileInfo profile;
  try {
    profile = await UserProfileService.fetchProfile(userId);
  } catch (e) {
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Nie udało się pobrać profilu: $e')),
    );
    return;
  }

  if (!context.mounted) return;

  final ownerName = '${profile.firstName} ${profile.lastName}'.trim();
  final phoneNumber = profile.phoneNumber;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return ReportFormSheet(
        existingAd: null,
        ownerName: ownerName,
        categories: categories,
        types: types,
        initialCategory: initialCategory,
        initialType: initialType,
        onSubmit: (title, description, location, deposit, images, category, type) async {
          try {
            final encodedCategory = AnnouncementMetadata.encode(type, category);

            final newAnnouncement = Announcement(
              id: '',
              userId: userId,
              title: title,
              description: description,
              location: location,
              deposit: deposit,
              ownerName: ownerName,
              isActive: true,
              createdAt: DateTime.now(),
              imageUrls: const [],
              isOwner: true,
              category: encodedCategory,
              contactName: ownerName,
              contactNumber: phoneNumber.isEmpty ? '' : phoneNumber,
            );

            final created = await AnnouncementService.createOffer(
              newAnnouncement,
              images: images,
            );

            await onCreated(created);
          } catch (e) {
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('Błąd zapisu: $e')),
            );
          }
        },
      );
    },
  );
}


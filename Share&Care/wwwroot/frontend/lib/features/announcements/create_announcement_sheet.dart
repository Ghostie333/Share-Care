import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/announcement_service.dart';
import '../../services/user_profile_service.dart';
import '../models/annoucement.dart';
import 'announcement_form_sheet.dart';

/// Otwiera dolny sheet z formularzem tworzenia ogłoszenia.
///
/// Funkcja sama tworzy ogłoszenie w backendzie po zatwierdzeniu formularza.
Future<void> showCreateAnnouncementSheet({
  required BuildContext context,
  required AuthResult authResult,
  required Future<void> Function(Announcement created) onCreated,
}) async {
  final userId = authResult.userId;
  if (userId == null || userId.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Brak identyfikatora użytkownika - nie można zapisać ogłoszenia.',
          ),
        ),
      );
    }
    return;
  }

  final scaffoldMessenger = ScaffoldMessenger.of(context);
  // Backend wymaga ContactName (Required). Login nie zwraca imienia i nazwiska,
  // więc musimy pobrać profil użytkownika przed otwarciem formularza.
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
    builder: (ctx) {
      return AnnouncementFormSheet(
        existingAd: null,
        ownerName: ownerName,
        onSubmit: (title, description, location, deposit, images) async {
          try {
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
              category: 'Ogłoszenie|Inne',
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
              SnackBar(content: Text('Błąd zapisu ogłoszenia: $e')),
            );
          }
        },
      );
    },
  );
}


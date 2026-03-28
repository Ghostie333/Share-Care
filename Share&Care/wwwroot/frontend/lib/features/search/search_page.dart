import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/animations.dart';
import '../announcements/announcement_metadata.dart';
import '../announcements/create_announcement_sheet.dart';
import '../chat/chat_page.dart';
import '../home/home_page.dart';
import '../home/widgets/profile_page.dart';
import '../navigation/app_bar.dart';

class SearchPage extends StatelessWidget {
  final AuthResult authResult;

  const SearchPage({super.key, required this.authResult});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Text(
          'Wyszukiwanie',
          style: theme.textTheme.headlineSmall,
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentTab: BottomNavTab.search,
        onHomeTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(HomePage(authResult: authResult)),
          );
        },
        onSearchTap: () {},
        onAddTap: () {
          showCreateAnnouncementSheet(
            context: context,
            authResult: authResult,
            initialCategory: AnnouncementMetadata.defaultCategory,
            initialType: AnnouncementMetadata.defaultAnnouncementType,
            categories: AnnouncementMetadata.categories,
            types: AnnouncementMetadata.types,
            onCreated: (_) async {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dodano ogłoszenie')),
              );
            },
          );
        },
        onMessagesTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(ChatPage(authResult: authResult)),
          );
        },
        onProfileTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(ProfileScreen(authResult: authResult)),
          );
        },
      ),
    );
  }
}


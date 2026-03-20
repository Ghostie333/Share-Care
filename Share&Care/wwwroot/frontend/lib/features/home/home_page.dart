import 'package:flutter/material.dart';

import '../announcements/annoucements_detail_page.dart';
import '../home/widgets/announcement_grid.dart';
import '../models/annoucement.dart';
import '../../core/classic_style.dart';
import '../../services/auth_service.dart';
import '../../services/announcement_service.dart';
import '../announcements/create_announcement_sheet.dart';
import '../../utils/animations.dart';
import '../chat/chat_page.dart';
import '../navigation/app_bar.dart';
import '../search/search_page.dart';
import 'widgets/profile_page.dart';
import '../announcements/create_report_sheet.dart';

enum HomeFeedMode { all, announcements, reports }

class HomePage extends StatefulWidget {
  final AuthResult authResult;

  const HomePage({super.key, required this.authResult});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Announcement> _allOffers = [];
  bool _isLoading = true;

  HomeFeedMode _mode = HomeFeedMode.all;
  String _searchQuery = '';
  String? _selectedCategory;

  static const List<String> _categories = [
    'Książki',
    'Elektronika',
    'Artykuły budowlane',
  ];

  static const List<String> _types = [
    'Ogłoszenie',
    'Zgłoszenie',
  ];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);
    try {
      final offers = await AnnouncementService.getActiveOffers(
        currentUserId: widget.authResult.userId,
      );
      if (!mounted) return;
      setState(() {
        _allOffers
          ..clear()
          ..addAll(offers);
      });
    } catch (_) {
      // Docelowo tu podłączysz snackbar; na razie nie blokujemy UI.
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    List<Announcement> filtered = _allOffers;

    String parseType(String? categoryEncoded) {
      final raw = (categoryEncoded ?? '').trim();
      if (raw.isEmpty) return 'Ogłoszenie';
      if (raw.contains('|')) return raw.split('|').first.trim();
      // kompatybilnosc dla starych danych
      return raw == 'Zgłoszenie' ? 'Zgłoszenie' : 'Ogłoszenie';
    }

    String parseCategory(String? categoryEncoded) {
      final raw = (categoryEncoded ?? '').trim();
      if (raw.isEmpty) return '';
      if (raw.contains('|')) return raw.split('|').skip(1).join('|').trim();
      return raw;
    }

    if (_mode == HomeFeedMode.announcements) {
      filtered = filtered.where((a) => parseType(a.category) == 'Ogłoszenie').toList();
    } else if (_mode == HomeFeedMode.reports) {
      filtered = filtered.where((a) => parseType(a.category) == 'Zgłoszenie').toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered
          .where((a) =>
              a.title.toLowerCase().contains(q) ||
              a.description.toLowerCase().contains(q))
          .toList();
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((a) => parseCategory(a.category) == _selectedCategory)
          .toList();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildSearchAndFilters(context),
            const SizedBox(height: 12),
            _buildFeedModeButtons(context),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: theme.cardColor,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 14,
                            spreadRadius: 2,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mode == HomeFeedMode.announcements
                                ? 'Aktywne ogloszenia'
                                : _mode == HomeFeedMode.reports
                                    ? 'Aktywne zgloszenia'
                                    : 'Aktywne ogloszenia / zgloszenia',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            AnnouncementGrid(
                              announcements: filtered,
                              onTap: (ad) {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) {
                                    return AnnouncementDetailsDialog(
                                      ad: ad,
                                      onEdit: null,
                                      onDelete: null,
                                      onChat: () {
                                        Navigator.of(ctx).pop();
                                        Navigator.of(context).push(
                                          createSlideFadeRoute(
                                            ChatPage(
                                              authResult: widget.authResult,
                                              initialListing: ad,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentTab: BottomNavTab.home,
        onHomeTap: () {},
        onSearchTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(SearchPage(authResult: widget.authResult)),
          );
        },
        onAddTap: () {
          if (_mode == HomeFeedMode.reports) {
            showCreateReportSheet(
              context: context,
              authResult: widget.authResult,
              initialCategory: _selectedCategory?.isNotEmpty == true
                  ? _selectedCategory!
                  : _categories.first,
              initialType: 'Zgłoszenie',
              categories: _categories,
              types: _types,
              onCreated: (_) async => _loadOffers(),
            );
          } else {
            showCreateAnnouncementSheet(
              context: context,
              authResult: widget.authResult,
              onCreated: (_) async => _loadOffers(),
            );
          }
        },
        onMessagesTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(ChatPage(authResult: widget.authResult)),
          );
        },
        onProfileTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(ProfileScreen(authResult: widget.authResult)),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Szukaj...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              filled: true,
            ),
            onChanged: (v) {
              setState(() => _searchQuery = v);
            },
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String?>(
          value: _selectedCategory,
          hint: const Text('Kategoria'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Wszystko'),
            ),
            ..._categories.map(
              (c) => DropdownMenuItem<String?>(
                value: c,
                child: Text(c),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _selectedCategory = v);
          },
        ),
      ],
    );
  }

  Widget _buildFeedModeButtons(BuildContext context) {
    final bool isAnnouncements = _mode == HomeFeedMode.announcements;
    final bool isReports = _mode == HomeFeedMode.reports;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isAnnouncements
                  ? ClassicStyle.my_light_green
                  : Theme.of(context).colorScheme.surfaceVariant,
              foregroundColor: isAnnouncements
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() => _mode = HomeFeedMode.announcements);
            },
            child: const Text('Ogłoszenia'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isReports
                  ? ClassicStyle.my_light_green
                  : Theme.of(context).colorScheme.surfaceVariant,
              foregroundColor: isReports
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() => _mode = HomeFeedMode.reports);
            },
            child: const Text('Zgłoszenia'),
          ),
        ),
      ],
    );
  }
}


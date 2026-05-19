import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/announcement_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/animations.dart';
import '../announcements/annoucements_detail_page.dart';
import '../announcements/announcement_grid.dart';
import '../auth/auth_login_page.dart';
import '../chat/chat_page.dart';
import '../models/annoucement.dart';
import '../payments/payment_authorization_page.dart';
import 'achievements_guide_page.dart';
import 'profile_trophies.dart';

class PublicProfilePage extends StatefulWidget {
  final String userId;

  const PublicProfilePage({super.key, required this.userId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool _loading = true;
  PublicProfileInfo? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await UserProfileService.fetchPublicProfile(widget.userId);
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać profilu: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile;
    final stats = ProfileAchievementStats(
      offersCreated: profile?.offersCount ?? 0,
      negotiationsCompleted: profile?.negotiationsCount ?? 0,
      giveOffersCreated: profile?.giveOffersCount ?? 0,
      firstDayPurchases: profile?.firstDayPurchasesCount ?? 0,
      priceDrops: profile?.loweredPriceChangesCount ?? 0,
      differentCities: profile?.differentCitiesCount ?? 0,
    );
    final achievements = buildAchievementProgress(stats);
    final unlockedAchievements = achievements.where((a) => a.unlocked).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil użytkownika')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Brak danych'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(theme, unlockedCount: unlockedAchievements.length),
                    const SizedBox(height: 16),
                    _buildStats(theme),
                    const SizedBox(height: 16),
                    _buildAchievements(theme, achievements, unlockedAchievements),
                    const SizedBox(height: 16),
                    _buildListingSection(
                      theme,
                      title: 'Ogłoszenia',
                      subtitleCount: _profile!.activeOffersCount,
                      announcements: _profile!.activeOffers,
                    ),
                    const SizedBox(height: 16),
                    _buildListingSection(
                      theme,
                      title: 'Zgłoszenia',
                      subtitleCount: _profile!.activeReportsCount,
                      announcements: _profile!.activeReports,
                    ),
                  ],
                ),
    );
  }

  Widget _buildListingSection(
    ThemeData theme, {
    required String title,
    required int subtitleCount,
    required List<Announcement> announcements,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$title ($subtitleCount aktywnych)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (announcements.isEmpty)
              Text(
                'Brak aktywnych ${title.toLowerCase()}.',
                style: theme.textTheme.bodyMedium,
              )
            else
              AnnouncementGrid(
                announcements: announcements,
                onTap: (ad) {
                  _openAdDetails(ad);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdDetails(Announcement ad) async {
    final stored = await AuthService.getStoredAuthResult();
    final currentUserId = stored?.userId;

    Announcement resolved = ad;
    if (ad.id.isNotEmpty) {
      var loaderShown = false;
      try {
        if (!mounted) return;
        _showLoadingDialog();
        loaderShown = true;
        resolved = await AnnouncementService.getOfferById(
          ad.id,
          currentUserId: currentUserId,
        );
      } catch (e) {
        if (mounted && loaderShown) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nie udało się pobrać ogłoszenia: $e')),
          );
        }
        return;
      } finally {
        if (mounted && loaderShown) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AnnouncementDetailsDialog(
          ad: resolved,
          onEdit: null,
          onDelete: null,
          onClose: null,
          onChat: () async {
            Navigator.of(ctx).pop();
            final loggedIn = await AuthService.isLoggedIn();
            if (!loggedIn) {
              if (!context.mounted) return;
              await Navigator.of(context).push(
                createSlideFadeRoute(
                  LoginScreen(
                    onLoginSuccess: (_) {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              );
              return;
            }

            final auth = await AuthService.getStoredAuthResult();
            if (auth == null) {
              if (!context.mounted) return;
              await Navigator.of(context).push(
                createSlideFadeRoute(
                  LoginScreen(
                    onLoginSuccess: (_) {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              );
              return;
            }

            if (!context.mounted) return;
            Navigator.of(context).push(
              createSlideFadeRoute(
                ChatPage(authResult: auth, initialListing: resolved),
              ),
            );
          },
          onPayment: () async {
            final auth = await AuthService.getStoredAuthResult();

            Navigator.of(context).push(
              createSlideFadeRoute(
                PaymentAuthorizationPage(
                  authResult: auth ??
                      AuthResult(
                        userId: null,
                        email: '',
                        firstName: '',
                        lastName: '',
                      ),
                  announcement: resolved,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildHeader(ThemeData theme, {required int unlockedCount}) {
    final profile = _profile!;
    final name = [
      if (profile.showFirstName) profile.firstName,
      if (profile.showLastName) profile.lastName,
    ].join(' ').trim();
    final showPhoto = profile.showProfileImage;

    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: theme.colorScheme.primary,
          foregroundImage: showPhoto
              ? NetworkImage(
                  '${AppConfig.apiBaseUrl}/UserProfile/photo/${profile.userId}',
                )
              : null,
          child: showPhoto
              ? null
              : Text(
                  name.isEmpty ? 'U' : name[0].toUpperCase(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          name.isEmpty ? 'Użytkownik' : name,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        if (profile.showCity && profile.city.isNotEmpty)
          Text(
            profile.city,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
        if (profile.showPhoneNumber && profile.phoneNumber.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              profile.phoneNumber,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(
              theme,
              Icons.star_outline,
              'Ocena ${profile.raiting.toStringAsFixed(2)}',
            ),
            _buildChip(
              theme,
              Icons.emoji_events_outlined,
              '$unlockedCount trofeów',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildStats(ThemeData theme) {
    final profile = _profile!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _statRow('Ranga', profile.rank),
            _statRow('Ogłoszenia', profile.offersCount.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievements(
    ThemeData theme,
    List<AchievementProgress> achievements,
    List<AchievementProgress> unlockedAchievements,
  ) {
    final lockedCount = achievements.length - unlockedAchievements.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trofea i osiągnięcia',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (unlockedAchievements.isEmpty)
              Text(
                'Brak zdobytych trofeów.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...unlockedAchievements.map(
                (achievement) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _achievementTile(theme, achievement),
                ),
              ),
            if (lockedCount > 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    final profile = _profile;
                    if (profile == null) return;
                    final stats = ProfileAchievementStats(
                      offersCreated: profile.offersCount,
                      negotiationsCompleted: profile.negotiationsCount,
                      giveOffersCreated: profile.giveOffersCount,
                      firstDayPurchases: profile.firstDayPurchasesCount,
                      priceDrops: profile.loweredPriceChangesCount,
                      differentCities: profile.differentCitiesCount,
                    );

                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AchievementsGuidePage(stats: stats),
                      ),
                    );
                  },
                  child: const Text('Jak zdobyć pozostałe?'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _achievementTile(ThemeData theme, AchievementProgress achievement) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              achievement.unlocked
                  ? Icons.emoji_events
                  : Icons.emoji_events_outlined,
              color:
                  achievement.unlocked ? Colors.amber : theme.iconTheme.color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.definition.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    achievement.definition.description,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${achievement.current}/${achievement.definition.threshold}'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: achievement.progress),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}

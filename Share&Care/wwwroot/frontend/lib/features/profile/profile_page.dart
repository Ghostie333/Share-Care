import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/announcement_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/payment_service.dart';
import '../../services/wallet_service.dart';
import '../../config/app_config.dart';
import '../../utils/animations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/edit_profile_page.dart';
import '../auth/change_password_page.dart';
import '../models/annoucement.dart';
import '../settings/settings_page.dart';
import '../announcements/annoucements_detail_page.dart';
import '../announcements/announcement_form_sheet.dart';
import '../announcements/announcement_metadata.dart';
import '../announcements/announcement_grid.dart';
import '../auth/auth_login_page.dart';
import '../chat/chat_page.dart';
import '../history/history_page.dart';
import '../navigation/app_bar.dart';
import 'profile_privacy_settings_page.dart';
import 'profile_trophies.dart';
import 'achievements_guide_page.dart';
import '../search/search_page.dart';
import '../rewards/rewards_page.dart';
import '../home/home_page.dart';
import '../payments/payment_authorization_page.dart';
import '../../widgets/ad_placeholder.dart';

class ProfileScreen extends StatefulWidget {
  final AuthResult authResult;

  const ProfileScreen({super.key, required this.authResult});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _firstName;
  late String _lastName;
  late String _email;
  late String _city;
  String _phoneNumber = '';
  String _raiting = '';
  String _type = '';
  double _walletBalance = 0;
  double _walletLocked = 0;
  int _credits = 0;
  int _offersCount = 0;
  int _negotiationsCount = 0;
  int _giveOffersCount = 0;
  int _firstDayPurchasesCount = 0;
  int _differentCitiesCount = 0;
  int _loweredPriceChangesCount = 0;

  final List<Announcement> _ads = [];
  bool _showActiveAds = true;
  bool _showActiveReports = true;

  String get _initials {
    final firstInitial = _firstName.isNotEmpty ? _firstName[0] : '';
    final lastInitial = _lastName.isNotEmpty ? _lastName[0] : '';
    final combined = (firstInitial + lastInitial).toUpperCase();
    return combined.isEmpty ? '?' : combined;
  }

  @override
  void initState() {
    super.initState();
    _firstName = widget.authResult.firstName;
    _lastName = widget.authResult.lastName;
    _email = widget.authResult.email;
    _city = '';
    _loadUserProfile();
    _loadUserAds();
  }

  Future<void> _loadUserProfile() async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final info = await UserProfileService.fetchProfile(userId);
      if (!mounted) return;
      setState(() {
        _firstName = info.firstName;
        _lastName = info.lastName;
        _email = info.email;
        _city = info.city;
        _phoneNumber = info.phoneNumber;
        _raiting = info.raiting;
        _type = info.type;
        _walletBalance = info.walletBalance;
        _walletLocked = info.walletLocked;
        _credits = info.credits;
        _offersCount = info.offersCount;
        _negotiationsCount = info.negotiationsCount;
        _giveOffersCount = info.giveOffersCount;
        _firstDayPurchasesCount = info.firstDayPurchasesCount;
        _differentCitiesCount = info.differentCitiesCount;
        _loweredPriceChangesCount = info.loweredPriceChangesCount;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać profilu: $e')),
      );
    }
  }

  // Ładowanie ogłoszenia
  Future<void> _loadUserAds() async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final offers = await AnnouncementService.getUserOffers(userId);
      if (!mounted) return;

      setState(() {
        _ads
          ..clear()
          ..addAll(offers);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać ogłoszeń: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Profil'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: Drawer(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edytuj dane'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _onEditProfilePressed();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Zmiana hasła'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _onChangePasswordPressed();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Ustawienia'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _onSettingsPressed();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Prywatność profilu'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _onPrivacySettingsPressed();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Wyloguj'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _onLogoutPressed();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildSectionCard(child: _buildProfileHeader()),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildUserInfoSection()),
            const SizedBox(height: 12),
            _buildQuickStatsChips(theme),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildWalletSection()),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildAchievementsSection()),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildAdSection()),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildOffersSection()),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildReportsSection()),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildOtherSectionsPlaceholder()),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Wersja: ${AppConfig.version}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentTab: BottomNavTab.profile,
        onHomeTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(HomePage(authResult: widget.authResult)),
          );
        },
        onSearchTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(SearchPage(authResult: widget.authResult)),
          );
        },
        onAddTap: () async {
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

          if (!context.mounted) return;
          await _onCreateAdPressed();
        },
        onMessagesTap: () async {
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

          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(ChatPage(authResult: widget.authResult)),
          );
        },
        onProfileTap: () {},
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: theme.colorScheme.primary,
          foregroundImage: widget.authResult.userId == null
              ? null
              : NetworkImage(
                  '${AppConfig.apiBaseUrl}/UserProfile/photo/${widget.authResult.userId}',
                ),
          child: Text(
            _initials,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$_firstName $_lastName',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_city.isNotEmpty)
              _buildInfoChip(label: _city, icon: Icons.location_on_outlined),
            if (_type.isNotEmpty)
              _buildInfoChip(label: _type, icon: Icons.verified_user_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStatsChips(ThemeData theme) {
    final stats = ProfileAchievementStats(
      offersCreated: _offersCount,
      negotiationsCompleted: _negotiationsCount,
      giveOffersCreated: _giveOffersCount,
      firstDayPurchases: _firstDayPurchasesCount,
      priceDrops: _loweredPriceChangesCount,
      differentCities: _differentCitiesCount,
    );
    final unlockedCount =
        buildAchievementProgress(stats).where((a) => a.unlocked).length;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_raiting.isNotEmpty)
          _buildInfoChip(label: 'Ocena $_raiting', icon: Icons.star_outline),
        _buildInfoChip(
          label: '$unlockedCount trofeów',
          icon: Icons.emoji_events_outlined,
        ),
        _buildInfoChip(
          label: '$_credits shareCoins',
          icon: Icons.credit_score_outlined,
        ),
      ],
    );
  }

  Widget _buildInfoChip({required String label, required IconData icon}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dane konta',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Divider(color: theme.dividerColor.withOpacity(0.8)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _infoRow('Imię', _firstName),
                  _infoRow('Nazwisko', _lastName),
                  _infoRow('Email', _email),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _infoRow('Miasto', _city.isEmpty ? '-' : _city),
                  _infoRow(
                    'Telefon',
                    _phoneNumber.isEmpty ? '-' : _phoneNumber,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletSection() {
    final theme = Theme.of(context);
    final formattedBalance = _walletBalance.toStringAsFixed(2);
    final formattedLocked = _walletLocked.toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Saldo',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Divider(color: theme.dividerColor.withOpacity(0.8)),
        const SizedBox(height: 10),
        _infoRow('Saldo', '$formattedBalance zł'),
        _infoRow('Zablokowane', '$formattedLocked zł'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showTopUpDialog,
                icon: const Icon(Icons.add_card),
                label: const Text('Doładuj'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showWithdrawDialog,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Wypłać'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersSection() {
    final offers = _ads.where((ad) => !_isReport(ad)).toList();
    final activeAds = offers.where((ad) => ad.isActive).toList();
    final inactiveAds = offers.where((ad) => !ad.isActive).toList();
    final count = _showActiveAds ? activeAds.length : inactiveAds.length;

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
            _showActiveAds
              ? 'Aktywne ogłoszenia ($count)'
              : 'Nieaktywne ogłoszenia ($count)',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _showActiveAds
                      ? theme.colorScheme.primary.withOpacity(0.18)
                      : Colors.transparent,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  if (!_showActiveAds) {
                    setState(() => _showActiveAds = true);
                  }
                },
                child: const Text('Aktywne'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: !_showActiveAds
                      ? theme.colorScheme.primary.withOpacity(0.18)
                      : Colors.transparent,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  if (_showActiveAds) {
                    setState(() => _showActiveAds = false);
                  }
                },
                child: const Text('Nieaktywne'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (count == 0)
          Text(
            _showActiveAds
                ? 'Brak aktywnych ogłoszeń.'
                : 'Brak nieaktywnych ogłoszeń.',
            style: theme.textTheme.bodyMedium,
          )
        else
          AnnouncementGrid(
            announcements: _showActiveAds ? activeAds : inactiveAds,
            onTap: _openAdDetails,
          ),
      ],
    );
  }

  Widget _buildReportsSection() {
    final reports = _ads.where(_isReport).toList();
    final activeReports = reports.where((ad) => ad.isActive).toList();
    final inactiveReports = reports.where((ad) => !ad.isActive).toList();
    final count = _showActiveReports
        ? activeReports.length
        : inactiveReports.length;

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _showActiveReports
              ? 'Aktywne zgłoszenia ($count)'
              : 'Nieaktywne zgłoszenia ($count)',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _showActiveReports
                      ? theme.colorScheme.primary.withOpacity(0.18)
                      : Colors.transparent,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  if (!_showActiveReports) {
                    setState(() => _showActiveReports = true);
                  }
                },
                child: const Text('Aktywne'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: !_showActiveReports
                      ? theme.colorScheme.primary.withOpacity(0.18)
                      : Colors.transparent,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  if (_showActiveReports) {
                    setState(() => _showActiveReports = false);
                  }
                },
                child: const Text('Nieaktywne'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (count == 0)
          Text(
            _showActiveReports
                ? 'Brak aktywnych zgłoszeń.'
                : 'Brak nieaktywnych zgłoszeń.',
            style: theme.textTheme.bodyMedium,
          )
        else
          AnnouncementGrid(
            announcements: _showActiveReports ? activeReports : inactiveReports,
            onTap: _openAdDetails,
          ),
      ],
    );
  }

  bool _isReport(Announcement ad) {
    return ad.offerKind == 'WantToTake' ||
        AnnouncementMetadata.parseType(ad.category) ==
            AnnouncementMetadata.defaultReportType;
  }

  Widget _buildOtherSectionsPlaceholder() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Inne',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Divider(color: theme.dividerColor.withOpacity(0.8)),
        const SizedBox(height: 6),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: const Text('Historia'),
          subtitle: const Text(
            'Wyszukiwania, ogłoszenia, czaty (w przygotowaniu)',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.of(context).push(
              createSlideFadeRoute(HistoryPage(authResult: widget.authResult)),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.emoji_events_outlined),
          title: const Text('Punkty / nagrody'),
          subtitle: const Text('Sprawdź dostępne nagrody'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.of(context).push(
              createSlideFadeRoute(const RewardsPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdSection() {
    return const AdPlaceholder(label: 'Reklama');
  }

  Widget _buildAchievementsSection() {
    final theme = Theme.of(context);
    final stats = ProfileAchievementStats(
      offersCreated: _offersCount,
      negotiationsCompleted: _negotiationsCount,
      giveOffersCreated: _giveOffersCount,
      firstDayPurchases: _firstDayPurchasesCount,
      priceDrops: _loweredPriceChangesCount,
      differentCities: _differentCitiesCount,
    );
    final achievements = buildAchievementProgress(stats);
    final unlocked = achievements.where((a) => a.unlocked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Trofea i osiągnięcia',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Divider(color: theme.dividerColor.withOpacity(0.8)),
        const SizedBox(height: 10),
        if (unlocked.isEmpty)
          Text(
            'Brak zdobytych trofeów.',
            style: theme.textTheme.bodyMedium,
          )
        else
          ...unlocked.map(
            (achievement) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _achievementTile(achievement),
            ),
          ),
        if (achievements.length != unlocked.length) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
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
    );
  }

  Widget _achievementTile(AchievementProgress achievement) {
    final theme = Theme.of(context);

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

  Future<void> _showTopUpDialog() async {
    await _showAmountDialog(
      title: 'Doładuj portfel',
      actionLabel: 'Przejdź do PayU',
      onSubmit: (amount) async {
        final redirectUrl = await PaymentService.createDepositRedirect(
          amount: amount,
        );
        await _openPaymentRedirect(redirectUrl);
      },
    );
  }

  Future<void> _showWithdrawDialog() async {
    await _showAmountDialog(
      title: 'Wypłata środków',
      actionLabel: 'Wypłać',
      onSubmit: (amount) async {
        await WalletService.withdraw(amount: amount);
        await _loadUserProfile();
      },
    );
  }

  Future<void> _showAmountDialog({
    required String title,
    required String actionLabel,
    required Future<void> Function(double amount) onSubmit,
  }) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Wpisz kwotę',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () async {
              final amount = _parseAmount(controller.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Podaj poprawną kwotę.')),
                );
                return;
              }

              Navigator.of(context).pop();
              try {
                await onSubmit(amount);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Nie udało się wykonać akcji: $e')),
                );
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  double? _parseAmount(String raw) {
    final normalized = raw.replaceAll(',', '.').trim();
    return double.tryParse(normalized);
  }

  Future<void> _openPaymentRedirect(String redirectUrl) async {
    final launched = await launchUrl(
      Uri.parse(redirectUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się otworzyć PayU.')),
      );
    }
  }

  Future<void> _onCreateAdPressed() async {
    await _openAdForm();
  }

  Future<void> _onEditProfilePressed() async {
    final result = await Navigator.of(context).push(
      createSlideFadeRoute(EditProfileScreen(authResult: widget.authResult)),
    );

    final updated = result is UserProfileInfo ? result : null;

    if (updated != null && mounted) {
      setState(() {
        _firstName = updated.firstName;
        _lastName = updated.lastName;
        _email = updated.email;
        _city = updated.city;
      });
    }
  }

  void _onSettingsPressed() {
    Navigator.of(
      context,
    ).push(createSlideFadeRoute(SettingsPage(authResult: widget.authResult)));
  }

  void _onPrivacySettingsPressed() {
    Navigator.of(context).push(
      createSlideFadeRoute(
        ProfilePrivacySettingsPage(authResult: widget.authResult),
      ),
    );
  }

  void _onLogoutPressed() {
    AuthService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      createSlideFadeRoute(const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _onChangePasswordPressed() async {
    await Navigator.of(context).push(
      createSlideFadeRoute(ChangePasswordScreen(authResult: widget.authResult)),
    );
  }

  Future<void> _openAdForm({Announcement? existingAd}) async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
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

    UserProfileInfo profile;
    try {
      profile = await UserProfileService.fetchProfile(userId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać profilu: $e')),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _firstName = profile.firstName;
      _lastName = profile.lastName;
      _email = profile.email;
      _city = profile.city;
      _phoneNumber = profile.phoneNumber;
      _raiting = profile.raiting;
      _type = profile.type;
    });

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
          existingAd: existingAd,
          ownerName: ownerName,
          categories: AnnouncementMetadata.categories,
          types: AnnouncementMetadata.types,
          offerKinds: AnnouncementMetadata.offerKinds,
          initialCategory: AnnouncementMetadata.defaultCategory,
          initialType: AnnouncementMetadata.defaultAnnouncementType,
          initialOfferKind: existingAd?.offerKind,
          initialCity: profile.city,
          initialPhoneNumber: phoneNumber,
          onSubmit:
              (
                title,
                description,
                location,
                deposit,
                images,
                category,
                type,
                offerKind,
                contactNumber,
                expirationDate,
              ) async {
                try {
                  if (existingAd == null) {
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
                      offerKind: offerKind,
                      category: encodedCategory,
                      contactName: ownerName,
                      contactNumber: contactNumber,
                      expiresAt: expirationDate,
                    );

                    final created = await AnnouncementService.createOffer(
                      newAnnouncement,
                      images: images,
                    );

                    if (!mounted) return;
                    setState(() {
                      _ads.add(created);
                    });
                  } else {
                    final encodedCategory = AnnouncementMetadata.encode(type, category);

                    existingAd
                      ..title = title
                      ..description = description
                      ..location = location
                      ..deposit = deposit
                      ..offerKind = offerKind
                      ..expiresAt = expirationDate
                      ..contactNumber = contactNumber
                      ..category = encodedCategory;

                    await AnnouncementService.updateOffer(existingAd);

                    if (!mounted) return;
                    setState(() {});
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd zapisu ogłoszenia: $e')),
                  );
                }
              },
        );
      },
    );
  }

  void _openAdDetails(Announcement ad) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AnnouncementDetailsDialog(
          ad: ad,
          onEdit: () {
            Navigator.of(ctx).pop();
            _openAdForm(existingAd: ad);
          },
          onClose: () async {
            final bool willActivate = !ad.isActive;
            final confirmed =
                await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Zmień aktywność ogłoszenia'),
                      content: Text(
                        willActivate
                            ? 'Czy na pewno chcesz ponownie aktywować to ogłoszenie?'
                            : 'Czy na pewno chcesz oznaczyć to ogłoszenie jako nieaktywne?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Nie'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Tak'),
                        ),
                      ],
                    );
                  },
                ) ??
                false;

            if (!confirmed) return;

            try {
              if (willActivate) {
                await AnnouncementService.activateOffer(ad.id);
              } else {
                await AnnouncementService.closeOffer(ad.id);
              }

              if (!mounted) return;
              setState(() {
                ad.isActive = willActivate;
                if (willActivate) {
                  _showActiveAds = true;
                }
              });
              Navigator.of(ctx).pop();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    willActivate
                        ? 'Błąd aktywacji ogłoszenia: $e'
                        : 'Błąd zamykania ogłoszenia: $e',
                  ),
                ),
              );
            }
          },
          onDelete: () async {
            final confirmed =
                await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Usuń ogłoszenie'),
                      content: const Text(
                        'Czy na pewno chcesz usunąć to ogłoszenie?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Nie'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Tak'),
                        ),
                      ],
                    );
                  },
                ) ??
                false;

            if (!confirmed) return;

            try {
              await AnnouncementService.deleteOffer(ad.id);
              if (!mounted) return;
              setState(() {
                _ads.removeWhere((a) => a.id == ad.id);
              });
              Navigator.of(ctx).pop();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Błąd usuwania ogłoszenia: $e')),
              );
            }
          },
          onChat: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push(
              createSlideFadeRoute(
                ChatPage(authResult: widget.authResult, initialListing: ad),
              ),
            );
          },
          onPayment: () {
            Navigator.of(context).push(
              createSlideFadeRoute(
                PaymentAuthorizationPage(
                  authResult: widget.authResult,
                  announcement: ad,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

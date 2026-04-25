import 'package:flutter/material.dart';

import '../../services/announcement_service.dart';
import '../../services/auth_service.dart';
import '../announcements/annoucements_detail_page.dart';
import '../models/annoucement.dart';

class AnnouncementHistoryPage extends StatefulWidget {
  final AuthResult authResult;

  const AnnouncementHistoryPage({super.key, required this.authResult});

  @override
  State<AnnouncementHistoryPage> createState() =>
      _AnnouncementHistoryPageState();
}

class _AnnouncementHistoryPageState extends State<AnnouncementHistoryPage> {
  bool _isLoading = true;
  List<Announcement> _inactiveAnnouncements = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) {
      setState(() {
        _inactiveAnnouncements = const [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final all = await AnnouncementService.getUserOffers(userId);
      if (!mounted) return;
      setState(() {
        _inactiveAnnouncements = all.where((a) => !a.isActive).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać historii ogłoszeń: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historia ogłoszeń')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inactiveAnnouncements.isEmpty
          ? const Center(child: Text('Brak nieaktywnych ogłoszeń.'))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _inactiveAnnouncements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final ad = _inactiveAnnouncements[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => AnnouncementDetailsDialog(ad: ad),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.7),
                        ),
                        color: Theme.of(context).cardColor,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ad.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ad.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ad.deposit != null
                                ? 'Kaucja: ${ad.deposit!.toStringAsFixed(2)} zł'
                                : 'Bez kaucji',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

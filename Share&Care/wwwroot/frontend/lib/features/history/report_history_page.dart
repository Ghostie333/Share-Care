import 'package:flutter/material.dart';

import '../../services/announcement_service.dart';
import '../../services/auth_service.dart';
import '../announcements/annoucements_detail_page.dart';
import '../announcements/announcement_metadata.dart';
import '../models/annoucement.dart';

class ReportHistoryPage extends StatefulWidget {
  final AuthResult authResult;

  const ReportHistoryPage({super.key, required this.authResult});

  @override
  State<ReportHistoryPage> createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
  bool _isLoading = true;
  List<Announcement> _inactiveReports = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) {
      setState(() {
        _inactiveReports = const [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final all = await AnnouncementService.getUserOffers(userId);
      if (!mounted) return;
      setState(() {
        _inactiveReports = all
            .where((a) => _isReport(a) && !a.isActive)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać historii zgłoszeń: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: 
        AppBar(
          title: const Text('Historia zgłoszeń'),
          flexibleSpace: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dziękuję że jesteś'),
                ),
              );
            },
            child: Image.asset(
              'images/logo/shareandcare_logo.png',
              height: 40,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inactiveReports.isEmpty
          ? const Center(child: Text('Brak nieaktywnych zgłoszeń.'))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _inactiveReports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final ad = _inactiveReports[index];
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
                          const Icon(Icons.report_gmailerrorred_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ad.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
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
                          if (ad.expiresAt != null)
                            Text(
                              _formatDate(ad.expiresAt!),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
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

  bool _isReport(Announcement ad) {
    return ad.offerKind == 'WantToTake' ||
        AnnouncementMetadata.parseType(ad.category) ==
            AnnouncementMetadata.defaultReportType;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

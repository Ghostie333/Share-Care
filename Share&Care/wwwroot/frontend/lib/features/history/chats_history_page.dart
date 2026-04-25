import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../chat/chat_page.dart';
import '../../utils/animations.dart';

class ChatsHistoryPage extends StatefulWidget {
  final AuthResult authResult;

  const ChatsHistoryPage({super.key, required this.authResult});

  @override
  State<ChatsHistoryPage> createState() => _ChatsHistoryPageState();
}

class _ChatsHistoryPageState extends State<ChatsHistoryPage> {
  bool _isLoading = true;
  List<ChatThreadSummary> _inactiveThreads = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final all = await ChatService.getMyChats();
      if (!mounted) return;
      setState(() {
        _inactiveThreads = all
            .where((t) => t.listingStatus.toLowerCase() != 'active')
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać historii czatów: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historia czatów')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inactiveThreads.isEmpty
          ? const Center(child: Text('Brak nieaktywnych czatów.'))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _inactiveThreads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final thread = _inactiveThreads[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        createSlideFadeRoute(
                          ChatPage(authResult: widget.authResult),
                        ),
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
                          const Icon(Icons.chat_bubble_outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  thread.otherUserName,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  thread.listingTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                thread.listingStatus,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (thread.lastMessageAt != null)
                                Text(
                                  '${thread.lastMessageAt!.day.toString().padLeft(2, '0')}.${thread.lastMessageAt!.month.toString().padLeft(2, '0')}.${thread.lastMessageAt!.year}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/classic_style.dart';
import '../../config/app_config.dart';
import '../../features/models/annoucement.dart';
import '../../services/auth_service.dart';
import '../../utils/animations.dart';
import '../announcements/announcement_metadata.dart';
import '../announcements/create_announcement_sheet.dart';
import '../auth/auth_login_page.dart';
// import '../auth/auth_registration_page.dart';
import '../home/home_page.dart';
import '../home/widgets/profile_page.dart';
import '../navigation/app_bar.dart';
import '../search/search_page.dart';
import '../announcements/annoucements_detail_page.dart';

class LocalChatAttachment {
  final String kind; // e.g. 'image'
  final String? fileName;
  final String? base64Data;

  LocalChatAttachment({
    required this.kind,
    this.fileName,
    this.base64Data,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'fileName': fileName,
        'base64Data': base64Data,
      };

  factory LocalChatAttachment.fromJson(Map<String, dynamic> json) {
    return LocalChatAttachment(
      kind: (json['kind'] ?? 'file').toString(),
      fileName: json['fileName']?.toString(),
      base64Data: json['base64Data']?.toString(),
    );
  }
}

class LocalChatMessage {
  final String id;
  final String senderId;
  final String content;
  final List<LocalChatAttachment> attachments;
  final DateTime sentAt;
  bool isRead;

  LocalChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.attachments,
    required this.sentAt,
    required this.isRead,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'content': content,
        'attachments': attachments.map((e) => e.toJson()).toList(),
        'sentAt': sentAt.toIso8601String(),
        'isRead': isRead,
      };

  factory LocalChatMessage.fromJson(Map<String, dynamic> json) {
    return LocalChatMessage(
      id: (json['id'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map((e) => LocalChatAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      sentAt: DateTime.tryParse((json['sentAt'] ?? '').toString()) ??
          DateTime.now(),
      isRead: (json['isRead'] ?? false) as bool,
    );
  }
}

class LocalChatThread {
  final String id;
  final String listingId;
  final String sellerId;
  final String buyerId;

  final String listingTitle;
  final double? listingDeposit;
  final String? listingFirstImageId;

  final String sellerName;
  final String buyerName;

  List<LocalChatMessage> messages;

  LocalChatThread({
    required this.id,
    required this.listingId,
    required this.sellerId,
    required this.buyerId,
    required this.listingTitle,
    required this.listingDeposit,
    required this.listingFirstImageId,
    required this.sellerName,
    required this.buyerName,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'listingId': listingId,
        'sellerId': sellerId,
        'buyerId': buyerId,
        'listingTitle': listingTitle,
        'listingDeposit': listingDeposit,
        'listingFirstImageId': listingFirstImageId,
        'sellerName': sellerName,
        'buyerName': buyerName,
        'messages': messages.map((e) => e.toJson()).toList(),
      };

  factory LocalChatThread.fromJson(Map<String, dynamic> json) {
    return LocalChatThread(
      id: (json['id'] ?? '').toString(),
      listingId: (json['listingId'] ?? '').toString(),
      sellerId: (json['sellerId'] ?? '').toString(),
      buyerId: (json['buyerId'] ?? '').toString(),
      listingTitle: (json['listingTitle'] ?? '').toString(),
      listingDeposit: (json['listingDeposit'] as num?)?.toDouble(),
      listingFirstImageId: json['listingFirstImageId']?.toString(),
      sellerName: (json['sellerName'] ?? '').toString(),
      buyerName: (json['buyerName'] ?? '').toString(),
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .map((e) => LocalChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatPage extends StatefulWidget {
  final AuthResult authResult;
  final Announcement? initialListing;

  const ChatPage({
    super.key,
    required this.authResult,
    this.initialListing,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _secureStorage = const FlutterSecureStorage();
  final _messageController = TextEditingController();

  static const String _threadsStoragePrefix = 'local_chat_threads_v1_';

  String? get _userId => widget.authResult.userId;
  String get _displayName => '${widget.authResult.firstName} ${widget.authResult.lastName}'.trim();

  List<LocalChatThread> _threads = [];
  String? _selectedThreadId;

  // Pending attachments (preview before send).
  final List<LocalChatAttachment> _pendingAttachments = [];
  // bool _isAuthOk = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!loggedIn) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        createSlideFadeRoute(const LoginScreen()),
        (_) => false,
      );
      return;
    }

    await _loadThreads();

    if (widget.initialListing != null && _userId != null) {
      await _openOrCreateThreadForListing(widget.initialListing!);
    } else if (_threads.isNotEmpty && _selectedThreadId == null) {
      _selectedThreadId = _threads.first.id;
    }
  }

  String _storageKey() => '$_threadsStoragePrefix${_userId ?? 'unknown'}';

  Future<void> _loadThreads() async {
    final raw = await _secureStorage.read(key: _storageKey());
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _threads = decoded
          .map((e) => LocalChatThread.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _threads = [];
    }
  }

  Future<void> _persistThreads() async {
    final raw = jsonEncode(_threads.map((e) => e.toJson()).toList());
    await _secureStorage.write(key: _storageKey(), value: raw);
  }

  LocalChatThread? get _selectedThread {
    if (_selectedThreadId == null) return null;
    return _threads.where((t) => t.id == _selectedThreadId).cast<LocalChatThread?>().firstOrNull;
  }

  LocalChatThread? _threadById(String id) =>
      _threads.where((t) => t.id == id).firstOrNull;

  Future<void> _openOrCreateThreadForListing(Announcement listing) async {
    final currentUserId = _userId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final sellerId = listing.userId ?? '';
    final listingFirstImageId =
        listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null;

    final existing = _threads.where((t) {
      return t.listingId == listing.id && t.buyerId == currentUserId;
    }).toList();

    if (existing.isNotEmpty) {
      _selectedThreadId = existing.first.id;
      _markThreadAsRead(existing.first.id);
      setState(() {});
      return;
    }

    final newThread = LocalChatThread(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      listingId: listing.id,
      sellerId: sellerId,
      buyerId: currentUserId,
      listingTitle: listing.title,
      listingDeposit: listing.deposit,
      listingFirstImageId: listingFirstImageId,
      sellerName: listing.ownerName,
      buyerName: _displayName,
      messages: [],
    );

    _threads.insert(0, newThread);
    _selectedThreadId = newThread.id;
    await _persistThreads();

    _markThreadAsRead(newThread.id);
    setState(() {});
  }

  Future<void> _markThreadAsRead(String threadId) async {
    final t = _threadById(threadId);
    if (t == null) return;

    bool changed = false;
    for (final m in t.messages) {
      if (m.senderId != _userId && !m.isRead) {
        m.isRead = true;
        changed = true;
      }
    }

    if (changed) {
      await _persistThreads();
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _removePendingAttachmentAt(int index) {
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  Future<LocalChatAttachment?> _pickSingleImageAttachment() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return null;

    final bytes = await xfile.readAsBytes();
    final base64Data = base64Encode(bytes);

    return LocalChatAttachment(
      kind: 'image',
      fileName: xfile.name,
      base64Data: base64Data,
    );
  }

  Future<void> _onSendPressed() async {
    final thread = _selectedThread;
    final currentUserId = _userId;
    if (thread == null || currentUserId == null || currentUserId.isEmpty) return;

    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final msg = LocalChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      senderId: currentUserId,
      content: text,
      attachments: List<LocalChatAttachment>.from(_pendingAttachments),
      sentAt: DateTime.now(),
      isRead: true, // w lokalnym trybie symulujemy odczyt po otwarciu czatu
    );

    thread.messages.add(msg);
    thread.messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

    _messageController.clear();
    _pendingAttachments.clear();

    await _persistThreads();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Wiadomości'),
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;

            // Narrow: grid tiles first, then conversation.
            if (isNarrow) {
              if (_selectedThread == null) {
                return _buildThreadTilesGrid();
              }
              return _buildConversation(thread: _selectedThread!, isNarrow: true);
            }

            // Wide: split view always.
            final selected = _selectedThread;
            return Row(
              children: [
                SizedBox(
                  width: 360,
                  child: _buildThreadTilesList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: selected == null
                      ? Center(
                          child: Text(
                            'Wybierz czat',
                            style: theme.textTheme.titleLarge,
                          ),
                        )
                      : _buildConversation(thread: selected, isNarrow: false),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentTab: BottomNavTab.messages,
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
          showCreateAnnouncementSheet(
            context: context,
            authResult: widget.authResult,
            initialCategory: AnnouncementMetadata.defaultCategory,
            initialType: AnnouncementMetadata.defaultAnnouncementType,
            categories: AnnouncementMetadata.categories,
            types: AnnouncementMetadata.types,
            onCreated: (_) async {},
          );
        },
        onMessagesTap: () {},
        onProfileTap: () async {
          final loggedIn = await AuthService.isLoggedIn();
          if (!loggedIn) {
            if (!context.mounted) return;
            await Navigator.of(context).push(
              createSlideFadeRoute(
                LoginScreen(
                  onLoginSuccess: (auth) {
                    Navigator.of(context).pushReplacement(
                      createSlideFadeRoute(ProfileScreen(authResult: auth)),
                    );
                  },
                ),
              ),
            );
            return;
          }

          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(ProfileScreen(authResult: widget.authResult)),
          );
        },
      ),
    );
  }

  Widget _buildThreadTilesGrid() {
    if (_threads.isEmpty) {
      return Center(
        child: Text(
          'Brak czatów. Otwórz czat z poziomu oferty.',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    final visibleThreads = _threads;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: visibleThreads.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (context, index) {
          final t = visibleThreads[index];
          final last = t.messages.isNotEmpty ? t.messages.last : null;

          return _ChatTile(
            title: t.listingTitle,
            subtitle: last == null ? '' : last.content,
            imageId: t.listingFirstImageId,
            isActive: last != null,
            onTap: () async {
              _selectedThreadId = t.id;
              await _markThreadAsRead(t.id);
              setState(() {});
            },
          );
        },
      ),
    );
  }

  Widget _buildThreadTilesList() {
    final visibleThreads = _threads;

    if (visibleThreads.isEmpty) {
      return Center(
        child: Text(
          'Brak czatów.',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: visibleThreads.length,
      itemBuilder: (context, index) {
        final t = visibleThreads[index];
        final last = t.messages.isNotEmpty ? t.messages.last : null;

        return _ChatTile(
          title: t.listingTitle,
          subtitle: last == null ? '' : last.content,
          imageId: t.listingFirstImageId,
          isActive: last != null,
          onTap: () async {
            _selectedThreadId = t.id;
            await _markThreadAsRead(t.id);
            setState(() {});
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  Widget _buildConversation({
    required LocalChatThread thread,
    required bool isNarrow,
  }) {
    final currentUserId = _userId ?? '';

    return Column(
      children: [
        if (isNarrow)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Wróć do listy',
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() => _selectedThreadId = null);
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${thread.sellerName} - ${thread.buyerName}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(thread.listingTitle),
              if (thread.listingDeposit != null)
                Text('Kaucja: ${thread.listingDeposit!.toStringAsFixed(2)} zł'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Brak pełnego modelu ogłoszenia tutaj,
                    // ale dialog może działać z placeholderem.
                    final ad = Announcement(
                      id: thread.listingId,
                      userId: thread.sellerId,
                      title: thread.listingTitle,
                      description: '',
                      location: '',
                      deposit: thread.listingDeposit,
                      ownerName: thread.sellerName,
                      isActive: true,
                      createdAt: DateTime.now(),
                      imageUrls: thread.listingFirstImageId == null
                          ? const []
                          : [thread.listingFirstImageId!],
                      isOwner: false,
                      category: null,
                      contactName: thread.sellerName,
                      contactNumber: '',
                    );
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AnnouncementDetailsDialog(
                        ad: ad,
                        onEdit: null,
                        onDelete: null,
                        onClose: null,
                      ),
                    );
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Otwórz ofertę'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: thread.messages.length,
            reverse: false,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final m = thread.messages[index];
              final isMine = m.senderId == currentUserId;
              return _MessageBubble(
                isMine: isMine,
                content: m.content,
                time: _formatTime(m.sentAt),
                isRead: m.isRead,
                attachments: m.attachments,
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Dodaj zdjęcie/plik',
                  icon: const Icon(Icons.attach_file),
                  onPressed: () async {
                    final att = await _pickSingleImageAttachment();
                    if (att == null) return;
                    setState(() => _pendingAttachments.add(att));
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Wpisz wiadomość...',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Wyślij',
                  icon: const Icon(Icons.send),
                  onPressed: _onSendPressed,
                  color: ClassicStyle.my_light_green,
                ),
              ],
            ),
          ),
        ),

        if (_pendingAttachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < _pendingAttachments.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _PendingAttachmentPreview(
                          att: _pendingAttachments[i],
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => _removePendingAttachmentAt(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageId;
  final bool isActive;
  final VoidCallback onTap;

  const _ChatTile({
    required this.title,
    required this.subtitle,
    required this.imageId,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ClassicStyle.my_beige,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 92,
                  width: double.infinity,
                  child: imageId == null
                      ? Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.black38),
                        )
                      : Image.network(
                          '${AppConfig.apiBaseUrl}/offer/image/$imageId',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, color: Colors.black38),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 8), 
              if (isActive)
                Row(
                  children: const [
                    Icon(Icons.circle, size: 10, color: Colors.greenAccent),
                    SizedBox(width: 6),
                    Text('Nowe', style: TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isMine;
  final String content;
  final String time;
  final bool isRead;
  final List<LocalChatAttachment> attachments;

  const _MessageBubble({
    required this.isMine,
    required this.content,
    required this.time,
    required this.isRead,
    required this.attachments,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? ClassicStyle.my_light_green : Colors.grey[200];
    final fg = isMine ? Colors.white : Colors.black87;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (attachments.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: attachments.map((att) {
                          if (att.base64Data == null) {
                            return const Icon(Icons.insert_drive_file);
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              base64Decode(att.base64Data!),
                              width: 140,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          );
                        }).toList(),
                      ),
                    if (content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          content,
                          style: TextStyle(color: fg),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                if (isMine) ...[
                  const SizedBox(width: 6),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 16,
                    color: isRead ? Colors.black54 : Colors.black54,
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingAttachmentPreview extends StatelessWidget {
  final LocalChatAttachment att;

  const _PendingAttachmentPreview({required this.att});

  @override
  Widget build(BuildContext context) {
    if (att.base64Data == null) {
      return const SizedBox(
        width: 90,
        height: 90,
        child: Icon(Icons.insert_drive_file),
      );
    }

    return SizedBox(
      width: 90,
      height: 90,
      child: Image.memory(
        base64Decode(att.base64Data!),
        fit: BoxFit.cover,
      ),
    );
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}



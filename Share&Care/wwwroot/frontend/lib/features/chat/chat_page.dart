import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../core/classic_style.dart';
import '../../config/app_config.dart';
import '../../features/models/annoucement.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/announcement_service.dart';
import '../../services/rental_service.dart';
import '../../services/ticket_service.dart';
import '../../utils/animations.dart';
import '../announcements/announcement_metadata.dart';
import '../announcements/create_announcement_sheet.dart';
import '../auth/auth_login_page.dart';
// import '../auth/auth_registration_page.dart';
import '../home/home_page.dart';
import '../profile/profile_page.dart';
import '../navigation/app_bar.dart';
import '../search/search_page.dart';
import '../announcements/annoucements_detail_page.dart';
import '../payments/payment_authorization_page.dart';

class LocalChatAttachment {
  final String kind; // e.g. 'image'
  final String? fileName;
  final String? base64Data;

  LocalChatAttachment({required this.kind, this.fileName, this.base64Data});

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

class ChatPage extends StatefulWidget {
  final AuthResult authResult;
  final Announcement? initialListing;

  const ChatPage({super.key, required this.authResult, this.initialListing});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();

  String? get _userId => widget.authResult.userId;
  // Nazwa do ewentualnego rozszerzenia w przyszłości – obecnie nieużywana.

  List<ChatThreadSummary> _threads = [];
  String? _selectedChatId;

  // Wiadomości w aktualnie wybranym czacie.
  List<ChatMessage> _messages = [];

  // Filtrowanie czatów po statusie ogłoszenia.
  // null = wszystkie, "Active" = tylko aktywne, "Inactive" = tylko nieaktywne.
  String? _statusFilter;

  // Prosty polling na czas otwartego czatu.
  // ignore: cancel_subscriptions
  Timer? _pollTimer;

  // Pending attachments (preview before send).
  final List<LocalChatAttachment> _pendingAttachments = [];
  // bool _isAuthOk = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Widget _buildThreadsPanel({required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
      ),
      child: child,
    );
  }

  Widget _buildStatusFilterRow() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActiveSelected = _statusFilter?.toLowerCase() == 'active';
    final isInactiveSelected = _statusFilter?.toLowerCase() == 'inactive';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: isActiveSelected
                      ? ClassicStyle.my_light_green.withOpacity(0.2)
                      : Colors.transparent,
                  foregroundColor: theme.textTheme.bodyMedium?.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _statusFilter = isActiveSelected ? null : 'Active';
                  });
                },
                child: const Text('Aktywne'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: isInactiveSelected
                      ? ClassicStyle.my_light_green.withOpacity(0.2)
                      : Colors.transparent,
                  foregroundColor: theme.textTheme.bodyMedium?.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _statusFilter = isInactiveSelected ? null : 'Inactive';
                  });
                },
                child: const Text('Nieaktywne'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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

    await _loadThreadsFromBackend();

    if (widget.initialListing != null && _userId != null) {
      await _openOrCreateThreadForListing(widget.initialListing!);
    } else if (_threads.isNotEmpty && _selectedChatId == null) {
      _selectedChatId = _threads.first.chatId;
      await _loadMessagesForSelected();
    }
  }

  ChatThreadSummary? get _selectedThread {
    if (_selectedChatId == null) return null;
    return _threads.firstWhereOrNull((t) => t.chatId == _selectedChatId);
  }

  Future<void> _loadThreadsFromBackend() async {
    try {
      final threads = await ChatService.getMyChats();
      if (!mounted) return;
      setState(() {
        _threads = threads;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać listy czatów: $e')),
      );
    }
  }

  Future<void> _openOrCreateThreadForListing(Announcement listing) async {
    final currentUserId = _userId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final sellerId = listing.userId ?? '';
    if (sellerId.isEmpty) return;

    try {
      final chatId = await ChatService.createChat(
        listingId: listing.id,
        sellerId: sellerId,
      );

      await _loadThreadsFromBackend();

      if (!mounted) return;
      setState(() {
        _selectedChatId = chatId;
      });

      await _loadMessagesForSelected();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się otworzyć czatu: $e')),
      );
    }
  }

  Future<void> _loadMessagesForSelected() async {
    final chatId = _selectedChatId;
    if (chatId == null || chatId.isEmpty) return;

    try {
      final msgs = await ChatService.getMessages(chatId);
      if (!mounted) return;
      setState(() {
        _messages = msgs..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      });

      _startPolling(chatId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać wiadomości: $e')),
      );
    }
  }

  Future<void> _openListingDetailsFromThread(ChatThreadSummary thread) async {
    try {
      final ad = await AnnouncementService.getOfferById(
        thread.listingId,
        currentUserId: _userId,
      );
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (ctx) => AnnouncementDetailsDialog(
          ad: ad,
          onEdit: null,
          onDelete: null,
          onClose: null,
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
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się otworzyć pełnej oferty: $e')),
      );
    }
  }

  void _startPolling(String chatId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      if (_selectedChatId != chatId) return;
      try {
        final msgs = await ChatService.getMessages(chatId);
        if (!mounted) return;
        setState(() {
          _messages = msgs..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        });
      } catch (_) {
        // ciche pomijanie błędów w pollingu
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String? _resolveGiverId() {
    for (final m in _messages) {
      final giverId = m.data?['giverId']?.toString();
      if (giverId != null && giverId.isNotEmpty) return giverId;
    }
    return null;
  }

  String? _resolveTakerId() {
    for (final m in _messages) {
      final takerId = m.data?['takerId']?.toString();
      if (takerId != null && takerId.isNotEmpty) return takerId;
    }
    return null;
  }

  bool _canSendMessage(ChatThreadSummary thread, String currentUserId) {
    final status = thread.listingStatus.toLowerCase();
    if (status == 'active') return true;
    if (status == 'inprogress') {
      return thread.currentBorrowerId != null &&
          thread.currentBorrowerId == currentUserId;
    }
    return false;
  }

  String _resolveReadOnlyReason(
    ChatThreadSummary thread,
    String currentUserId,
  ) {
    final status = thread.listingStatus.toLowerCase();
    if (status == 'inprogress') {
      if (thread.currentBorrowerId == currentUserId) {
        return 'Czat aktywny dla wypozyczajacego w trakcie realizacji.';
      }
      return 'Czat tylko do odczytu (w trakcie realizacji moze pisac tylko wypozyczajacy).';
    }
    return 'Czat tylko do odczytu (ogloszenie nieaktywne lub usuniete).';
  }

  Future<void> _showTicketDialog(ChatThreadSummary thread) async {
    final controller = TextEditingController();
    String reason = 'Nieprawidlowa ocena';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zglos sprawe do administracji'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: reason,
              decoration: const InputDecoration(
                labelText: 'Powod',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Nieprawidlowa ocena',
                  child: Text('Nieprawidlowa ocena'),
                ),
                DropdownMenuItem(
                  value: 'Nieprawidlowy stan',
                  child: Text('Nieprawidlowy stan rzeczy'),
                ),
                DropdownMenuItem(
                  value: 'Inne',
                  child: Text('Inne'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                reason = value;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Opis',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Wyslij'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      controller.dispose();
      return;
    }

    final description = controller.text.trim();
    if (description.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opis nie moze byc pusty.')),
        );
      }
      controller.dispose();
      return;
    }

    try {
      await TicketService.createTicket(
        reason: reason,
        description: description,
        listingId: thread.listingId,
        chatId: thread.chatId,
        targetUserId: thread.otherUserId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zgloszenie zostalo wyslane.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udalo sie wyslac: $e')),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showReturnDialog(String offerId) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;

    try {
      await RentalService.takerReturn(offerId: offerId, images: images);
      await _loadMessagesForSelected();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zgłosić zwrotu: $e')),
      );
    }
  }

  Future<void> _showGiverReviewDialog(String offerId) async {
    String condition = 'Ideal';
    final picker = ImagePicker();
    final images = <XFile>[];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Ocena stanu przedmiotu'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: condition,
                    decoration: const InputDecoration(
                      labelText: 'Stan',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Ideal', child: Text('Idealny')),
                      DropdownMenuItem(value: 'LightlyUsed', child: Text('Lekko zużyty')),
                      DropdownMenuItem(value: 'HeavilyUsed', child: Text('Mocno zużyty')),
                      DropdownMenuItem(value: 'Destroyed', child: Text('Zniszczony')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => condition = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await picker.pickMultiImage(
                        imageQuality: 80,
                      );
                      if (picked.isEmpty) return;
                      setState(() {
                        images
                          ..clear()
                          ..addAll(picked);
                      });
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text('Dodaj zdjęcia (${images.length})'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Anuluj'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await RentalService.giverReview(
                        offerId: offerId,
                        condition: condition,
                        images: images,
                      );
                      await _loadMessagesForSelected();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Nie udało się zakończyć: $e')),
                      );
                    }
                  },
                  child: const Text('Zatwierdź'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removePendingAttachmentAt(int index) {
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  Future<LocalChatAttachment?> _pickSingleImageAttachment() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
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
    final chatId = _selectedChatId;
    if (thread == null ||
        chatId == null ||
        chatId.isEmpty ||
        currentUserId == null ||
        currentUserId.isEmpty)
      return;

    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final attachmentsPayload = _pendingAttachments
        .map((att) => att.toJson())
        .toList(growable: false);
    final contentToSend = text.isNotEmpty
        ? text
        : (attachmentsPayload.isNotEmpty ? 'Zdjęcie' : '');
    final kind = attachmentsPayload.isNotEmpty ? 'image' : 'text';
    final data = attachmentsPayload.isNotEmpty
        ? <String, dynamic>{'attachments': attachmentsPayload}
        : null;

    try {
      final sent = await ChatService.sendMessage(
        chatId: chatId,
        content: contentToSend,
        kind: kind,
        data: data,
      );

      _messageController.clear();
      _pendingAttachments.clear();

      setState(() {
        _messages = List<ChatMessage>.from(_messages)..add(sent);
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

        // zaktualizuj podgląd ostatniej wiadomości w liście czatów
        final idx = _threads.indexWhere((t) => t.chatId == chatId);
        if (idx != -1) {
          final t = _threads[idx];
          _threads[idx] = ChatThreadSummary(
            chatId: t.chatId,
            listingId: t.listingId,
            listingTitle: t.listingTitle,
            listingStatus: t.listingStatus,
            currentBorrowerId: t.currentBorrowerId,
            otherUserId: t.otherUserId,
            otherUserName: t.otherUserName,
            lastMessage: sent.content,
            lastMessageAt: sent.sentAt,
            listingFirstImageId: t.listingFirstImageId,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wysłać wiadomości: $e')),
      );
    }
  }

  Future<void> _onDeleteCurrentChat() async {
    final chatId = _selectedChatId;
    if (chatId == null || chatId.isEmpty) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Usuń czat'),
              content: const Text('Czy na pewno chcesz usunąć czat?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Nie'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Tak'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      await ChatService.archiveChat(chatId);
      if (!mounted) return;
      setState(() {
        _threads.removeWhere((t) => t.chatId == chatId);
        _selectedChatId = null;
        _messages = [];
      });
      _pollTimer?.cancel();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Czat został usunięty.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Nie udało się usunąć czatu: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Wiadomości'),
        actions: [
          if (_selectedThread != null)
            IconButton(
              tooltip: 'Usuń czat',
              icon: const Icon(Icons.delete_outline),
              onPressed: _onDeleteCurrentChat,
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;

            // Narrow: grid tiles first, then conversation.
            if (isNarrow) {
              if (_selectedThread == null) {
                return Column(
                  children: [
                    _buildStatusFilterRow(),
                    Expanded(
                      child: _buildThreadsPanel(child: _buildThreadTilesGrid()),
                    ),
                  ],
                );
              }
              return _buildConversation(
                thread: _selectedThread!,
                isNarrow: true,
              );
            }

            // Wide: split view always.
            final selected = _selectedThread;
            return Row(
              children: [
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      _buildStatusFilterRow(),
                      Expanded(
                        child: _buildThreadsPanel(
                          child: _buildThreadTilesList(),
                        ),
                      ),
                    ],
                  ),
                ),
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
            initialOfferKind: AnnouncementMetadata.offerKinds.first,
            categories: AnnouncementMetadata.categories,
            types: AnnouncementMetadata.types,
            offerKinds: AnnouncementMetadata.offerKinds,
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
    final visibleThreads = _filteredThreads();

    if (visibleThreads.isEmpty) {
      return const SizedBox.expand();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: visibleThreads.length,
      itemBuilder: (context, index) {
        final t = visibleThreads[index];

        return _ChatTile(
          title: t.listingTitle,
          subtitle: t.lastMessage ?? '',
          imageId: t.listingFirstImageId,
          listingStatus: t.listingStatus,
          onTap: () async {
            setState(() {
              _selectedChatId = t.chatId;
            });
            await _loadMessagesForSelected();
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  List<ChatThreadSummary> _filteredThreads() {
    if (_statusFilter == null) return _threads;
    final f = _statusFilter!.toLowerCase();
    return _threads.where((t) => t.listingStatus.toLowerCase() == f).toList();
  }

  Widget _buildThreadTilesList() {
    final visibleThreads = _filteredThreads();

    if (visibleThreads.isEmpty) {
      return const SizedBox.expand();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: visibleThreads.length,
      itemBuilder: (context, index) {
        final t = visibleThreads[index];

        return _ChatTile(
          title: t.listingTitle,
          subtitle: t.lastMessage ?? '',
          imageId: t.listingFirstImageId,
          listingStatus: t.listingStatus,
          onTap: () async {
            setState(() {
              _selectedChatId = t.chatId;
            });
            await _loadMessagesForSelected();
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  Widget _buildConversation({
    required ChatThreadSummary thread,
    required bool isNarrow,
  }) {
    final currentUserId = _userId ?? '';
    final canSend = _canSendMessage(thread, currentUserId);
    final readOnlyReason = _resolveReadOnlyReason(thread, currentUserId);

    return Column(
      children: [
        if (isNarrow)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Wróć do listy',
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _selectedChatId = null;
                  _messages = [];
                  _pollTimer?.cancel();
                });
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      thread.otherUserName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showTicketDialog(thread),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Zglos sprawe'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(thread.listingTitle),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _openListingDetailsFromThread(thread),
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
            itemCount: _messages.length,
            reverse: false,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final m = _messages[index];
              final isMine = m.senderId == currentUserId;
              final giverId = _resolveGiverId();
              final takerId = _resolveTakerId();
              final isGiver = giverId != null && giverId == currentUserId;
              final isTaker = takerId != null && takerId == currentUserId;
              final offerId = m.data?['offerId']?.toString() ?? thread.listingId;

              if (m.kind == 'rental_request' && isGiver) {
                return Card(
                  child: ListTile(
                    title: const Text('Nowa prośba o wypożyczenie'),
                    subtitle: Text(m.content),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () async {
                            try {
                              await RentalService.approveRental(offerId);
                              await _loadMessagesForSelected();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Nie udało się zaakceptować: $e')),
                              );
                            }
                          },
                          child: const Text('Akceptuj'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await RentalService.declineRental(offerId);
                              await _loadMessagesForSelected();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Nie udało się odrzucić: $e')),
                              );
                            }
                          },
                          child: const Text('Odrzuć'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (m.kind == 'rental_returned' && isGiver) {
                return Card(
                  child: ListTile(
                    title: const Text('Zwrot zgłoszony przez takera'),
                    subtitle: Text(m.content),
                    trailing: TextButton(
                      onPressed: () => _showGiverReviewDialog(offerId),
                      child: const Text('Oceń stan'),
                    ),
                  ),
                );
              }

              if (m.kind == 'rental_approved' && isTaker) {
                return Card(
                  child: ListTile(
                    title: const Text('Wypożyczenie aktywne'),
                    subtitle: Text(m.content),
                    trailing: TextButton(
                      onPressed: () => _showReturnDialog(offerId),
                      child: const Text('Zgłoś zwrot'),
                    ),
                  ),
                );
              }

              return _MessageBubble(
                isMine: isMine,
                content: m.content,
                time: _formatTime(m.sentAt),
                isRead: m.isRead,
                attachments: _attachmentsFromMessage(m),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: !canSend
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      readOnlyReason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Row(
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

  List<LocalChatAttachment> _attachmentsFromMessage(ChatMessage message) {
    final raw = message.data?['attachments'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => LocalChatAttachment.fromJson(
          Map<String, dynamic>.from(item),
        ))
        .toList(growable: false);
  }
}

class _ChatTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageId;
  final String listingStatus;
  final VoidCallback onTap;

  const _ChatTile({
    required this.title,
    required this.subtitle,
    required this.imageId,
    required this.listingStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
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
                          color: theme.colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.image,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Image.network(
                          '${AppConfig.apiBaseUrl}/offer/image/$imageId',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: theme.colorScheme.surfaceVariant,
                              child: Icon(
                                Icons.image,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(children: [_buildStatusChip(context, listingStatus)]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final labelColor = Theme.of(context).colorScheme.onSurface;
    final lower = status.toLowerCase();
    Color color;
    String label;

    if (lower == 'active') {
      color = Colors.greenAccent;
      label = 'Aktywne ogłoszenie';
    } else if (lower == 'inactive') {
      color = Colors.orangeAccent;
      label = 'Nieaktywne ogłoszenie';
    } else {
      color = Colors.redAccent;
      label = 'Usunięte ogłoszenie';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
        ],
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
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
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
                          final bytes = base64Decode(att.base64Data!);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: GestureDetector(
                              onTap: () => _openAttachmentPreview(context, bytes),
                              child: Image.memory(
                                bytes,
                                width: 140,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    if (content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(content, style: TextStyle(color: fg)),
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
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAttachmentPreview(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                color: Colors.white,
                tooltip: 'Zamknij',
              ),
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
      child: Image.memory(base64Decode(att.base64Data!), fit: BoxFit.cover),
    );
  }
}

extension _FirstWhereOrNullExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

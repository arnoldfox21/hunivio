import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/kost_group.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';
import '../widgets/animated_vectors.dart';
import 'kost_chat_screen.dart';
import 'kost_group_chat_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  List<ChatMessage> _conversations = [];
  List<KostGroupRoom> _groupRooms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    NotificationService.inboxEventCounter.addListener(_onInboxEvent);
    AuthService.currentUserNotifier.addListener(_onInboxEvent);
    _loadInbox();
  }

  @override
  void dispose() {
    NotificationService.inboxEventCounter.removeListener(_onInboxEvent);
    AuthService.currentUserNotifier.removeListener(_onInboxEvent);
    super.dispose();
  }

  void _onInboxEvent() {
    if (mounted) _loadInbox();
  }

  Future<void> _loadInbox() async {
    final user = AuthService.currentUser;
    if (user == null) {
      setState(() {
        _conversations = [];
        _groupRooms = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    if (_conversations.isEmpty && _groupRooms.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        ApiService.fetchChatConversations(user.id),
        ApiService.fetchGroupRoomsForUser(user.id),
      ]);
      final convs = results[0] as List<ChatMessage>;
      final groups = results[1] as List<KostGroupRoom>;
      if (!mounted) return;
      setState(() {
        _conversations = convs;
        _groupRooms = groups;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Kotak Pesan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEF2F6)),
        ),
      ),
      body: user == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Masuk untuk melihat riwayat obrolan Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                )
              : (_error != null && _conversations.isEmpty && _groupRooms.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_clock_outlined,
                              size: 52,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _loadInbox,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Muat Ulang'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : (_conversations.isEmpty && _groupRooms.isEmpty)
                  ? const AnimatedVectorEmptyState(
                      icon: Icons.mark_chat_unread_rounded,
                      title: 'Belum ada percakapan',
                      subtitle:
                          'Klik tombol "Tanya" di halaman detail properti untuk mulai chat dengan pemilik.',
                    )
                  : RefreshIndicator(
                      color: AppColors.primaryGreen,
                      onRefresh: _loadInbox,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_groupRooms.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.groups_rounded,
                                      size: 18, color: AppColors.primaryGreen),
                                  SizedBox(width: 6),
                                  Text(
                                    'Grup Penghuni Kost',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._groupRooms.map(
                              (g) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => KostGroupChatScreen(
                                          kostId: g.kostId,
                                          kostName: g.kostName,
                                          kostImage: g.kostImage,
                                        ),
                                      ),
                                    );
                                    _loadInbox();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppColors.primaryGreen
                                              .withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: AppColors.lightGreenBg,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.groups_rounded,
                                            color: AppColors.primaryGreen,
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      g.kostName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .lightGreenBg,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      g.isAdmin
                                                          ? 'Admin • ${g.memberCount}'
                                                          : '${g.memberCount} Penghuni',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            AppColors.darkGreen,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                g.lastSenderName.isNotEmpty
                                                    ? '${g.lastSenderName}: ${g.lastMessage}'
                                                    : g.lastMessage,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded,
                                            color: AppColors.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_conversations.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 6, bottom: 10),
                                child: Text(
                                  'Chat Pribadi',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                          ],
                          ..._conversations.map((msg) {
                            final kost = msg.kost;
                            if (kost == null) return const SizedBox.shrink();
                            final thumb =
                                kost.images.isNotEmpty ? kost.images.first : '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final candidatePeer =
                                      msg.senderId == user.id
                                          ? msg.receiverId
                                          : msg.senderId;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => KostChatScreen(
                                        kost: kost,
                                        peerUserId: candidatePeer != user.id
                                            ? candidatePeer
                                            : null,
                                      ),
                                    ),
                                  );
                                  _loadInbox();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border:
                                        Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          thumb,
                                          width: 54,
                                          height: 54,
                                          fit: BoxFit.cover,
                                          cacheWidth: 160,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 54,
                                            height: 54,
                                            color: const Color(0xFFF1F5F9),
                                            child:
                                                const Icon(Icons.bed_rounded),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              kost.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                if (msg.senderId ==
                                                    user.id) ...[
                                                  Icon(
                                                    msg.status == 'SENT'
                                                        ? Icons.done_rounded
                                                        : Icons.done_all_rounded,
                                                    size: 15,
                                                    color: msg.status == 'READ'
                                                        ? AppColors.primaryGreen
                                                        : const Color(
                                                            0xFF9CA3AF),
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    '${msg.senderName}: ${msg.message}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          msg.unreadCount > 0
                                                              ? FontWeight.w700
                                                              : FontWeight.w400,
                                                      color: msg.unreadCount > 0
                                                          ? AppColors.textPrimary
                                                          : AppColors
                                                              .textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (msg.unreadCount > 0) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryGreen,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${msg.unreadCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}

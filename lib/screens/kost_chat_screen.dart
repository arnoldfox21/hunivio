import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/chat_message.dart';
import '../models/kost.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';

class KostChatScreen extends StatefulWidget {
  final Kost kost;
  final int? peerUserId;

  const KostChatScreen({
    super.key,
    required this.kost,
    this.peerUserId,
  });

  @override
  State<KostChatScreen> createState() => _KostChatScreenState();
}

class _KostChatScreenState extends State<KostChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _showEmojiPicker = false;
  int _emojiCategoryIndex = 0;
  io.Socket? _socket;
  bool _socketConnected = false;

  static const List<Map<String, dynamic>> _emojiCategories = [
    {
      'icon': '😊',
      'label': 'Ekspresi',
      'emojis': [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
        '😊', '😇', '🙂', '😉', '😌', '😍', '🥰', '😘',
        '😋', '😎', '🤩', '🥳', '🤔', '🤨', '😐', '🙄',
        '🙏', '🤝', '👍', '👎', '👏', '🙌', '✌️', '👌',
      ],
    },
    {
      'icon': '🏠',
      'label': 'Kost & Lokasi',
      'emojis': [
        '🏠', '🏡', '🏢', '🛏️', '🛋️', '🚿', '🛁', '🚽',
        '🔑', '🗝️', '🚪', '🪟', '❄️', '📶', '⚡', '💡',
        '📍', '🗺️', '🛵', '🚗', '🅿️', '🔒', '📹', '🧹',
        '🍳', '🧊', '🧺', '🪴', '🌳', '☀️', '🌙', '⭐',
      ],
    },
    {
      'icon': '💬',
      'label': 'Simbol',
      'emojis': [
        '❤️', '💚', '💙', '💛', '🧡', '💜', '✨', '🔥',
        '💯', '✅', '❌', '❓', '❗', '💰', '💵', '💳',
        '📅', '🕒', '📞', '📱', '💬', '📩', '🎉', '🎊',
      ],
    },
  ];

  static const List<String> _tenantQuickReplies = [
    'Halo, apakah kamar masih tersedia? 🏠',
    'Boleh survei lokasi hari ini? 📍',
    'Apakah listrik sudah termasuk? ⚡',
    'Ada diskon untuk sewa 6 bulan? 💰',
  ];

  static const List<String> _ownerQuickReplies = [
    'Halo, kamar masih tersedia ya! 😊',
    'Silakan datang survei lokasi, kabari jamnya ya 📍',
    'Boleh kak, rencana mulai sewa kapan? 🗓️',
    'Harga sudah termasuk WiFi & fasilitas kamar 👍',
  ];

  List<String> get _quickReplies =>
      _senderId == widget.kost.ownerId
          ? _ownerQuickReplies
          : _tenantQuickReplies;

  int get _senderId => AuthService.currentUser?.id ?? 0;
  String get _senderName => AuthService.currentUser?.name ?? 'Tamu HuniVio';
  String get _senderAvatar => AuthService.currentUser?.avatarUrl ?? '';

  int get _resolvedReceiverId {
    if (widget.peerUserId != null &&
        widget.peerUserId! > 0 &&
        widget.peerUserId != _senderId) {
      return widget.peerUserId!;
    }
    if (_senderId != widget.kost.ownerId) {
      return widget.kost.ownerId;
    }
    for (final m in _messages.reversed) {
      if (m.senderId > 0 && m.senderId != _senderId) return m.senderId;
      if (m.receiverId > 0 && m.receiverId != _senderId) return m.receiverId;
    }
    return widget.kost.ownerId;
  }

  @override
  void initState() {
    super.initState();
    NotificationService.activeChatKostId = widget.kost.id;
    _loadMessages();
    _initSocket();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
  }

  void _initSocket() {
    try {
      final socket = io.io(
        ApiService.socketBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );
      socket.onConnect((_) {
        if (!mounted) return;
        setState(() => _socketConnected = true);
        socket.emit('joinKostChat', {
          'kostId': widget.kost.id,
          if (_senderId > 0) 'userId': _senderId,
        });
      });
      socket.onDisconnect((_) {
        if (mounted) setState(() => _socketConnected = false);
      });
      socket.on('newMessage', (data) {
        if (!mounted || data == null) return;
        final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data as Map));
        if (msg.kostId == widget.kost.id) {
          if (!_messages.any((m) => m.id == msg.id)) {
            setState(() => _messages.add(msg));
            _scrollToBottom();
          }
          if (msg.senderId != _senderId && _senderId > 0) {
            socket.emit('markAsRead', {
              'kostId': widget.kost.id,
              'readerId': _senderId,
            });
            NotificationService.refreshUnreadCount();
          }
        }
      });
      socket.on('messageStatusUpdated', (data) {
        if (!mounted || data == null) return;
        final map = Map<String, dynamic>.from(data as Map);
        final kostId = int.tryParse('${map['kostId']}') ?? 0;
        final newStatus = map['status']?.toString().toUpperCase() ?? '';
        final rawIds = map['messageIds'] as List<dynamic>? ?? const [];
        final ids = rawIds
            .map((e) => int.tryParse('$e') ?? 0)
            .where((id) => id > 0)
            .toSet();
        if (kostId != widget.kost.id || newStatus.isEmpty || ids.isEmpty) {
          return;
        }
        setState(() {
          _messages = _messages.map((m) {
            if (ids.contains(m.id)) {
              return m.copyWith(status: newStatus);
            }
            return m;
          }).toList();
        });
      });
      socket.connect();
      _socket = socket;
    } catch (_) {}
  }

  @override
  void dispose() {
    if (NotificationService.activeChatKostId == widget.kost.id) {
      NotificationService.activeChatKostId = null;
    }
    _socket?.emit('leaveKostChat', {'kostId': widget.kost.id});
    _socket?.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_senderId <= 0) {
      setState(() {
        _messages = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await ApiService.fetchChatMessages(
        kostId: widget.kost.id,
        userId: _senderId,
      );
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _scrollToBottom();
      if (_senderId > 0) {
        ApiService.markChatAsRead(
          kostId: widget.kost.id,
          readerId: _senderId,
        );
        _socket?.emit('markAsRead', {
          'kostId': widget.kost.id,
          'readerId': _senderId,
        });
        NotificationService.refreshUnreadCount();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _insertEmoji(String emoji) {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final updated = text.replaceRange(start, end, emoji);
    _msgCtrl.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _msgCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    if (preset == null) {
      _msgCtrl.clear();
    }
    setState(() => _sending = true);

    try {
      final receiverId = _resolvedReceiverId;
      if (_socketConnected && _socket != null) {
        _socket!.emit('sendMessage', {
          'kostId': widget.kost.id,
          'senderId': _senderId,
          'senderName': _senderName,
          'senderAvatar': _senderAvatar,
          'receiverId': receiverId,
          'message': text,
        });
        if (mounted) setState(() => _sending = false);
      } else {
        final sent = await ApiService.sendChatMessage(
          kostId: widget.kost.id,
          senderId: _senderId,
          senderName: _senderName,
          senderAvatar: _senderAvatar,
          receiverId: receiverId,
          message: text,
        );
        if (!mounted) return;
        setState(() {
          if (!_messages.any((m) => m.id == sent.id)) {
            _messages.add(sent);
          }
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal mengirim pesan: $e'),
        ),
      );
    }
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final thumb =
        widget.kost.images.isNotEmpty ? widget.kost.images.first : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        titleSpacing: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEF2F6)),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.lightGreenBg,
              child: Text(
                widget.kost.ownerName.isNotEmpty
                    ? widget.kost.ownerName[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.kost.ownerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Pemilik • ${widget.kost.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang chat',
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pinned Kost Summary Banner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    thumb,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.bed_rounded, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.kost.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatRupiah(widget.kost.pricePerMonth)}/bln • ${widget.kost.district}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Messages List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: AppColors.lightGreenBg,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 36,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Mulai obrolan dengan ${widget.kost.ownerName}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tanyakan ketersediaan kamar, fasilitas, atau jadwal survei lokasi.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == _senderId;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.76,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFFE7F8EE)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                border: Border.all(
                                  color: isMe
                                      ? AppColors.primaryGreen.withOpacity(0.25)
                                      : AppColors.cardBorder,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.message,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.35,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTime(msg.createdAt),
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          msg.status == 'SENT'
                                              ? Icons.done_rounded
                                              : Icons.done_all_rounded,
                                          size: 15,
                                          color: msg.status == 'READ'
                                              ? AppColors.primaryGreen
                                              : const Color(0xFF9CA3AF),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Quick Reply Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickReplies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final text = _quickReplies[idx];
                  return ActionChip(
                    label: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    backgroundColor: AppColors.lightGreenBg,
                    side: BorderSide(
                      color: AppColors.primaryGreen.withOpacity(0.25),
                    ),
                    shape: const StadiumBorder(),
                    onPressed: () => _sendMessage(text),
                  );
                },
              ),
            ),
          ),

          // Input Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: SafeArea(
              top: false,
              bottom: !_showEmojiPicker,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Pilih Emoji',
                    onPressed: () {
                      if (_showEmojiPicker) {
                        setState(() => _showEmojiPicker = false);
                        _focusNode.requestFocus();
                      } else {
                        _focusNode.unfocus();
                        setState(() => _showEmojiPicker = true);
                      }
                    },
                    icon: Icon(
                      _showEmojiPicker
                          ? Icons.keyboard_rounded
                          : Icons.emoji_emotions_outlined,
                      color: _showEmojiPicker
                          ? AppColors.primaryGreen
                          : Colors.grey.shade600,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5EAF0)),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Tulis pesan untuk pemilik kost...',
                          hintStyle: TextStyle(fontSize: 13.5),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primaryGreen,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sending ? null : () => _sendMessage(),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Built-in Emoji Picker Panel
          if (_showEmojiPicker) _buildEmojiPickerPanel(),
        ],
      ),
    );
  }

  Widget _buildEmojiPickerPanel() {
    final currentCategory = _emojiCategories[_emojiCategoryIndex];
    final emojis = currentCategory['emojis'] as List<String>;

    return Container(
      height: 250,
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                children: [
                  ...List.generate(_emojiCategories.length, (idx) {
                    final cat = _emojiCategories[idx];
                    final selected = idx == _emojiCategoryIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _emojiCategoryIndex = idx),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selected
                                    ? AppColors.primaryGreen
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Text(
                            '${cat['icon']} ${cat['label']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? AppColors.primaryGreen
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  IconButton(
                    tooltip: 'Hapus karakter',
                    onPressed: () {
                      final text = _msgCtrl.text;
                      if (text.isNotEmpty) {
                        final chars = text.characters.toList();
                        chars.removeLast();
                        final updated = chars.join();
                        _msgCtrl.value = TextEditingValue(
                          text: updated,
                          selection:
                              TextSelection.collapsed(offset: updated.length),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.backspace_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, idx) {
                  final emoji = emojis[idx];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _insertEmoji(emoji),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

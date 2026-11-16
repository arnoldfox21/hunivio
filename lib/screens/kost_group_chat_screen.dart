import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/kost_group.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';

class KostGroupChatScreen extends StatefulWidget {
  final int kostId;
  final String kostName;
  final String kostImage;

  const KostGroupChatScreen({
    super.key,
    required this.kostId,
    required this.kostName,
    this.kostImage = '',
  });

  @override
  State<KostGroupChatScreen> createState() => _KostGroupChatScreenState();
}

class _KostGroupChatScreenState extends State<KostGroupChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  KostGroupDetail? _detail;
  List<KostGroupMessage> _messages = [];
  KostGroupSettings _settings = const KostGroupSettings();
  List<KostGroupMember> _members = [];
  String _myRole = 'MEMBER';
  bool _loading = true;
  bool _sending = false;
  String? _errorMsg;
  bool _showEmojiPicker = false;
  io.Socket? _socket;
  bool _socketConnected = false;

  static const List<String> _emojis = [
    '😊', '🙏', '👍', '🏠', '🔑', '📦', '⚡', '📶',
    '🧹', '🚗', '🛵', '❤️', '🔥', '✅', '❓', '🎉',
  ];

  int get _userId => AuthService.currentUser?.id ?? 0;
  String get _userName => AuthService.currentUser?.name ?? 'Penghuni';
  String get _userAvatar => AuthService.currentUser?.avatarUrl ?? '';
  bool get _isAdmin => _myRole == 'ADMIN';

  @override
  void initState() {
    super.initState();
    NotificationService.activeGroupKostId = widget.kostId;
    _loadGroupDetail();
    _initSocket();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
  }

  @override
  void dispose() {
    if (NotificationService.activeGroupKostId == widget.kostId) {
      NotificationService.activeGroupKostId = null;
    }
    _socket?.emit('leaveGroupChat', {'kostId': widget.kostId});
    _socket?.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initSocket() {
    final token = ApiService.authToken;
    if (_userId <= 0 || token == null || token.isEmpty) return;
    try {
      final socket = io.io(
        ApiService.socketBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .disableAutoConnect()
            .build(),
      );
      socket.onConnect((_) {
        if (!mounted) return;
        setState(() => _socketConnected = true);
        socket.emit('joinGroupChat', {
          'kostId': widget.kostId,
          'userId': _userId,
        });
      });
      socket.onDisconnect((_) {
        if (mounted) setState(() => _socketConnected = false);
      });
      socket.on('newGroupMessage', (data) {
        if (!mounted || data == null) return;
        final msg =
            KostGroupMessage.fromJson(Map<String, dynamic>.from(data as Map));
        if (msg.kostId == widget.kostId &&
            !_messages.any((m) => m.id == msg.id)) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      });
      socket.on('groupSettingsUpdated', (data) {
        if (!mounted || data == null) return;
        final map = Map<String, dynamic>.from(data as Map);
        if ((int.tryParse('${map['kostId']}') ?? 0) == widget.kostId) {
          setState(() {
            _settings = KostGroupSettings.fromJson(map);
          });
        }
      });
      socket.on('groupMessageDeleted', (data) {
        if (!mounted || data == null) return;
        final map = Map<String, dynamic>.from(data as Map);
        final msgId = int.tryParse('${map['messageId']}') ?? 0;
        if (msgId > 0) {
          setState(() {
            _messages.removeWhere((m) => m.id == msgId);
            if (_settings.pinnedMessageId == msgId) {
              _settings = KostGroupSettings(
                pinnedMessageId: null,
                pinnedText: null,
                adminOnly: _settings.adminOnly,
              );
            }
          });
        }
      });
      socket.connect();
      _socket = socket;
    } catch (_) {}
  }

  Future<void> _loadGroupDetail() async {
    if (_userId <= 0) {
      setState(() {
        _loading = false;
        _errorMsg = 'Silakan login untuk mengakses grup penghuni.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final detail = await ApiService.fetchGroupDetail(
        kostId: widget.kostId,
        userId: _userId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _messages = detail.messages;
        _settings = detail.settings;
        _members = detail.members;
        _myRole = detail.myRole;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
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

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    if (_settings.adminOnly && !_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode Hanya Admin aktif. Hanya pemilik yang dapat mengirim pesan.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      if (_socket != null && _socketConnected) {
        _socket!.emitWithAck(
          'sendGroupMessage',
          {
            'kostId': widget.kostId,
            'senderId': _userId,
            'senderName': _userName,
            'senderAvatar': _userAvatar,
            'message': text,
          },
          ack: (dynamic ackData) {
            if (!mounted) return;
            setState(() => _sending = false);
            if (ackData != null) {
              _msgCtrl.clear();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gagal mengirim pesan grup. Coba lagi.'),
                ),
              );
            }
          },
        );
      } else {
        final saved = await ApiService.sendGroupMessageRest(
          kostId: widget.kostId,
          senderId: _userId,
          senderName: _userName,
          senderAvatar: _userAvatar,
          message: text,
        );
        if (mounted) _msgCtrl.clear();
        if (mounted && !_messages.any((m) => m.id == saved.id)) {
          setState(() => _messages.add(saved));
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('$e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessageActions(KostGroupMessage msg) {
    final canDelete = _isAdmin || msg.senderId == _userId;
    if (!_isAdmin && !canDelete) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.push_pin_rounded,
                    color: AppColors.primaryGreen),
                title: Text(
                  _settings.pinnedMessageId == msg.id
                      ? 'Lepas Sematan Pengumuman'
                      : 'Sematkan sebagai Pengumuman',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _socket?.emit('updateGroupSettings', {
                    'kostId': widget.kostId,
                    'userId': _userId,
                    'pinnedMessageId':
                        _settings.pinnedMessageId == msg.id ? null : msg.id,
                  });
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade600),
                title: Text(
                  'Hapus Pesan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade600,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _socket?.emit('deleteGroupMessage', {
                    'kostId': widget.kostId,
                    'userId': _userId,
                    'messageId': msg.id,
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddMemberSheet() async {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> candidates = [];
    bool loading = true;
    String? error;
    final Set<int> addingIds = {};

    Future<void> loadCandidates(
      String query,
      void Function(void Function()) setModalState,
    ) async {
      setModalState(() {
        loading = true;
        error = null;
      });
      try {
        final res = await ApiService.searchGroupCandidates(
          kostId: widget.kostId,
          adminId: _userId,
          query: query,
        );
        if (!mounted) return;
        setModalState(() {
          candidates = res;
          loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setModalState(() {
          error = e.toString();
          loading = false;
        });
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool initialized = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!initialized) {
              initialized = true;
              loadCandidates('', setModalState);
            }
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              builder: (_, scrollCtrl) => Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppColors.primaryGreen,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tambah Anggota Grup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: TextField(
                      controller: searchCtrl,
                      onSubmitted: (val) => loadCandidates(val, setModalState),
                      decoration: InputDecoration(
                        hintText: 'Cari nama, email, atau nomor HP...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          onPressed: () =>
                              loadCandidates(searchCtrl.text, setModalState),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                          )
                        : error != null
                            ? Center(child: Text(error!))
                            : candidates.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Pengguna tidak ditemukan.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollCtrl,
                                    itemCount: candidates.length,
                                    itemBuilder: (_, idx) {
                                      final c = candidates[idx];
                                      final uid = c['id'] as int;
                                      final isMember = c['isMember'] == true;
                                      final isAdding = addingIds.contains(uid);
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              AppColors.lightGreenBg,
                                          child: Text(
                                            (c['name']?.toString() ?? 'P')
                                                    .isNotEmpty
                                                ? c['name']
                                                    .toString()[0]
                                                    .toUpperCase()
                                                : 'P',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          c['name']?.toString() ?? 'Pengguna',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          [
                                            if ((c['phone']?.toString() ?? '')
                                                .isNotEmpty)
                                              c['phone'].toString(),
                                            if ((c['email']?.toString() ?? '')
                                                .isNotEmpty)
                                              c['email'].toString(),
                                          ].join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: isMember
                                            ? const Chip(
                                                label: Text(
                                                  'Anggota',
                                                  style:
                                                      TextStyle(fontSize: 11),
                                                ),
                                              )
                                            : ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.primaryGreen,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: isAdding
                                                    ? null
                                                    : () async {
                                                        setModalState(() =>
                                                            addingIds.add(uid));
                                                        try {
                                                          await ApiService
                                                              .addGroupMember(
                                                            kostId:
                                                                widget.kostId,
                                                            adminId: _userId,
                                                            targetUserId: uid,
                                                          );
                                                          setModalState(() {
                                                            c['isMember'] =
                                                                true;
                                                            addingIds
                                                                .remove(uid);
                                                          });
                                                          _loadGroupDetail();
                                                        } catch (e) {
                                                          setModalState(() =>
                                                              addingIds.remove(
                                                                  uid));
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(
                                                                    context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                backgroundColor:
                                                                    Colors.red
                                                                        .shade700,
                                                                content: Text(
                                                                    'Gagal menambahkan: $e'),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                child: Text(isAdding
                                                    ? '...'
                                                    : 'Tambah'),
                                              ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    searchCtrl.dispose();
  }

  void _openGroupInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.88,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.groups_rounded,
                      color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anggota Grup (${_members.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_isAdmin)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _openAddMemberSheet();
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text(
                        'Tambah',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            if (_isAdmin)
              SwitchListTile(
                title: const Text(
                  'Mode Hanya Admin',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Hanya pemilik properti yang dapat mengirim pesan',
                  style: TextStyle(fontSize: 12),
                ),
                activeColor: AppColors.primaryGreen,
                value: _settings.adminOnly,
                onChanged: (val) {
                  _socket?.emit('updateGroupSettings', {
                    'kostId': widget.kostId,
                    'userId': _userId,
                    'adminOnly': val,
                  });
                  Navigator.of(ctx).pop();
                },
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _members.length,
                itemBuilder: (context, idx) {
                  final m = _members[idx];
                  final isMemberAdmin = m.role == 'ADMIN';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lightGreenBg,
                      backgroundImage: m.avatarUrl.isNotEmpty
                          ? NetworkImage(m.avatarUrl)
                          : null,
                      child: m.avatarUrl.isEmpty
                          ? Text(
                              m.name.isNotEmpty
                                  ? m.name[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryGreen,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      m.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMemberAdmin
                                ? AppColors.lightGreenBg
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isMemberAdmin ? 'Admin • Pemilik' : 'Penghuni',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isMemberAdmin
                                  ? AppColors.darkGreen
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        if (_isAdmin && !isMemberAdmin)
                          IconButton(
                            tooltip: 'Keluarkan dari grup',
                            icon: Icon(Icons.person_remove_outlined,
                                color: Colors.red.shade600, size: 20),
                            onPressed: () async {
                              await ApiService.kickGroupMember(
                                kostId: widget.kostId,
                                adminId: _userId,
                                targetUserId: m.userId,
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              _loadGroupDetail();
                            },
                          ),
                      ],
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

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final titleName = _detail?.kostName ?? widget.kostName;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _members.isNotEmpty ? _openGroupInfoSheet : null,
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.lightGreenBg,
                child: Icon(
                  Icons.groups_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grup • $titleName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${_members.length} anggota${_isAdmin ? ' • Anda Admin' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Info & Anggota Grup',
            onPressed: _members.isNotEmpty ? _openGroupInfoSheet : null,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _errorMsg != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 52, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _errorMsg!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_settings.pinnedText != null &&
                        _settings.pinnedText!.trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          color: AppColors.lightGreenBg,
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFD1FAE5)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.push_pin_rounded,
                                size: 17, color: AppColors.darkGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _settings.pinnedText!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkGreen,
                                ),
                              ),
                            ),
                            if (_isAdmin)
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: AppColors.darkGreen),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  _socket?.emit('updateGroupSettings', {
                                    'kostId': widget.kostId,
                                    'userId': _userId,
                                    'pinnedMessageId': null,
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Belum ada percakapan di grup penghuni.\nMulai sapa penghuni atau buat pengumuman!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.all(14),
                              itemCount: _messages.length,
                              itemBuilder: (context, idx) {
                                final msg = _messages[idx];
                                final isMe = msg.senderId == _userId;
                                final isAdminMsg = msg.senderRole == 'ADMIN';
                                return Align(
                                  alignment: isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: GestureDetector(
                                    onLongPress: () =>
                                        _showMessageActions(msg),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.78,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? const Color(0xFFE7F8EE)
                                            : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(14),
                                          topRight: const Radius.circular(14),
                                          bottomLeft:
                                              Radius.circular(isMe ? 14 : 4),
                                          bottomRight:
                                              Radius.circular(isMe ? 4 : 14),
                                        ),
                                        border: Border.all(
                                          color: isMe
                                              ? AppColors.primaryGreen
                                                  .withOpacity(0.25)
                                              : AppColors.cardBorder,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                isMe ? 'Anda' : msg.senderName,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isAdminMsg
                                                      ? AppColors.darkGreen
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              if (isAdminMsg) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors.primaryGreen,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Text(
                                                    'Admin',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            msg.message,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              height: 1.35,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              _formatTime(msg.createdAt),
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_settings.adminOnly && !_isAdmin)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFFEF3C7),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: const Text(
                          'Mode Hanya Admin aktif. Hanya pemilik kost yang dapat mengirim pesan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: SafeArea(
                          top: false,
                          bottom: !_showEmojiPicker,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() =>
                                      _showEmojiPicker = !_showEmojiPicker);
                                  if (_showEmojiPicker) {
                                    _focusNode.unfocus();
                                  } else {
                                    _focusNode.requestFocus();
                                  }
                                },
                                icon: Icon(
                                  _showEmojiPicker
                                      ? Icons.keyboard_alt_outlined
                                      : Icons.emoji_emotions_outlined,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _msgCtrl,
                                  focusNode: _focusNode,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: 'Tulis pesan ke grup penghuni...',
                                    filled: true,
                                    fillColor: const Color(0xFFF3F4F6),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                backgroundColor: AppColors.primaryGreen,
                                child: IconButton(
                                  onPressed: _sending ? null : _sendMessage,
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_showEmojiPicker)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(10),
                        child: SafeArea(
                          top: false,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _emojis
                                .map(
                                  (e) => InkWell(
                                    onTap: () {
                                      _msgCtrl.text = '${_msgCtrl.text}$e';
                                      _msgCtrl.selection =
                                          TextSelection.fromPosition(
                                        TextPosition(
                                            offset: _msgCtrl.text.length),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Text(e,
                                          style: const TextStyle(fontSize: 22)),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

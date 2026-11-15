import 'package:flutter/material.dart';
import '../models/owner_post.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/owner_post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final OwnerPost post;
  final UserProfile owner;
  final bool focusComment;
  final ValueChanged<int>? onOpenKostById;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.owner,
    this.focusComment = false,
    this.onOpenKostById,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late OwnerPost _post;
  List<OwnerPostComment> _comments = [];
  bool _loadingComments = true;
  bool _submittingComment = false;
  bool _togglingLike = false;
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _commentFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final list = await ApiService.fetchPostComments(_post.id);
      if (!mounted) return;
      setState(() {
        _comments = list;
        _post = _post.copyWith(commentCount: list.length);
        _loadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat komentar: $e')),
      );
    }
  }

  Future<void> _toggleLike() async {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk menyukai postingan.'),
        ),
      );
      return;
    }
    if (_togglingLike) return;
    final prevLiked = _post.isLiked;
    final prevCount = _post.likeCount;
    setState(() {
      _togglingLike = true;
      _post = _post.copyWith(
        isLiked: !prevLiked,
        likeCount: prevLiked
            ? (prevCount > 0 ? prevCount - 1 : 0)
            : prevCount + 1,
      );
    });
    try {
      final res = await ApiService.togglePostLike(_post.id);
      if (!mounted) return;
      setState(() {
        _post = _post.copyWith(isLiked: res.liked, likeCount: res.likeCount);
        _togglingLike = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _post = _post.copyWith(isLiked: prevLiked, likeCount: prevCount);
        _togglingLike = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui suka: $e')),
      );
    }
  }

  Future<void> _submitComment() async {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk berkomentar.'),
        ),
      );
      return;
    }
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _submittingComment) return;

    setState(() => _submittingComment = true);
    try {
      final created = await ApiService.createPostComment(
        postId: _post.id,
        content: text,
      );
      if (!mounted) return;
      _commentCtrl.clear();
      setState(() {
        _comments = [..._comments, created];
        _post = _post.copyWith(commentCount: _comments.length);
        _submittingComment = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submittingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim komentar: $e')),
      );
    }
  }

  bool _canDeleteComment(OwnerPostComment comment) {
    final user = AuthService.currentUser;
    if (user == null) return false;
    final role = user.role.toUpperCase();
    return comment.userId == user.id ||
        _post.ownerId == user.id ||
        role == 'STAFF' ||
        role == 'ADMINISTRATOR';
  }

  Future<void> _deleteComment(OwnerPostComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Komentar'),
        content: const Text('Yakin ingin menghapus komentar ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deletePostComment(
        postId: _post.id,
        commentId: comment.id,
      );
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _post = _post.copyWith(commentCount: _comments.length);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus komentar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final userAvatar = currentUser?.avatarUrl.trim() ?? '';
    final userInitial = (currentUser?.name.trim().isNotEmpty ?? false)
        ? currentUser!.name.trim()[0].toUpperCase()
        : 'U';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.of(context).pop(_post);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_post),
          ),
          title: Text(
            'Postingan ${widget.owner.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadComments,
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    OwnerPostCard(
                      post: _post,
                      owner: widget.owner,
                      isDetailView: true,
                      onTapLike: _toggleLike,
                      onTapComment: () => _commentFocus.requestFocus(),
                      onTapImage: (_post.imageUrl != null &&
                              _post.imageUrl!.trim().isNotEmpty)
                          ? () => FullScreenImageViewer.open(
                                context,
                                imageUrl: _post.imageUrl!,
                                heroTag: 'post-image-${_post.id}',
                              )
                          : null,
                      onTapKost: _post.kostId != null
                          ? () => widget.onOpenKostById?.call(_post.kostId!)
                          : null,
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE4E6EB),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      child: Text(
                        'Komentar (${_comments.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF050505),
                        ),
                      ),
                    ),
                    if (_loadingComments)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 38,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Belum ada komentar.\nJadilah yang pertama berkomentar!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF65676B),
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._comments.map(_buildCommentItem),
                  ],
                ),
              ),
            ),
            // Sticky bottom comment composer
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE4E6EB), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: AppColors.lightGreenBg,
                          backgroundImage: userAvatar.isNotEmpty
                              ? NetworkImage(userAvatar)
                              : null,
                          child: userAvatar.isEmpty
                              ? Text(
                                  userInitial,
                                  style: const TextStyle(
                                    color: AppColors.darkGreen,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: TextField(
                            controller: _commentCtrl,
                            focusNode: _commentFocus,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submitComment(),
                            decoration: InputDecoration(
                              hintText: currentUser != null
                                  ? 'Tulis komentar...'
                                  : 'Masuk untuk berkomentar...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF65676B),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _submittingComment
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _submitComment,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: AppColors.primaryGreen,
                              ),
                              tooltip: 'Kirim Komentar',
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(OwnerPostComment comment) {
    final avatar = comment.userAvatarUrl.trim();
    final initial = comment.userName.trim().isNotEmpty
        ? comment.userName.trim()[0].toUpperCase()
        : 'U';
    final isPostOwner = comment.userId == _post.ownerId;
    final canDelete = _canDeleteComment(comment);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.lightGreenBg,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              comment.userName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF050505),
                              ),
                            ),
                          ),
                          if (isPostOwner) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lightGreenBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Pemilik',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        comment.content,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Color(0xFF050505),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatPostRelativeTime(comment.createdAt),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF65676B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (canDelete) ...[
                        const SizedBox(width: 14),
                        InkWell(
                          onTap: () => _deleteComment(comment),
                          child: const Text(
                            'Hapus',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

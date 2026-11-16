import 'package:flutter/material.dart';
import '../models/owner_post.dart';
import '../models/user_profile.dart';
import '../utils/formatters.dart';

String formatPostRelativeTime(String rawIso) {
  final parsed = DateTime.tryParse(rawIso)?.toLocal();
  if (parsed == null) return rawIso;
  final now = DateTime.now();
  final diff = now.difference(parsed);
  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt';
  if (diff.inHours < 24) return '${diff.inHours} jam';
  if (diff.inDays < 7) return '${diff.inDays} hr';
  final d = parsed.day.toString().padLeft(2, '0');
  final m = parsed.month.toString().padLeft(2, '0');
  final hh = parsed.hour.toString().padLeft(2, '0');
  final mm = parsed.minute.toString().padLeft(2, '0');
  return '$d/$m/${parsed.year} • $hh:$mm';
}

class OwnerPostCard extends StatelessWidget {
  final OwnerPost post;
  final UserProfile owner;
  final bool canManage;
  final bool isDetailView;
  final VoidCallback? onTapPost;
  final VoidCallback? onTapComment;
  final VoidCallback onTapLike;
  final VoidCallback? onTapImage;
  final VoidCallback? onTapKost;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const OwnerPostCard({
    super.key,
    required this.post,
    required this.owner,
    this.canManage = false,
    this.isDetailView = false,
    this.onTapPost,
    this.onTapComment,
    required this.onTapLike,
    this.onTapImage,
    this.onTapKost,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        post.imageUrl != null && post.imageUrl!.trim().isNotEmpty;
    final hasKost = post.kostId != null &&
        post.kostName != null &&
        post.kostName!.trim().isNotEmpty;
    final hasStats = post.likeCount > 0 || post.commentCount > 0;
    final likeColor =
        post.isLiked ? AppColors.primaryGreen : const Color(0xFF65676B);

    return Material(
      color: Colors.white,
      borderRadius: isDetailView ? BorderRadius.zero : BorderRadius.circular(14),
      elevation: isDetailView ? 0 : 0.5,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: isDetailView
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4E6EB)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: isDetailView ? null : onTapPost,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  owner.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF050505),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGreenBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  owner.roleLabel,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                formatPostRelativeTime(post.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF65676B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Text(
                                ' · ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF65676B),
                                ),
                              ),
                              const Icon(
                                Icons.public_rounded,
                                size: 13,
                                color: Color(0xFF65676B),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (canManage)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Color(0xFF65676B),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit?.call();
                        } else if (value == 'delete') {
                          onDelete?.call();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                ],
              ),
            ),

            // Body text
            InkWell(
              onTap: isDetailView ? null : onTapPost,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: isDetailView
                      ? SelectableText(
                          post.content,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Color(0xFF050505),
                          ),
                        )
                      : Text(
                          post.content,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Color(0xFF050505),
                          ),
                        ),
                ),
              ),
            ),

            // Image (edge-to-edge like FB)
            if (hasImage)
              GestureDetector(
                onTap: onTapImage,
                child: Hero(
                  tag: 'post-image-${post.id}',
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFF0F2F5),
                    constraints: isDetailView
                        ? null
                        : const BoxConstraints(maxHeight: 380),
                    child: Image.network(
                      post.imageUrl!,
                      width: double.infinity,
                      cacheWidth: 900,
                      fit: isDetailView ? BoxFit.fitWidth : BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 220,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 180,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Linked Kost card
            if (hasKost)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: InkWell(
                  onTap: onTapKost,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE4E6EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.home_work_rounded,
                            size: 19,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.kostName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF050505),
                                ),
                              ),
                              if (post.kostType != null &&
                                  post.kostType!.isNotEmpty)
                                Text(
                                  'Properti ${post.kostType!} • Ketuk untuk lihat',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF65676B),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF65676B),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Stats row (Likes & Comments count)
            if (hasStats)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(
                  children: [
                    if (post.likeCount > 0)
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.thumb_up_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.likeCount}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF65676B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),
                    if (post.commentCount > 0)
                      InkWell(
                        onTap: isDetailView ? onTapComment : onTapPost,
                        child: Text(
                          '${post.commentCount} komentar',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF65676B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              const SizedBox(height: 6),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Divider(
                height: 1,
                thickness: 0.8,
                color: Color(0xFFE4E6EB),
              ),
            ),

            // Action bar (Suka, Komentar)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTapLike,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            post.isLiked
                                ? Icons.thumb_up_alt_rounded
                                : Icons.thumb_up_outlined,
                            size: 19,
                            color: likeColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Suka',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: likeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onTapComment ?? onTapPost,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mode_comment_outlined,
                            size: 19,
                            color: Color(0xFF65676B),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Komentar',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF65676B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatar = owner.avatarUrl.trim();
    final initial =
        owner.name.trim().isNotEmpty ? owner.name.trim()[0].toUpperCase() : 'P';
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.lightGreenBg,
      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
      child: avatar.isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

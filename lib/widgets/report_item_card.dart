import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';

class ReportItemCard extends StatelessWidget {
  final ReportItem item;
  final VoidCallback? onTap;
  final bool hasUnreadMessage;

  const ReportItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.hasUnreadMessage = false,
  });

  Color _parseHexColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String? get _imageUrl {
    final primary = item.primaryImage?.trim();
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }

    for (final image in item.images) {
      final url = image.trim();
      if (url.isNotEmpty) return url;
    }

    return null;
  }

  Widget _buildThumbnail(bool isLost) {
    final imageUrl = _imageUrl;

    Widget placeholder() => Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: _parseHexColor(item.iconBgHex),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(
        item.icon,
        size: 28,
        color: (item.status ?? '').toLowerCase() == 'returned'
            ? Colors.red
            : isLost
            ? AppColors.lostThemeStart
            : AppColors.foundThemeStart,
      ),
    );

    if (imageUrl == null) {
      debugPrint(
        '[REPORT IMAGE] NO URL: id=${item.id}, '
        'type=${item.type}, title=${item.title}',
      );
      return placeholder();
    }

    debugPrint('[REPORT IMAGE] Loading: id=${item.id}, url=$imageUrl');

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;

          return Container(
            width: 64,
            height: 64,
            color: AppColors.borderColor,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            '[REPORT IMAGE] FAILED: id=${item.id}, '
            'url=$imageUrl, error=$error',
          );
          if (stackTrace != null) debugPrint('$stackTrace');
          return placeholder();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLost = item.type == ReportType.lost;

    final isReturned = (item.status ?? '').toLowerCase() == 'returned';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isReturned ? Border.all(color: Colors.red, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildThumbnail(isLost),
                    if (isReturned)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_returned_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (hasUnreadMessage)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.displayTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.status != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isReturned
                                    ? const Color(0xFFFFE8E8)
                                    : AppColors.matchedBadgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isReturned
                                    ? 'RETURNED'
                                    : item.status!.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isReturned
                                      ? Colors.red
                                      : AppColors.matchedBadgeText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              item.location,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isLost
                                  ? AppColors.lostBadgeBg
                                  : AppColors.foundBadgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isLost ? 'LOST' : 'FOUND',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isLost
                                    ? AppColors.lostBadgeText
                                    : AppColors.foundBadgeText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item.timeAgo,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.reward != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${item.reward}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

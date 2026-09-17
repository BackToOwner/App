import 'package:flutter/material.dart';

enum ReportType { all, lost, found }

ReportType reportTypeFromString(String? value) =>
    value == 'found' ? ReportType.found : ReportType.lost;

class ReportItem {
  final String id;
  final String title;

  /// Colour prefix shown in front of the title, e.g. "Black Sony Wireless Headphones".
  final String? itemColor;

  /// The two halves of a location the report form collects separately. Both are empty on reports
  /// the admin dashboard filed — those only ever have the server's single location string, which
  /// is what [location] falls back to rather than rendering an empty campus.
  final String campus;
  final String area;
  final String? additionalDetails;

  /// The server's single free-text location. Read it through [location], never directly.
  final String _serverLocation;

  final ReportType type;

  /// Server-side lifecycle: open | in_review | matched | returned | closed.
  final String? status;
  final String description;
  final String category;

  /// Emoji and card background come from the `categories` table, so the app no longer keeps its
  /// own copy of what each category looks like. [icon] maps the same category to a Material icon.
  final String emojiIcon;
  final String iconBgHex;

  final double? rewardAmount;
  final String rewardCurrency;
  final List<String> images;
  final String? primaryImage;
  final double? lat;
  final double? lng;
  final double? distanceKm;

  final String? ownerId;
  final String? ownerName;
  final bool isMine;

  final int viewCount;
  final int commentCount;
  final int claimCount;

  final DateTime? createdAt;
  final bool matched;

  ReportItem({
    required this.id,
    required this.title,
    required this.type,
    String location = '',
    this.itemColor,
    this.campus = '',
    this.area = '',
    this.additionalDetails,
    this.status,
    this.description = '',
    this.category = 'other',
    this.emojiIcon = '📦',
    this.iconBgHex = 'F1F5F9',
    this.rewardAmount,
    this.rewardCurrency = 'LKR',
    this.images = const [],
    this.primaryImage,
    this.lat,
    this.lng,
    this.distanceKm,
    this.ownerId,
    this.ownerName,
    this.isMine = false,
    this.viewCount = 0,
    this.commentCount = 0,
    this.claimCount = 0,
    this.createdAt,
    this.matched = false,
  }) : _serverLocation = location;

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    final coords = json['coordinates'] as Map<String, dynamic>?;

    return ReportItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      location: json['location'] as String? ?? '',
      itemColor: json['itemColor'] as String?,
      campus: json['campus'] as String? ?? '',
      area: json['area'] as String? ?? '',
      additionalDetails: json['additionalDetails'] as String?,
      type: reportTypeFromString(json['type'] as String?),
      status: json['status'] as String?,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      emojiIcon: json['emoji'] as String? ?? '📦',
      iconBgHex: json['iconBgHex'] as String? ?? 'F1F5F9',
      rewardAmount: (json['reward'] as num?)?.toDouble(),
      rewardCurrency: json['rewardCurrency'] as String? ?? 'LKR',
      images: (json['images'] as List?)?.whereType<String>().toList() ?? const [],
      primaryImage: json['primaryImage'] as String?,
      lat: (coords?['lat'] as num?)?.toDouble(),
      lng: (coords?['lng'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      ownerId: owner?['id'] as String?,
      ownerName: owner?['name'] as String?,
      isMine: json['isMine'] as bool? ?? false,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      claimCount: (json['claimCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
      matched: json['matched'] as bool? ?? false,
    );
  }

  /// The single location line the API stores. The server requires one, so the campus and area are
  /// composed into it on the way out — that keeps search and the FTS index working unchanged.
  static String composeLocation(String campus, String area) => [campus, area]
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' · ');

  /// Material icons keyed by the server's category id, in the order the report form offers them.
  /// The category list is fixed server-side, so an unknown id only means a new category was added
  /// — which falls back to the generic box rather than drawing nothing.
  static const Map<String, IconData> categoryIcons = {
    'electronics': Icons.smartphone,
    'wallets': Icons.account_balance_wallet,
    'pets': Icons.pets,
    'keys': Icons.vpn_key,
    'bags': Icons.backpack,
    'documents': Icons.description,
    'jewelry': Icons.watch,
    'clothing': Icons.checkroom,
    'other': Icons.inventory_2,
  };

  static IconData iconForCategory(String category) =>
      categoryIcons[category] ?? Icons.inventory_2;

  IconData get icon => iconForCategory(category);

  /// Title with the colour prefix, e.g. "Black Sony Wireless Headphones".
  String get displayTitle {
    final colour = itemColor;
    if (colour != null && colour.isNotEmpty) return '$colour $title';
    return title;
  }

  /// Combined location for display, e.g. "BCI · CRK 2". Falls back to whatever single string the
  /// server holds when this report predates the campus/area split.
  String get location {
    final composed = composeLocation(campus, area);
    if (composed.isNotEmpty) return composed;
    return _serverLocation.isEmpty ? 'Unknown Location' : _serverLocation;
  }

  /// Full location including the free-text details line.
  String get locationFull {
    final details = additionalDetails;
    if (details != null && details.isNotEmpty) return '$location\n$details';
    return location;
  }

  /// Formatted for the card, e.g. "LKR 5,000 reward". Null when no reward was offered, which is
  /// what the card checks before drawing the badge.
  String? get reward {
    final amount = rewardAmount;
    if (amount == null || amount <= 0) return null;
    final whole = amount.toStringAsFixed(0);
    final withSeparators = whole.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '$rewardCurrency $withSeparators reward';
  }

  /// Relative time, computed on the device rather than shipped from the server, so it stays
  /// correct while the screen is open.
  String get timeAgo {
    final created = createdAt;
    if (created == null) return '';

    final diff = DateTime.now().difference(created);
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  /// Uppercase badge the card shows next to the title — only for states worth calling out.
  String? get statusLabel {
    switch (status) {
      case 'matched':
        return 'MATCHED';
      case 'returned':
        return 'RETURNED';
      case 'in_review':
        return 'IN REVIEW';
      default:
        return null;
    }
  }
}

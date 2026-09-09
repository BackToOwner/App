/// A report category, with the emoji and swatch colour the cards draw.
/// Previously hard-coded in Dart; now served from the `categories` table.
class ItemCategory {
  final String id;
  final String label;
  final String emoji;
  final String bgHex;

  const ItemCategory({
    required this.id,
    required this.label,
    required this.emoji,
    required this.bgHex,
  });

  factory ItemCategory.fromJson(Map<String, dynamic> json) => ItemCategory(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '📦',
        bgHex: json['bgHex'] as String? ?? 'F1F5F9',
      );
}

/// A category loaded from the shared Supabase categories table.
class ItemCategory {
  final String id;
  final String label;
  final String icon;
  final String color;

  const ItemCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  factory ItemCategory.fromJson(Map<String, dynamic> json) => ItemCategory(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    icon: json['icon']?.toString() ?? 'Package',
    color: json['color']?.toString() ?? '#00D2B4',
  );
}

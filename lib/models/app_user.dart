/// The signed-in user, as returned by `/auth/me` and `/me`.
///
/// The backend never sends `idVerificationNo`, `passwordHash` or `googleId`, so there is nothing
/// sensitive to keep out of this model.
class AppUser {
  final String id;
  final String name;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? avatar;
  final String role;
  final int itemsReported;
  final int itemsFound;
  final int itemsReturned;
  final double trustScore;
  final bool emailVerified;
  final DateTime? joinedAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.avatar,
    this.role = 'Verified Citizen',
    this.itemsReported = 0,
    this.itemsFound = 0,
    this.itemsReturned = 0,
    this.trustScore = 95,
    this.emailVerified = false,
    this.joinedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatar: json['avatar'] as String?,
        role: json['role'] as String? ?? 'Verified Citizen',
        itemsReported: (json['itemsReported'] as num?)?.toInt() ?? 0,
        itemsFound: (json['itemsFound'] as num?)?.toInt() ?? 0,
        itemsReturned: (json['itemsReturned'] as num?)?.toInt() ?? 0,
        trustScore: (json['trustScore'] as num?)?.toDouble() ?? 95,
        emailVerified: json['emailVerified'] as bool? ?? false,
        joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? '')?.toLocal(),
      );

  /// First letter for the avatar circle, when there is no photo.
  String get initial => (name.isNotEmpty ? name : (email ?? '?')).substring(0, 1).toUpperCase();
}

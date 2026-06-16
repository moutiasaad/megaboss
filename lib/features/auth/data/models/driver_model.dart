// Driver profile — returned by GET /driver/me and POST /driver/login (data.user)
class DriverModel {
  const DriverModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.city,
    this.role = 'livreur',
    this.isAvailable = true,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? city;
  final String role; // 'livreur' | 'pickupeur'
  final bool isAvailable;

  factory DriverModel.fromJson(Map<String, dynamic> json) => DriverModel(
        id: json['id'] as int,
        name: (json['full_name'] ?? json['name'] ?? '') as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        avatar: (json['profile_image_url'] ?? json['avatar']) as String?,
        city: json['city'] as String?,
        role: json['role'] as String? ?? 'livreur',
        isAvailable: (json['is_available'] as bool?) ??
            (json['status'] as String?) == 'available',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'city': city,
        'role': role,
        'is_available': isAvailable,
      };

  // Initials for avatar placeholder (e.g. "Mohamed Ali" → "MA")
  String get initials {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  DriverModel copyWith({
    String? name,
    String? phone,
    String? avatar,
    String? city,
    String? role,
    bool? isAvailable,
  }) =>
      DriverModel(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        avatar: avatar ?? this.avatar,
        city: city ?? this.city,
        role: role ?? this.role,
        isAvailable: isAvailable ?? this.isAvailable,
      );
}

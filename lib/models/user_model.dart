import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, faculty, student }

class UserModel {
  final String userId;
  final String name;
  final UserRole role;
  final String? section;
  final String? photoUrl;
  final String? email;
  final String? authUid;
  final DateTime createdAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.role,
    this.section,
    this.photoUrl,
    this.email,
    this.authUid,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Basic field parsing with defaults
    final userId = map['user_id'] ?? map['userId'] ?? '';
    final name = map['name'] ?? 'Unknown User';

    // Defensive role parsing
    UserRole role = UserRole.student;
    try {
      final roleStr = map['role']?.toString().toLowerCase();
      role = UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.student,
      );
    } catch (_) {}

    // Safe timestamp parsing
    DateTime createdAt = DateTime.now();
    try {
      if (map['created_at'] is Timestamp) {
        createdAt = (map['created_at'] as Timestamp).toDate();
      } else if (map['issued_at'] is Timestamp) {
        createdAt = (map['issued_at'] as Timestamp).toDate();
      }
    } catch (_) {}

    return UserModel(
      userId: userId,
      name: name,
      role: role,
      section: map['section']?.toString(),
      photoUrl: map['photo_url']?.toString(),
      email: map['email']?.toString() ?? map['auth_email']?.toString(),
      authUid: map['auth_uid']?.toString(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'role': role.name,
      'section': section,
      'photo_url': photoUrl,
      'email': email,
      'auth_uid': authUid,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Classroom {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final List<String> adminIds;
  final List<String> members;
  final String? profileImageUrl;
  final DateTime createdAt;

  const Classroom({
    required this.id,
    required this.name,
    this.description = '',
    required this.inviteCode,
    required this.adminIds,
    required this.members,
    this.profileImageUrl,
    required this.createdAt,
  });

  bool isAdmin(String userId) => adminIds.contains(userId);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'adminIds': adminIds,
      'members': members,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Classroom.fromMap(Map<String, dynamic> map, String docId) {
    // Backward compatible: support both old 'adminId' and new 'adminIds'
    List<String> admins;
    if (map['adminIds'] != null) {
      admins = List<String>.from(map['adminIds']);
    } else if (map['adminId'] != null) {
      admins = [map['adminId'] as String];
    } else {
      admins = [];
    }

    return Classroom(
      id: docId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      adminIds: admins,
      members: List<String>.from(map['members'] ?? []),
      profileImageUrl: map['profileImageUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Classroom copyWith({
    String? id,
    String? name,
    String? description,
    String? inviteCode,
    List<String>? adminIds,
    List<String>? members,
    String? profileImageUrl,
    DateTime? createdAt,
  }) {
    return Classroom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      adminIds: adminIds ?? this.adminIds,
      members: members ?? this.members,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

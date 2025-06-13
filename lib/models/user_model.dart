import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  student,
  officerInCharge,
  clubAdmin,
  departmentAdmin,
  ssgAdmin
}

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String studentId;
  final String department;
  final UserRole role;
  final String? profileImageUrl;
  final List<String> clubs;
  final List<String> organizations;
  final int points;
  final String qrCodeData;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.studentId,
    required this.department,
    required this.role,
    this.profileImageUrl,
    required this.clubs,
    required this.organizations,
    required this.points,
    required this.qrCodeData,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      studentId: data['studentId'] ?? '',
      department: data['department'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.student,
      ),
      profileImageUrl: data['profileImageUrl'],
      clubs: List<String>.from(data['clubs'] ?? []),
      organizations: List<String>.from(data['organizations'] ?? []),
      points: data['points'] ?? 0,
      qrCodeData: data['qrCodeData'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'studentId': studentId,
      'department': department,
      'role': role.toString().split('.').last,
      'profileImageUrl': profileImageUrl,
      'clubs': clubs,
      'organizations': organizations,
      'points': points,
      'qrCodeData': qrCodeData,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? studentId,
    String? department,
    UserRole? role,
    String? profileImageUrl,
    List<String>? clubs,
    List<String>? organizations,
    int? points,
    String? qrCodeData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      studentId: studentId ?? this.studentId,
      department: department ?? this.department,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      clubs: clubs ?? this.clubs,
      organizations: organizations ?? this.organizations,
      points: points ?? this.points,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

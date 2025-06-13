import 'package:cloud_firestore/cloud_firestore.dart';

enum OrganizationType {
  ssg,
  department,
  club
}

class OrganizationModel {
  final String id;
  final String name;
  final String description;
  final OrganizationType type;
  final String? department;
  final String adminId;
  final List<String> officersInCharge;
  final List<String> members;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrganizationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.department,
    required this.adminId,
    required this.officersInCharge,
    required this.members,
    this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrganizationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrganizationModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      type: OrganizationType.values.firstWhere(
        (e) => e.toString() == 'OrganizationType.${data['type']}',
        orElse: () => OrganizationType.club,
      ),
      department: data['department'],
      adminId: data['adminId'] ?? '',
      officersInCharge: List<String>.from(data['officersInCharge'] ?? []),
      members: List<String>.from(data['members'] ?? []),
      logoUrl: data['logoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'department': department,
      'adminId': adminId,
      'officersInCharge': officersInCharge,
      'members': members,
      'logoUrl': logoUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

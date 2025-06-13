import 'package:cloud_firestore/cloud_firestore.dart';

enum ClearanceStatus {
  pending,
  approved,
  rejected
}

enum ClearanceType {
  ssg,
  department,
  club
}

class ClearanceModel {
  final String id;
  final String studentId;
  final String studentName;
  final String department;
  final ClearanceType type;
  final String organizationId;
  final String organizationName;
  final ClearanceStatus status;
  final String? remarks;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? transactionCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClearanceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.department,
    required this.type,
    required this.organizationId,
    required this.organizationName,
    required this.status,
    this.remarks,
    this.approvedBy,
    this.approvedAt,
    this.transactionCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClearanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClearanceModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      department: data['department'] ?? '',
      type: ClearanceType.values.firstWhere(
        (e) => e.toString() == 'ClearanceType.${data['type']}',
        orElse: () => ClearanceType.ssg,
      ),
      organizationId: data['organizationId'] ?? '',
      organizationName: data['organizationName'] ?? '',
      status: ClearanceStatus.values.firstWhere(
        (e) => e.toString() == 'ClearanceStatus.${data['status']}',
        orElse: () => ClearanceStatus.pending,
      ),
      remarks: data['remarks'],
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] != null ? (data['approvedAt'] as Timestamp).toDate() : null,
      transactionCode: data['transactionCode'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'department': department,
      'type': type.toString().split('.').last,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'status': status.toString().split('.').last,
      'remarks': remarks,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'transactionCode': transactionCode,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class UnifiedClearanceModel {
  final String id;
  final String studentId;
  final String studentName;
  final String department;
  final bool ssgApproved;
  final bool departmentApproved;
  final List<String> clubsApproved;
  final List<String> pendingClubs;
  final String? transactionCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  UnifiedClearanceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.department,
    required this.ssgApproved,
    required this.departmentApproved,
    required this.clubsApproved,
    required this.pendingClubs,
    this.transactionCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UnifiedClearanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UnifiedClearanceModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      department: data['department'] ?? '',
      ssgApproved: data['ssgApproved'] ?? false,
      departmentApproved: data['departmentApproved'] ?? false,
      clubsApproved: List<String>.from(data['clubsApproved'] ?? []),
      pendingClubs: List<String>.from(data['pendingClubs'] ?? []),
      transactionCode: data['transactionCode'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'department': department,
      'ssgApproved': ssgApproved,
      'departmentApproved': departmentApproved,
      'clubsApproved': clubsApproved,
      'pendingClubs': pendingClubs,
      'transactionCode': transactionCode,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

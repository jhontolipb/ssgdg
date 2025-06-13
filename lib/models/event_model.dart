import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  ssg,
  department,
  club
}

enum AttendanceStatus {
  pending,
  present,
  absent,
  late,
  excused
}

class EventModel {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final EventType type;
  final String organizerId;
  final String organizerName;
  final List<String> officersInCharge;
  final int sanctionPoints;
  final bool isMandatory;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.type,
    required this.organizerId,
    required this.organizerName,
    required this.officersInCharge,
    required this.sanctionPoints,
    required this.isMandatory,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      location: data['location'] ?? '',
      type: EventType.values.firstWhere(
        (e) => e.toString() == 'EventType.${data['type']}',
        orElse: () => EventType.ssg,
      ),
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      officersInCharge: List<String>.from(data['officersInCharge'] ?? []),
      sanctionPoints: data['sanctionPoints'] ?? 0,
      isMandatory: data['isMandatory'] ?? false,
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'location': location,
      'type': type.toString().split('.').last,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'officersInCharge': officersInCharge,
      'sanctionPoints': sanctionPoints,
      'isMandatory': isMandatory,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class AttendanceModel {
  final String id;
  final String eventId;
  final String studentId;
  final String studentName;
  final String department;
  final DateTime? timeIn;
  final DateTime? timeOut;
  final AttendanceStatus status;
  final String? remarks;
  final String recordedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  AttendanceModel({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.studentName,
    required this.department,
    this.timeIn,
    this.timeOut,
    required this.status,
    this.remarks,
    required this.recordedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      department: data['department'] ?? '',
      timeIn: data['timeIn'] != null ? (data['timeIn'] as Timestamp).toDate() : null,
      timeOut: data['timeOut'] != null ? (data['timeOut'] as Timestamp).toDate() : null,
      status: AttendanceStatus.values.firstWhere(
        (e) => e.toString() == 'AttendanceStatus.${data['status']}',
        orElse: () => AttendanceStatus.pending,
      ),
      remarks: data['remarks'],
      recordedBy: data['recordedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'studentId': studentId,
      'studentName': studentName,
      'department': department,
      'timeIn': timeIn,
      'timeOut': timeOut,
      'status': status.toString().split('.').last,
      'remarks': remarks,
      'recordedBy': recordedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

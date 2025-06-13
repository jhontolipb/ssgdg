import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ssg_digi/models/event_model.dart';
import 'package:ssg_digi/models/user_model.dart';
import 'package:ssg_digi/providers/notification_provider.dart';

class EventProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationProvider _notificationProvider = NotificationProvider();
  
  List<EventModel> _events = [];
  List<AttendanceModel> _attendances = [];
  bool _isLoading = false;
  String? _error;

  List<EventModel> get events => _events;
  List<AttendanceModel> get attendances => _attendances;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchEvents({
    EventType? type,
    String? organizerId,
    bool upcomingOnly = false,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _firestore.collection('events');
      
      if (type != null) {
        query = query.where('type', isEqualTo: type.toString().split('.').last);
      }
      
      if (organizerId != null) {
        query = query.where('organizerId', isEqualTo: organizerId);
      }
      
      if (upcomingOnly) {
        query = query.where('startDate', isGreaterThanOrEqualTo: DateTime.now());
      }
      
      query = query.orderBy('startDate', descending: false);
      
      final snapshot = await query.get();
      _events = snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<EventModel?> getEventById(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();
      if (doc.exists) {
        return EventModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> createEvent({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required String location,
    required EventType type,
    required String organizerId,
    required String organizerName,
    required List<String> officersInCharge,
    required int sanctionPoints,
    required bool isMandatory,
    String? imageUrl,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final newEvent = EventModel(
        id: '',
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        location: location,
        type: type,
        organizerId: organizerId,
        organizerName: organizerName,
        officersInCharge: officersInCharge,
        sanctionPoints: sanctionPoints,
        isMandatory: isMandatory,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore.collection('events').add(newEvent.toMap());
      
      // Notify officers in charge
      for (final officerId in officersInCharge) {
        await _notificationProvider.createNotification(
          userId: officerId,
          title: 'New Event Assignment',
          message: 'You have been assigned as an officer for the event: $title',
          type: NotificationType.event,
          relatedId: docRef.id,
        );
      }
      
      await fetchEvents();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateEvent({
    required String id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    List<String>? officersInCharge,
    int? sanctionPoints,
    bool? isMandatory,
    String? imageUrl,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (startDate != null) updates['startDate'] = startDate;
      if (endDate != null) updates['endDate'] = endDate;
      if (location != null) updates['location'] = location;
      if (officersInCharge != null) updates['officersInCharge'] = officersInCharge;
      if (sanctionPoints != null) updates['sanctionPoints'] = sanctionPoints;
      if (isMandatory != null) updates['isMandatory'] = isMandatory;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;

      await _firestore.collection('events').doc(id).update(updates);
      
      // If officers were updated, notify new officers
      if (officersInCharge != null) {
        final event = await getEventById(id);
        if (event != null) {
          for (final officerId in officersInCharge) {
            if (!event.officersInCharge.contains(officerId)) {
              await _notificationProvider.createNotification(
                userId: officerId,
                title: 'New Event Assignment',
                message: 'You have been assigned as an officer for the event: ${event.title}',
                type: NotificationType.event,
                relatedId: id,
              );
            }
          }
        }
      }
      
      await fetchEvents();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEvent(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('events').doc(id).delete();
      
      // Delete related attendances
      final attendanceSnapshot = await _firestore
          .collection('attendances')
          .where('eventId', isEqualTo: id)
          .get();
          
      final batch = _firestore.batch();
      for (final doc in attendanceSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      await fetchEvents();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAttendances({
    String? eventId,
    String? studentId,
    AttendanceStatus? status,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _firestore.collection('attendances');
      
      if (eventId != null) {
        query = query.where('eventId', isEqualTo: eventId);
      }
      
      if (studentId != null) {
        query = query.where('studentId', isEqualTo: studentId);
      }
      
      if (status != null) {
        query = query.where('status', isEqualTo: status.toString().split('.').last);
      }
      
      final snapshot = await query.get();
      _attendances = snapshot.docs.map((doc) => AttendanceModel.fromFirestore(doc)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> recordAttendance({
    required String eventId,
    required String studentId,
    required String studentName,
    required String department,
    required AttendanceStatus status,
    required String recordedBy,
    DateTime? timeIn,
    DateTime? timeOut,
    String? remarks,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if attendance record already exists
      final existingSnapshot = await _firestore
          .collection('attendances')
          .where('eventId', isEqualTo: eventId)
          .where('studentId', isEqualTo: studentId)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        // Update existing record
        final docId = existingSnapshot.docs.first.id;
        final updates = <String, dynamic>{
          'status': status.toString().split('.').last,
          'updatedAt': DateTime.now(),
        };

        if (timeIn != null) updates['timeIn'] = timeIn;
        if (timeOut != null) updates['timeOut'] = timeOut;
        if (remarks != null) updates['remarks'] = remarks;

        await _firestore.collection('attendances').doc(docId).update(updates);
      } else {
        // Create new record
        final newAttendance = AttendanceModel(
          id: '',
          eventId: eventId,
          studentId: studentId,
          studentName: studentName,
          department: department,
          timeIn: timeIn,
          timeOut: timeOut,
          status: status,
          remarks: remarks,
          recordedBy: recordedBy,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore.collection('attendances').add(newAttendance.toMap());
      }

      // Get event details for notification
      final event = await getEventById(eventId);
      if (event != null) {
        // Notify student about attendance
        await _notificationProvider.createNotification(
          userId: studentId,
          title: 'Attendance Recorded',
          message: 'Your attendance for ${event.title} has been recorded as ${status.toString().split('.').last}.',
          type: NotificationType.attendance,
          relatedId: eventId,
        );

        // Apply sanctions if absent and event is mandatory
        if (status == AttendanceStatus.absent && event.isMandatory && event.sanctionPoints > 0) {
          // Get student data
          final studentDoc = await _firestore.collection('users').doc(studentId).get();
          if (studentDoc.exists) {
            final userData = studentDoc.data() as Map<String, dynamic>;
            final currentPoints = userData['points'] as int? ?? 0;
            
            // Update points
            await _firestore.collection('users').doc(studentId).update({
              'points': currentPoints + event.sanctionPoints,
              'updatedAt': DateTime.now(),
            });
            
            // Notify student about sanctions
            await _notificationProvider.createNotification(
              userId: studentId,
              title: 'Sanctions Applied',
              message: 'You received ${event.sanctionPoints} sanction points for missing the mandatory event: ${event.title}.',
              type: NotificationType.general,
            );
          }
        }
      }
      
      await fetchAttendances();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAttendanceStatus({
    required String attendanceId,
    required AttendanceStatus status,
    String? remarks,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{
        'status': status.toString().split('.').last,
        'updatedAt': DateTime.now(),
      };

      if (remarks != null) updates['remarks'] = remarks;

      await _firestore.collection('attendances').doc(attendanceId).update(updates);
      
      // Get attendance details
      final attendanceDoc = await _firestore.collection('attendances').doc(attendanceId).get();
      if (attendanceDoc.exists) {
        final attendance = AttendanceModel.fromFirestore(attendanceDoc);
        
        // Get event details
        final event = await getEventById(attendance.eventId);
        if (event != null) {
          // Notify student about status update
          await _notificationProvider.createNotification(
            userId: attendance.studentId,
            title: 'Attendance Status Updated',
            message: 'Your attendance status for ${event.title} has been updated to ${status.toString().split('.').last}.',
            type: NotificationType.attendance,
            relatedId: attendance.eventId,
          );
          
          // Apply sanctions if absent and event is mandatory
          if (status == AttendanceStatus.absent && event.isMandatory && event.sanctionPoints > 0) {
            // Get student data
            final studentDoc = await _firestore.collection('users').doc(attendance.studentId).get();
            if (studentDoc.exists) {
              final userData = studentDoc.data() as Map<String, dynamic>;
              final currentPoints = userData['points'] as int? ?? 0;
              
              // Update points
              await _firestore.collection('users').doc(attendance.studentId).update({
                'points': currentPoints + event.sanctionPoints,
                'updatedAt': DateTime.now(),
              });
              
              // Notify student about sanctions
              await _notificationProvider.createNotification(
                userId: attendance.studentId,
                title: 'Sanctions Applied',
                message: 'You received ${event.sanctionPoints} sanction points for missing the mandatory event: ${event.title}.',
                type: NotificationType.general,
              );
            }
          }
        }
      }
      
      await fetchAttendances();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

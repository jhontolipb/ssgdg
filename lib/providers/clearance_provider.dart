import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ssg_digi/models/clearance_model.dart';
import 'package:ssg_digi/models/notification_model.dart';
import 'package:ssg_digi/providers/notification_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class ClearanceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationProvider _notificationProvider = NotificationProvider();
  
  List<ClearanceModel> _clearances = [];
  UnifiedClearanceModel? _unifiedClearance;
  bool _isLoading = false;
  String? _error;

  List<ClearanceModel> get clearances => _clearances;
  UnifiedClearanceModel? get unifiedClearance => _unifiedClearance;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchClearances({
    String? studentId,
    ClearanceType? type,
    String? organizationId,
    ClearanceStatus? status,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _firestore.collection('clearances');
      
      if (studentId != null) {
        query = query.where('studentId', isEqualTo: studentId);
      }
      
      if (type != null) {
        query = query.where('type', isEqualTo: type.toString().split('.').last);
      }
      
      if (organizationId != null) {
        query = query.where('organizationId', isEqualTo: organizationId);
      }
      
      if (status != null) {
        query = query.where('status', isEqualTo: status.toString().split('.').last);
      }
      
      final snapshot = await query.get();
      _clearances = snapshot.docs.map((doc) => ClearanceModel.fromFirestore(doc)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnifiedClearance(String studentId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('unifiedClearances')
          .where('studentId', isEqualTo: studentId)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        _unifiedClearance = UnifiedClearanceModel.fromFirestore(snapshot.docs.first);
      } else {
        _unifiedClearance = null;
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      _unifiedClearance = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestClearance({
    required String studentId,
    required String studentName,
    required String department,
    required ClearanceType type,
    required String organizationId,
    required String organizationName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if clearance request already exists
      final existingSnapshot = await _firestore
          .collection('clearances')
          .where('studentId', isEqualTo: studentId)
          .where('organizationId', isEqualTo: organizationId)
          .where('type', isEqualTo: type.toString().split('.').last)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        // If it exists and is not approved, update it
        final existingClearance = ClearanceModel.fromFirestore(existingSnapshot.docs.first);
        if (existingClearance.status != ClearanceStatus.approved) {
          await _firestore.collection('clearances').doc(existingClearance.id).update({
            'status': ClearanceStatus.pending.toString().split('.').last,
            'updatedAt': DateTime.now(),
          });
        } else {
          _error = 'Clearance already approved';
          return false;
        }
      } else {
        // Create new clearance request
        final newClearance = ClearanceModel(
          id: '',
          studentId: studentId,
          studentName: studentName,
          department: department,
          type: type,
          organizationId: organizationId,
          organizationName: organizationName,
          status: ClearanceStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore.collection('clearances').add(newClearance.toMap());
      }

      // Get admin ID for notification
      String? adminId;
      final orgDoc = await _firestore.collection('organizations').doc(organizationId).get();
      if (orgDoc.exists) {
        final orgData = orgDoc.data() as Map<String, dynamic>;
        adminId = orgData['adminId'] as String?;
      }

      // Notify admin about clearance request
      if (adminId != null) {
        await _notificationProvider.createNotification(
          userId: adminId,
          title: 'New Clearance Request',
          message: '$studentName has requested clearance for $organizationName.',
          type: NotificationType.clearance,
          relatedId: organizationId,
        );
      }
      
      await fetchClearances(studentId: studentId);
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

  Future<bool> approveClearance({
    required String clearanceId,
    required String approvedBy,
    String? remarks,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get clearance details
      final clearanceDoc = await _firestore.collection('clearances').doc(clearanceId).get();
      if (!clearanceDoc.exists) {
        _error = 'Clearance not found';
        return false;
      }

      final clearance = ClearanceModel.fromFirestore(clearanceDoc);
      
      // Update clearance status
      await _firestore.collection('clearances').doc(clearanceId).update({
        'status': ClearanceStatus.approved.toString().split('.').last,
        'approvedBy': approvedBy,
        'approvedAt': DateTime.now(),
        'remarks': remarks,
        'updatedAt': DateTime.now(),
      });

      // Update unified clearance
      await _updateUnifiedClearance(clearance);
      
      // Notify student about approval
      await _notificationProvider.createNotification(
        userId: clearance.studentId,
        title: 'Clearance Approved',
        message: 'Your clearance for ${clearance.organizationName} has been approved.',
        type: NotificationType.clearance,
        relatedId: clearanceId,
      );
      
      await fetchClearances();
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

  Future<bool> rejectClearance({
    required String clearanceId,
    required String remarks,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get clearance details
      final clearanceDoc = await _firestore.collection('clearances').doc(clearanceId).get();
      if (!clearanceDoc.exists) {
        _error = 'Clearance not found';
        return false;
      }

      final clearance = ClearanceModel.fromFirestore(clearanceDoc);
      
      // Update clearance status
      await _firestore.collection('clearances').doc(clearanceId).update({
        'status': ClearanceStatus.rejected.toString().split('.').last,
        'remarks': remarks,
        'updatedAt': DateTime.now(),
      });
      
      // Notify student about rejection
      await _notificationProvider.createNotification(
        userId: clearance.studentId,
        title: 'Clearance Rejected',
        message: 'Your clearance for ${clearance.organizationName} has been rejected. Reason: $remarks',
        type: NotificationType.clearance,
        relatedId: clearanceId,
      );
      
      await fetchClearances();
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

  Future<void> _updateUnifiedClearance(ClearanceModel clearance) async {
    try {
      // Check if unified clearance exists
      final unifiedSnapshot = await _firestore
          .collection('unifiedClearances')
          .where('studentId', isEqualTo: clearance.studentId)
          .get();

      if (unifiedSnapshot.docs.isNotEmpty) {
        // Update existing unified clearance
        final docId = unifiedSnapshot.docs.first.id;
        final existingData = unifiedSnapshot.docs.first.data();
        
        final updates = <String, dynamic>{
          'updatedAt': DateTime.now(),
        };

        switch (clearance.type) {
          case ClearanceType.ssg:
            updates['ssgApproved'] = true;
            break;
          case ClearanceType.department:
            updates['departmentApproved'] = true;
            break;
          case ClearanceType.club:
            final clubsApproved = List<String>.from(existingData['clubsApproved'] ?? []);
            if (!clubsApproved.contains(clearance.organizationId)) {
              clubsApproved.add(clearance.organizationId);
              updates['clubsApproved'] = clubsApproved;
            }
            
            final pendingClubs = List<String>.from(existingData['pendingClubs'] ?? []);
            if (pendingClubs.contains(clearance.organizationId)) {
              pendingClubs.remove(clearance.organizationId);
              updates['pendingClubs'] = pendingClubs;
            }
            break;
        }

        // Check if all clearances are approved to generate transaction code
        bool allApproved = false;
        if (clearance.type == ClearanceType.ssg) {
          final departmentApproved = existingData['departmentApproved'] ?? false;
          final pendingClubs = List<String>.from(existingData['pendingClubs'] ?? []);
          allApproved = departmentApproved && pendingClubs.isEmpty;
        } else if (clearance.type == ClearanceType.department) {
          final ssgApproved = existingData['ssgApproved'] ?? false;
          final pendingClubs = List<String>.from(existingData['pendingClubs'] ?? []);
          allApproved = ssgApproved && pendingClubs.isEmpty;
        } else {
          final ssgApproved = existingData['ssgApproved'] ?? false;
          final departmentApproved = existingData['departmentApproved'] ?? false;
          final pendingClubs = List<String>.from(existingData['pendingClubs'] ?? []);
          pendingClubs.remove(clearance.organizationId);
          allApproved = ssgApproved && departmentApproved && pendingClubs.isEmpty;
        }

        if (allApproved && existingData['transactionCode'] == null) {
          updates['transactionCode'] = const Uuid().v4();
        }

        await _firestore.collection('unifiedClearances').doc(docId).update(updates);
      } else {
        // Create new unified clearance
        final ssgApproved = clearance.type == ClearanceType.ssg;
        final departmentApproved = clearance.type == ClearanceType.department;
        final clubsApproved = clearance.type == ClearanceType.club ? [clearance.organizationId] : <String>[];
        
        // Get all clubs the student is a member of
        final userDoc = await _firestore.collection('users').doc(clearance.studentId).get();
        final userData = userDoc.data() as Map<String, dynamic>;
        final allClubs = List<String>.from(userData['clubs'] ?? []);
        
        // Calculate pending clubs
        final pendingClubs = [...allClubs];
        if (clearance.type == ClearanceType.club) {
          pendingClubs.remove(clearance.organizationId);
        }
        
        // Create unified clearance
        final newUnifiedClearance = UnifiedClearanceModel(
          id: '',
          studentId: clearance.studentId,
          studentName: clearance.studentName,
          department: clearance.department,
          ssgApproved: ssgApproved,
          departmentApproved: departmentApproved,
          clubsApproved: clubsApproved,
          pendingClubs: pendingClubs,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _firestore.collection('unifiedClearances').add(newUnifiedClearance.toMap());
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<File?> generateClearanceDocument() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_unifiedClearance == null || _unifiedClearance!.transactionCode == null) {
        _error = 'Unified clearance not complete';
        return null;
      }

      // Create PDF document
      final pdf = pw.Document();

      // Add content to PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'UNIFIED CLEARANCE DOCUMENT',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Student Name: ${_unifiedClearance!.studentName}'),
                pw.Text('Student ID: ${_unifiedClearance!.studentId}'),
                pw.Text('Department: ${_unifiedClearance!.department}'),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Clearance Status:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text('SSG: ${_unifiedClearance!.ssgApproved ? "Approved" : "Pending"}'),
                pw.Text('Department: ${_unifiedClearance!.departmentApproved ? "Approved" : "Pending"}'),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Clubs:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                for (final club in _unifiedClearance!.clubsApproved)
                  pw.Text('- $club: Approved'),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Transaction Code: ${_unifiedClearance!.transactionCode}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.BarcodeWidget(
                    data: _unifiedClearance!.transactionCode!,
                    barcode: pw.Barcode.qrCode(),
                    width: 200,
                    height: 200,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'Generated on: ${DateTime.now().toString().split('.').first}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/clearance_${_unifiedClearance!.studentId}.pdf');
      await file.writeAsBytes(await pdf.save());

      return file;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openClearanceDocument() async {
    final file = await generateClearanceDocument();
    if (file != null) {
      await OpenFile.open(file.path);
    }
  }
}

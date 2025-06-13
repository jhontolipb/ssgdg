import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ssg_digi/models/organization_model.dart';
import 'package:ssg_digi/models/user_model.dart';
import 'package:ssg_digi/providers/notification_provider.dart';

class OrganizationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationProvider _notificationProvider = NotificationProvider();
  
  List<OrganizationModel> _organizations = [];
  bool _isLoading = false;
  String? _error;

  List<OrganizationModel> get organizations => _organizations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchOrganizations({
    OrganizationType? type,
    String? department,
    String? adminId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _firestore.collection('organizations');
      
      if (type != null) {
        query = query.where('type', isEqualTo: type.toString().split('.').last);
      }
      
      if (department != null) {
        query = query.where('department', isEqualTo: department);
      }
      
      if (adminId != null) {
        query = query.where('adminId', isEqualTo: adminId);
      }
      
      final snapshot = await query.get();
      _organizations = snapshot.docs.map((doc) => OrganizationModel.fromFirestore(doc)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<OrganizationModel?> getOrganizationById(String id) async {
    try {
      final doc = await _firestore.collection('organizations').doc(id).get();
      if (doc.exists) {
        return OrganizationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> createOrganization({
    required String name,
    required String description,
    required OrganizationType type,
    String? department,
    required String adminId,
    String? logoUrl,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Validate department for departmental organizations
      if (type == OrganizationType.department && (department == null || department.isEmpty)) {
        _error = 'Department is required for departmental organizations';
        return false;
      }

      final newOrganization = OrganizationModel(
        id: '',
        name: name,
        description: description,
        type: type,
        department: department,
        adminId: adminId,
        officersInCharge: [],
        members: [],
        logoUrl: logoUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('organizations').add(newOrganization.toMap());
      
      await fetchOrganizations();
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

  Future<bool> updateOrganization({
    required String id,
    String? name,
    String? description,
    String? adminId,
    String? logoUrl,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (adminId != null) updates['adminId'] = adminId;
      if (logoUrl != null) updates['logoUrl'] = logoUrl;

      await _firestore.collection('organizations').doc(id).update(updates);
      
      // If admin was updated, notify new admin
      if (adminId != null) {
        final org = await getOrganizationById(id);
        if (org != null) {
          await _notificationProvider.createNotification(
            userId: adminId,
            title: 'New Admin Assignment',
            message: 'You have been assigned as the admin for ${org.name}.',
            type: NotificationType.general,
            relatedId: id,
          );
        }
      }
      
      await fetchOrganizations();
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

  Future<bool> deleteOrganization(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if organization has members
      final org = await getOrganizationById(id);
      if (org != null && org.members.isNotEmpty) {
        _error = 'Cannot delete organization with members';
        return false;
      }

      await _firestore.collection('organizations').doc(id).delete();
      
      await fetchOrganizations();
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

  Future<bool> addOfficerInCharge({
    required String organizationId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get organization
      final orgDoc = await _firestore.collection('organizations').doc(organizationId).get();
      if (!orgDoc.exists) {
        _error = 'Organization not found';
        return false;
      }

      final org = OrganizationModel.fromFirestore(orgDoc);
      
      // Check if user is already an officer
      if (org.officersInCharge.contains(userId)) {
        _error = 'User is already an officer';
        return false;
      }

      // Add user to officers
      final updatedOfficers = [...org.officersInCharge, userId];
      await _firestore.collection('organizations').doc(organizationId).update({
        'officersInCharge': updatedOfficers,
        'updatedAt': DateTime.now(),
      });
      
      // Notify user
      await _notificationProvider.createNotification(
        userId: userId,
        title: 'New Officer Assignment',
        message: 'You have been assigned as an officer for ${org.name}.',
        type: NotificationType.general,
        relatedId: organizationId,
      );
      
      // Update user role if needed
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final currentRole = userData['role'] as String? ?? 'student';
        
        if (currentRole == 'student') {
          await _firestore.collection('users').doc(userId).update({
            'role': UserRole.officerInCharge.toString().split('.').last,
            'updatedAt': DateTime.now(),
          });
        }
      }
      
      await fetchOrganizations();
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

  Future<bool> removeOfficerInCharge({
    required String organizationId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get organization
      final orgDoc = await _firestore.collection('organizations').doc(organizationId).get();
      if (!orgDoc.exists) {
        _error = 'Organization not found';
        return false;
      }

      final org = OrganizationModel.fromFirestore(orgDoc);
      
      // Check if user is an officer
      if (!org.officersInCharge.contains(userId)) {
        _error = 'User is not an officer';
        return false;
      }

      // Remove user from officers
      final updatedOfficers = [...org.officersInCharge];
      updatedOfficers.remove(userId);
      await _firestore.collection('organizations').doc(organizationId).update({
        'officersInCharge': updatedOfficers,
        'updatedAt': DateTime.now(),
      });
      
      // Notify user
      await _notificationProvider.createNotification(
        userId: userId,
        title: 'Officer Assignment Removed',
        message: 'You have been removed as an officer for ${org.name}.',
        type: NotificationType.general,
        relatedId: organizationId,
      );
      
      // Check if user is still an officer in any organization
      final otherOrgsSnapshot = await _firestore
          .collection('organizations')
          .where('officersInCharge', arrayContains: userId)
          .get();
          
      if (otherOrgsSnapshot.docs.isEmpty) {
        // If not an officer anywhere else, revert role to student
        await _firestore.collection('users').doc(userId).update({
          'role': UserRole.student.toString().split('.').last,
          'updatedAt': DateTime.now(),
        });
      }
      
      await fetchOrganizations();
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

  Future<bool> addMember({
    required String organizationId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get organization
      final orgDoc = await _firestore.collection('organizations').doc(organizationId).get();
      if (!orgDoc.exists) {
        _error = 'Organization not found';
        return false;
      }

      final org = OrganizationModel.fromFirestore(orgDoc);
      
      // Check if user is already a member
      if (org.members.contains(userId)) {
        _error = 'User is already a member';
        return false;
      }

      // Add user to members
      final updatedMembers = [...org.members, userId];
      await _firestore.collection('organizations').doc(organizationId).update({
        'members': updatedMembers,
        'updatedAt': DateTime.now(),
      });
      
      // Update user's clubs or organizations
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        if (org.type == OrganizationType.club) {
          final clubs = List<String>.from(userData['clubs'] ?? []);
          if (!clubs.contains(org.name)) {
            clubs.add(org.name);
            await _firestore.collection('users').doc(userId).update({
              'clubs': clubs,
              'updatedAt': DateTime.now(),
            });
          }
        } else if (org.type == OrganizationType.department) {
          final organizations = List<String>.from(userData['organizations'] ?? []);
          if (!organizations.contains(org.name)) {
            organizations.add(org.name);
            await _firestore.collection('users').doc(userId).update({
              'organizations': organizations,
              'updatedAt': DateTime.now(),
            });
          }
        }
      }
      
      // Notify user
      await _notificationProvider.createNotification(
        userId: userId,
        title: 'New Membership',
        message: 'You have been added as a member of ${org.name}.',
        type: NotificationType.general,
        relatedId: organizationId,
      );
      
      await fetchOrganizations();
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

  Future<bool> removeMember({
    required String organizationId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get organization
      final orgDoc = await _firestore.collection('organizations').doc(organizationId).get();
      if (!orgDoc.exists) {
        _error = 'Organization not found';
        return false;
      }

      final org = OrganizationModel.fromFirestore(orgDoc);
      
      // Check if user is a member
      if (!org.members.contains(userId)) {
        _error = 'User is not a member';
        return false;
      }

      // Remove user from members
      final updatedMembers = [...org.members];
      updatedMembers.remove(userId);
      await _firestore.collection('organizations').doc(organizationId).update({
        'members': updatedMembers,
        'updatedAt': DateTime.now(),
      });
      
      // Update user's clubs or organizations
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        if (org.type == OrganizationType.club) {
          final clubs = List<String>.from(userData['clubs'] ?? []);
          if (clubs.contains(org.name)) {
            clubs.remove(org.name);
            await _firestore.collection('users').doc(userId).update({
              'clubs': clubs,
              'updatedAt': DateTime.now(),
            });
          }
        } else if (org.type == OrganizationType.department) {
          final organizations = List<String>.from(userData['organizations'] ?? []);
          if (organizations.contains(org.name)) {
            organizations.remove(org.name);
            await _firestore.collection('users').doc(userId).update({
              'organizations': organizations,
              'updatedAt': DateTime.now(),
            });
          }
        }
      }
      
      // Notify user
      await _notificationProvider.createNotification(
        userId: userId,
        title: 'Membership Removed',
        message: 'You have been removed from ${org.name}.',
        type: NotificationType.general,
        relatedId: organizationId,
      );
      
      await fetchOrganizations();
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

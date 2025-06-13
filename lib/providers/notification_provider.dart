import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:ssg_digi/models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  NotificationProvider() {
    _initMessaging();
  }

  Future<void> _initMessaging() async {
    // Request permission for notifications
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      final token = await _messaging.getToken();
      
      // Save token to user document if logged in
      // This would typically be done in the auth provider after login
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Handle the message and update notifications
        fetchNotifications();
      });
    }
  }

  Future<void> fetchNotifications({String? userId}) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (userId == null) {
        _notifications = [];
        _unreadCount = 0;
        return;
      }

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
          
      _notifications = snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();
      
      // Count unread notifications
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    String? relatedId,
  }) async {
    try {
      final newNotification = NotificationModel(
        id: '',
        userId: userId,
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('notifications').add(newNotification.toMap());
      
      // Send push notification (this would typically be done via Cloud Functions)
      // For now, we'll just update the local state if the user is the recipient
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final updatedNotification = NotificationModel(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          title: _notifications[index].title,
          message: _notifications[index].message,
          type: _notifications[index].type,
          relatedId: _notifications[index].relatedId,
          isRead: true,
          createdAt: _notifications[index].createdAt,
        );
        
        _notifications[index] = updatedNotification;
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> markAllAsRead(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get all unread notifications
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
          
      // Create batch update
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      // Commit batch
      await batch.commit();
      
      // Update local state
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          final updatedNotification = NotificationModel(
            id: _notifications[i].id,
            userId: _notifications[i].userId,
            title: _notifications[i].title,
            message: _notifications[i].message,
            type: _notifications[i].type,
            relatedId: _notifications[i].relatedId,
            isRead: true,
            createdAt: _notifications[i].createdAt,
          );
          
          _notifications[i] = updatedNotification;
        }
      }
      
      _unreadCount = 0;
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      
      // Update local state
      _notifications.removeWhere((n) => n.id == notificationId);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
}

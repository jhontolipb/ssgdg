import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ssg_digi/models/message_model.dart';
import 'package:ssg_digi/providers/notification_provider.dart';
import 'package:ssg_digi/models/notification_model.dart';

class MessageProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationProvider _notificationProvider = NotificationProvider();
  
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchMessages({
    required String userId,
    String? otherUserId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _firestore.collection('messages')
          .where('senderId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);
          
      if (otherUserId != null) {
        query = _firestore.collection('messages')
            .where(Filter.or(
              Filter.and(
                Filter('senderId', isEqualTo: userId),
                Filter('receiverId', isEqualTo: otherUserId),
              ),
              Filter.and(
                Filter('senderId', isEqualTo: otherUserId),
                Filter('receiverId', isEqualTo: userId),
              ),
            ))
            .orderBy('createdAt', descending: true);
      }
      
      final snapshot = await query.get();
      _messages = snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String receiverName,
    required String content,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final newMessage = MessageModel(
        id: '',
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        receiverName: receiverName,
        content: content,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('messages').add(newMessage.toMap());
      
      // Notify receiver
      await _notificationProvider.createNotification(
        userId: receiverId,
        title: 'New Message',
        message: 'You have a new message from $senderName',
        type: NotificationType.message,
        relatedId: senderId,
      );
      
      // Update local state
      _messages.insert(0, newMessage);
      
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

  Future<bool> markMessageAsRead(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'isRead': true,
      });
      
      // Update local state
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final updatedMessage = MessageModel(
          id: _messages[index].id,
          senderId: _messages[index].senderId,
          senderName: _messages[index].senderName,
          receiverId: _messages[index].receiverId,
          receiverName: _messages[index].receiverName,
          content: _messages[index].content,
          isRead: true,
          createdAt: _messages[index].createdAt,
        );
        
        _messages[index] = updatedMessage;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> markAllMessagesAsRead({
    required String userId,
    required String otherUserId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get all unread messages from other user
      final snapshot = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: userId)
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
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].senderId == otherUserId && 
            _messages[i].receiverId == userId && 
            !_messages[i].isRead) {
          final updatedMessage = MessageModel(
            id: _messages[i].id,
            senderId: _messages[i].senderId,
            senderName: _messages[i].senderName,
            receiverId: _messages[i].receiverId,
            receiverName: _messages[i].receiverName,
            content: _messages[i].content,
            isRead: true,
            createdAt: _messages[i].createdAt,
          );
          
          _messages[i] = updatedMessage;
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
          
      return snapshot.count;
    } catch (e) {
      _error = e.toString();
      return 0;
    }
  }
}

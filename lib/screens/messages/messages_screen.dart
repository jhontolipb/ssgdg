import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/message_provider.dart';
import 'package:ssg_digi/providers/organization_provider.dart';
import 'package:ssg_digi/models/message_model.dart';
import 'package:ssg_digi/models/organization_model.dart';
import 'package:ssg_digi/screens/messages/chat_screen.dart';
import 'package:ssg_digi/screens/messages/compose_message_screen.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isLoading = false;
  Map<String, MessageModel> _latestMessages = {};
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messageProvider = Provider.of<MessageProvider>(context, listen: false);

    if (authProvider.user != null) {
      await messageProvider.fetchMessages(userId: authProvider.user!.id);
      
      // Group messages by conversation (other user)
      final messages = messageProvider.messages;
      _latestMessages = {};
      _userNames = {};
      
      for (final message in messages) {
        final otherUserId = message.senderId == authProvider.user!.id
            ? message.receiverId
            : message.senderId;
        
        final otherUserName = message.senderId == authProvider.user!.id
            ? message.receiverName
            : message.senderName;
        
        // Keep only the latest message for each conversation
        if (!_latestMessages.containsKey(otherUserId) ||
            message.createdAt.isAfter(_latestMessages[otherUserId]!.createdAt)) {
          _latestMessages[otherUserId] = message;
          _userNames[otherUserId] = otherUserName;
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ComposeMessageScreen(),
                ),
              ).then((_) => _loadMessages());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMessages,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _latestMessages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the + button to start a conversation',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _latestMessages.length,
                    itemBuilder: (context, index) {
                      final otherUserId = _latestMessages.keys.elementAt(index);
                      final message = _latestMessages[otherUserId]!;
                      final otherUserName = _userNames[otherUserId]!;
                      
                      return _buildMessageTile(message, otherUserId, otherUserName);
                    },
                  ),
      ),
    );
  }

  Widget _buildMessageTile(MessageModel message, String otherUserId, String otherUserName) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isFromMe = message.senderId == authProvider.user?.id;
    final isUnread = !message.isRead && !isFromMe;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: Text(
          otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        otherUserName,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        message.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
          color: isUnread ? Colors.black87 : Colors.grey,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat('MMM d').format(message.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: isUnread ? Colors.blue : Colors.grey,
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isUnread) ...[
            const SizedBox(height: 4),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              otherUserId: otherUserId,
              otherUserName: otherUserName,
            ),
          ),
        ).then((_) => _loadMessages());
      },
    );
  }
}

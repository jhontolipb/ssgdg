import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/message_provider.dart';
import 'package:ssg_digi/providers/organization_provider.dart';
import 'package:ssg_digi/models/organization_model.dart';
import 'package:ssg_digi/models/user_model.dart';
import 'package:ssg_digi/screens/messages/chat_screen.dart';
import 'package:ssg_digi/widgets/loading_overlay.dart';

class ComposeMessageScreen extends StatefulWidget {
  const ComposeMessageScreen({super.key});

  @override
  State<ComposeMessageScreen> createState() => _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends State<ComposeMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  List<OrganizationModel> _organizations = [];
  List<Map<String, dynamic>> _recipients = [];
  Map<String, dynamic>? _selectedRecipient;

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  Future<void> _loadRecipients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final organizationProvider = Provider.of<OrganizationProvider>(context, listen: false);

      if (authProvider.user != null) {
        final user = authProvider.user!;
        
        // Load organizations
        await organizationProvider.fetchOrganizations();
        _organizations = organizationProvider.organizations;
        
        _recipients = [];
        
        // Add organization admins based on user role
        switch (user.role) {
          case UserRole.student:
            // Students can message SSG, their department, and their clubs
            
            // Add SSG admins
            final ssgOrgs = _organizations.where((org) => org.type == OrganizationType.ssg).toList();
            for (final org in ssgOrgs) {
              final admin = await authProvider.getUserById(org.adminId);
              if (admin != null) {
                _recipients.add({
                  'id': admin.id,
                  'name': admin.fullName,
                  'role': 'SSG Admin',
                  'organization': org.name,
                });
              }
            }
            
            // Add department admins
            final deptOrgs = _organizations.where((org) => 
                org.type == OrganizationType.department && 
                org.department == user.department).toList();
            for (final org in deptOrgs) {
              final admin = await authProvider.getUserById(org.adminId);
              if (admin != null) {
                _recipients.add({
                  'id': admin.id,
                  'name': admin.fullName,
                  'role': 'Department Admin',
                  'organization': org.name,
                });
              }
            }
            
            // Add club admins for user's clubs
            final clubOrgs = _organizations.where((org) => 
                org.type == OrganizationType.club && 
                user.clubs.contains(org.name)).toList();
            for (final org in clubOrgs) {
              final admin = await authProvider.getUserById(org.adminId);
              if (admin != null) {
                _recipients.add({
                  'id': admin.id,
                  'name': admin.fullName,
                  'role': 'Club Admin',
                  'organization': org.name,
                });
              }
            }
            break;
            
          case UserRole.officerInCharge:
            // Officers can message their organization admins and SSG
            
            // Add SSG admins
            final ssgOrgs = _organizations.where((org) => org.type == OrganizationType.ssg).toList();
            for (final org in ssgOrgs) {
              final admin = await authProvider.getUserById(org.adminId);
              if (admin != null) {
                _recipients.add({
                  'id': admin.id,
                  'name': admin.fullName,
                  'role': 'SSG Admin',
                  'organization': org.name,
                });
              }
            }
            
            // Add admins of organizations where user is an officer
            final officerOrgs = _organizations.where((org) => 
                org.officersInCharge.contains(user.id)).toList();
            for (final org in officerOrgs) {
              final admin = await authProvider.getUserById(org.adminId);
              if (admin != null) {
                _recipients.add({
                  'id': admin.id,
                  'name': admin.fullName,
                  'role': '${org.type.toString().split('.').last} Admin',
                  'organization': org.name,
                });
              }
            }
            break;
            
          case UserRole.clubAdmin:
          case UserRole.departmentAdmin:
            // Admins can message SSG and their members
            
            // Add SSG admins
            final ssgOrgs = _organizations.where((org) => org.type == OrganizationType.ssg).toList();
            for (final org in ssgOrgs) {
              final admin = await authProvider.getUserById(org.adminId);
              if (admin != null) {
                _recipients.add({
                  'id': admin.id,
                  'name': admin.fullName,
                  'role': 'SSG Admin',
                  'organization': org.name,
                });
              }
            }
            break;
            
          case UserRole.ssgAdmin:
            // SSG can message all admins
            for (final org in _organizations) {
              if (org.type != OrganizationType.ssg) {
                final admin = await authProvider.getUserById(org.adminId);
                if (admin != null) {
                  _recipients.add({
                    'id': admin.id,
                    'name': admin.fullName,
                    'role': '${org.type.toString().split('.').last} Admin',
                    'organization': org.name,
                  });
                }
              }
            }
            break;
        }
        
        // Remove duplicates
        final seen = <String>{};
        _recipients = _recipients.where((recipient) {
          final id = recipient['id'] as String;
          if (seen.contains(id)) {
            return false;
          }
          seen.add(id);
          return true;
        }).toList();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_selectedRecipient == null || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recipient and enter a message')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final messageProvider = Provider.of<MessageProvider>(context, listen: false);

      if (authProvider.user != null) {
        final success = await messageProvider.sendMessage(
          senderId: authProvider.user!.id,
          senderName: authProvider.user!.fullName,
          receiverId: _selectedRecipient!['id'],
          receiverName: _selectedRecipient!['name'],
          content: _messageController.text.trim(),
        );

        if (success && mounted) {
          // Navigate to chat screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                otherUserId: _selectedRecipient!['id'],
                otherUserName: _selectedRecipient!['name'],
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(messageProvider.error ?? 'Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Message'),
          actions: [
            TextButton(
              onPressed: _sendMessage,
              child: const Text(
                'Send',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipient Selection
              const Text(
                'To:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedRecipient,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select recipient',
                ),
                items: _recipients.map((recipient) {
                  return DropdownMenuItem(
                    value: recipient,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipient['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${recipient['role']} • ${recipient['organization']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRecipient = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              // Message Input
              const Text(
                'Message:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Type your message here...',
                    alignLabelWithHint: true,
                  ),
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
              const SizedBox(height: 16),
              
              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Send Message'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

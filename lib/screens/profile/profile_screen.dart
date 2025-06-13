import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/screens/profile/edit_profile_screen.dart';
import 'package:ssg_digi/screens/profile/change_password_screen.dart';
import 'package:ssg_digi/screens/qr/qr_code_screen.dart';
import 'package:ssg_digi/widgets/loading_overlay.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoading) {
            return const LoadingOverlay(
              isLoading: true,
              child: SizedBox(),
            );
          }

          final user = authProvider.user;
          if (user == null) {
            return const Center(
              child: Text('User not found'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: user.profileImageUrl != null
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          child: user.profileImageUrl == null
                              ? Text(
                                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getRoleColor(user.role).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _getRoleColor(user.role)),
                          ),
                          child: Text(
                            _getRoleText(user.role),
                            style: TextStyle(
                              color: _getRoleColor(user.role),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // User Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(Icons.badge, 'Student ID', user.studentId),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.email, 'Email', user.email),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.school, 'Department', user.department),
                        if (user.clubs.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.group, 'Clubs', user.clubs.join(', ')),
                        ],
                        if (user.organizations.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.business, 'Organizations', user.organizations.join(', ')),
                        ],
                        if (user.points > 0) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.warning,
                            'Sanction Points',
                            user.points.toString(),
                            valueColor: Colors.red,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Actions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (user.role == UserRole.student) ...[
                          ListTile(
                            leading: const Icon(Icons.qr_code, color: Colors.blue),
                            title: const Text('My QR Code'),
                            subtitle: const Text('Show your QR code for attendance'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => QrCodeScreen(user: user),
                                ),
                              );
                            },
                          ),
                          const Divider(),
                        ],
                        
                        ListTile(
                          leading: const Icon(Icons.edit, color: Colors.green),
                          title: const Text('Edit Profile'),
                          subtitle: const Text('Update your personal information'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        
                        ListTile(
                          leading: const Icon(Icons.lock, color: Colors.orange),
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your account password'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Logout'),
                          subtitle: const Text('Sign out of your account'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => _showLogoutDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Colors.blue;
      case UserRole.officerInCharge:
        return Colors.green;
      case UserRole.clubAdmin:
        return Colors.orange;
      case UserRole.departmentAdmin:
        return Colors.purple;
      case UserRole.ssgAdmin:
        return Colors.red;
    }
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.officerInCharge:
        return 'Officer in Charge';
      case UserRole.clubAdmin:
        return 'Club Admin';
      case UserRole.departmentAdmin:
        return 'Department Admin';
      case UserRole.ssgAdmin:
        return 'SSG Admin';
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

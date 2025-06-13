import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/organization_provider.dart';
import 'package:ssg_digi/screens/admin/user_management_screen.dart';
import 'package:ssg_digi/screens/admin/organization_management_screen.dart';
import 'package:ssg_digi/screens/admin/department_management_screen.dart';
import 'package:ssg_digi/screens/events/event_management_screen.dart';
import 'package:ssg_digi/screens/clearance/clearance_approval_screen.dart';
import 'package:ssg_digi/screens/messages/messages_screen.dart';
import 'package:ssg_digi/screens/profile/profile_screen.dart';
import 'package:ssg_digi/widgets/dashboard_card.dart';

class SsgAdminDashboard extends StatefulWidget {
  const SsgAdminDashboard({super.key});

  @override
  State<SsgAdminDashboard> createState() => _SsgAdminDashboardState();
}

class _SsgAdminDashboardState extends State<SsgAdminDashboard> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const SsgAdminHomeScreen(),
    const UserManagementScreen(),
    const EventManagementScreen(),
    const ClearanceApprovalScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Clearance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class SsgAdminHomeScreen extends StatelessWidget {
  const SsgAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSG Admin Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          if (user == null) return const Center(child: CircularProgressIndicator());
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, SSG Admin ${user.fullName}!',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Supreme Student Government Administration',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Management Actions
                const Text(
                  'Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    DashboardCard(
                      title: 'User Management',
                      icon: Icons.people,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UserManagementScreen(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Organizations',
                      icon: Icons.business,
                      color: Colors.green,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OrganizationManagementScreen(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Departments',
                      icon: Icons.school,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DepartmentManagementScreen(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Events',
                      icon: Icons.event,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EventManagementScreen(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Clearances',
                      icon: Icons.assignment_turned_in,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ClearanceApprovalScreen(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Messages',
                      icon: Icons.message,
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MessagesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Statistics Cards
                const Text(
                  'Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.people,
                                size: 32,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Total Students',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<int>(
                                future: _getTotalStudents(),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data?.toString() ?? '0',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.event,
                                size: 32,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Active Events',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<int>(
                                future: _getActiveEvents(),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data?.toString() ?? '0',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<int> _getTotalStudents() async {
    // This would typically fetch from Firestore
    return 1250; // Mock data
  }

  Future<int> _getActiveEvents() async {
    // This would typically fetch from Firestore
    return 8; // Mock data
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/event_provider.dart';
import 'package:ssg_digi/providers/clearance_provider.dart';
import 'package:ssg_digi/providers/notification_provider.dart';
import 'package:ssg_digi/screens/events/events_screen.dart';
import 'package:ssg_digi/screens/clearance/clearance_screen.dart';
import 'package:ssg_digi/screens/messages/messages_screen.dart';
import 'package:ssg_digi/screens/profile/profile_screen.dart';
import 'package:ssg_digi/screens/qr/qr_code_screen.dart';
import 'package:ssg_digi/widgets/dashboard_card.dart';
import 'package:ssg_digi/widgets/notification_badge.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const StudentHomeScreen(),
    const EventsScreen(),
    const ClearanceScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final clearanceProvider = Provider.of<ClearanceProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      await Future.wait([
        eventProvider.fetchEvents(upcomingOnly: true),
        clearanceProvider.fetchClearances(studentId: authProvider.user!.id),
        clearanceProvider.fetchUnifiedClearance(authProvider.user!.id),
        notificationProvider.fetchNotifications(userId: authProvider.user!.id),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.event),
                label: 'Events',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.assignment),
                label: 'Clearance',
              ),
              BottomNavigationBarItem(
                icon: NotificationBadge(
                  count: notificationProvider.unreadCount,
                  child: const Icon(Icons.message),
                ),
                label: 'Messages',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          );
        },
      ),
    );
  }
}

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSG Digi'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return IconButton(
                icon: NotificationBadge(
                  count: notificationProvider.unreadCount,
                  child: const Icon(Icons.notifications),
                ),
                onPressed: () {
                  // Navigate to notifications screen
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          if (user == null) return const Center(child: CircularProgressIndicator());
          
          return RefreshIndicator(
            onRefresh: () async {
              // Refresh data
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user.fullName}!',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Student ID: ${user.studentId}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'Department: ${user.department}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (user.points > 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Sanction Points: ${user.points}',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quick Actions
                  const Text(
                    'Quick Actions',
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
                        title: 'My QR Code',
                        icon: Icons.qr_code,
                        color: Colors.blue,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => QrCodeScreen(user: user),
                            ),
                          );
                        },
                      ),
                      DashboardCard(
                        title: 'Upcoming Events',
                        icon: Icons.event,
                        color: Colors.green,
                        onTap: () {
                          // Navigate to events
                        },
                      ),
                      DashboardCard(
                        title: 'Request Clearance',
                        icon: Icons.assignment,
                        color: Colors.orange,
                        onTap: () {
                          // Navigate to clearance request
                        },
                      ),
                      DashboardCard(
                        title: 'Send Message',
                        icon: Icons.message,
                        color: Colors.purple,
                        onTap: () {
                          // Navigate to messages
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Recent Events
                  Consumer<EventProvider>(
                    builder: (context, eventProvider, child) {
                      if (eventProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final upcomingEvents = eventProvider.events.take(3).toList();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upcoming Events',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          if (upcomingEvents.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No upcoming events'),
                              ),
                            )
                          else
                            ...upcomingEvents.map((event) => Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: event.type == EventType.ssg
                                      ? Colors.blue
                                      : event.type == EventType.department
                                          ? Colors.green
                                          : Colors.orange,
                                  child: Icon(
                                    Icons.event,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(event.title),
                                subtitle: Text(
                                  '${event.location} • ${event.startDate.day}/${event.startDate.month}/${event.startDate.year}',
                                ),
                                trailing: event.isMandatory
                                    ? const Chip(
                                        label: Text('Mandatory'),
                                        backgroundColor: Colors.red,
                                        labelStyle: TextStyle(color: Colors.white),
                                      )
                                    : null,
                                onTap: () {
                                  // Navigate to event details
                                },
                              ),
                            )),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

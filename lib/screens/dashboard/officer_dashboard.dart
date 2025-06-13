import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/event_provider.dart';
import 'package:ssg_digi/screens/attendance/attendance_scanner_screen.dart';
import 'package:ssg_digi/screens/attendance/attendance_records_screen.dart';
import 'package:ssg_digi/screens/events/events_screen.dart';
import 'package:ssg_digi/screens/profile/profile_screen.dart';
import 'package:ssg_digi/widgets/dashboard_card.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const OfficerHomeScreen(),
    const EventsScreen(),
    const AttendanceRecordsScreen(),
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
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Records',
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

class OfficerHomeScreen extends StatelessWidget {
  const OfficerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Dashboard'),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, Officer ${user.fullName}!',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Department: ${user.department}',
                          style: const TextStyle(color: Colors.grey),
                        ),
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
                      title: 'Scan QR Code',
                      icon: Icons.qr_code_scanner,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AttendanceScannerScreen(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Attendance Records',
                      icon: Icons.list_alt,
                      color: Colors.green,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AttendanceRecordsScreen(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'My Events',
                      icon: Icons.event,
                      color: Colors.orange,
                      onTap: () {
                        // Navigate to assigned events
                      },
                    ),
                    DashboardCard(
                      title: 'Submit Records',
                      icon: Icons.upload,
                      color: Colors.purple,
                      onTap: () {
                        // Navigate to submit records
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Assigned Events
                Consumer<EventProvider>(
                  builder: (context, eventProvider, child) {
                    if (eventProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    // Filter events where user is an officer
                    final assignedEvents = eventProvider.events
                        .where((event) => event.officersInCharge.contains(user.id))
                        .take(3)
                        .toList();
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Events',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        if (assignedEvents.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No assigned events'),
                            ),
                          )
                        else
                          ...assignedEvents.map((event) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: event.type == EventType.ssg
                                    ? Colors.blue
                                    : event.type == EventType.department
                                        ? Colors.green
                                        : Colors.orange,
                                child: const Icon(
                                  Icons.event,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(event.title),
                              subtitle: Text(
                                '${event.location} • ${event.startDate.day}/${event.startDate.month}/${event.startDate.year}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.qr_code_scanner),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AttendanceScannerScreen(
                                        eventId: event.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
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
          );
        },
      ),
    );
  }
}

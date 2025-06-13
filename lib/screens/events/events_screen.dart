import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/event_provider.dart';
import 'package:ssg_digi/models/event_model.dart';
import 'package:ssg_digi/screens/events/event_details_screen.dart';
import 'package:ssg_digi/screens/events/event_management_screen.dart';
import 'package:intl/intl.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEvents();
  }
  
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });
    
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    await eventProvider.fetchEvents();
    
    setState(() {
      _isLoading = false;
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final bool canCreateEvents = user != null && 
        (user.role == UserRole.ssgAdmin || 
         user.role == UserRole.departmentAdmin || 
         user.role == UserRole.clubAdmin);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'All'),
          ],
        ),
        actions: [
          if (canCreateEvents)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EventManagementScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: TabBarView(
          controller: _tabController,
          children: [
            // Upcoming Events
            _buildEventList(
              (events) => events.where((e) => e.startDate.isAfter(DateTime.now())).toList(),
            ),
            
            // Past Events
            _buildEventList(
              (events) => events.where((e) => e.endDate.isBefore(DateTime.now())).toList(),
            ),
            
            // All Events
            _buildEventList((events) => events),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEventList(List<EventModel> Function(List<EventModel>) filter) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final filteredEvents = filter(eventProvider.events);
        
        if (filteredEvents.isEmpty) {
          return const Center(
            child: Text('No events found'),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredEvents.length,
          itemBuilder: (context, index) {
            final event = filteredEvents[index];
            return _buildEventCard(event);
          },
        );
      },
    );
  }
  
  Widget _buildEventCard(EventModel event) {
    final now = DateTime.now();
    final isOngoing = event.startDate.isBefore(now) && event.endDate.isAfter(now);
    final isPast = event.endDate.isBefore(now);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailsScreen(eventId: event.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image or Color Banner
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: _getEventTypeColor(event.type),
                image: event.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(event.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  // Event Type Badge
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getEventTypeText(event.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Status Badge
                  if (isOngoing || isPast || event.isMandatory)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isOngoing
                              ? Colors.green.withOpacity(0.9)
                              : isPast
                                  ? Colors.grey.withOpacity(0.9)
                                  : event.isMandatory
                                      ? Colors.red.withOpacity(0.9)
                                      : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          isOngoing
                              ? 'Ongoing'
                              : isPast
                                  ? 'Completed'
                                  : event.isMandatory
                                      ? 'Mandatory'
                                      : '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Event Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('MMM d, yyyy').format(event.startDate)} • ${DateFormat('h:mm a').format(event.startDate)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        event.location,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Organized by: ${event.organizerName}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getEventTypeColor(EventType type) {
    switch (type) {
      case EventType.ssg:
        return Colors.blue;
      case EventType.department:
        return Colors.green;
      case EventType.club:
        return Colors.orange;
    }
  }
  
  String _getEventTypeText(EventType type) {
    switch (type) {
      case EventType.ssg:
        return 'SSG Event';
      case EventType.department:
        return 'Department Event';
      case EventType.club:
        return 'Club Event';
    }
  }
}

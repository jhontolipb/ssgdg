import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/event_provider.dart';
import 'package:ssg_digi/models/event_model.dart';
import 'package:ssg_digi/screens/events/event_management_screen.dart';
import 'package:ssg_digi/screens/attendance/attendance_scanner_screen.dart';
import 'package:ssg_digi/screens/attendance/attendance_records_screen.dart';
import 'package:ssg_digi/widgets/loading_overlay.dart';
import 'package:intl/intl.dart';

class EventDetailsScreen extends StatefulWidget {
  final String eventId;

  const EventDetailsScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _isLoading = true;
  EventModel? _event;
  List<AttendanceModel> _attendances = [];

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
  }

  Future<void> _loadEventDetails() async {
    setState(() {
      _isLoading = true;
    });

    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    // Load event details
    _event = await eventProvider.getEventById(widget.eventId);
    
    if (_event != null) {
      // Load attendance records
      await eventProvider.fetchAttendances(eventId: widget.eventId);
      _attendances = eventProvider.attendances;
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    
    // Check if user can edit this event
    final bool canEdit = user != null && (
      user.role == UserRole.ssgAdmin ||
      (user.role == UserRole.departmentAdmin && _event?.type == EventType.department) ||
      (user.role == UserRole.clubAdmin && _event?.type == EventType.club && _event?.organizerId == user.id)
    );
    
    // Check if user is an officer for this event
    final bool isOfficer = user != null && _event != null && 
        _event!.officersInCharge.contains(user.id);
    
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        body: _event == null
            ? const Center(child: Text('Event not found'))
            : CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(_event!.title),
                      background: _event!.imageUrl != null
                          ? Image.network(
                              _event!.imageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: _getEventTypeColor(_event!.type),
                            ),
                    ),
                    actions: [
                      if (canEdit)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EventManagementScreen(
                                  eventId: _event!.id,
                                ),
                              ),
                            ).then((_) => _loadEventDetails());
                          },
                        ),
                    ],
                  ),
                  
                  // Event Details
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event Type and Status
                          Row(
                            children: [
                              _buildChip(
                                _getEventTypeText(_event!.type),
                                _getEventTypeColor(_event!.type),
                              ),
                              const SizedBox(width: 8),
                              if (_event!.isMandatory)
                                _buildChip('Mandatory', Colors.red),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Date and Time
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Date',
                            DateFormat('EEEE, MMMM d, yyyy').format(_event!.startDate),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.access_time,
                            'Time',
                            '${DateFormat('h:mm a').format(_event!.startDate)} - ${DateFormat('h:mm a').format(_event!.endDate)}',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.location_on,
                            'Location',
                            _event!.location,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.business,
                            'Organizer',
                            _event!.organizerName,
                          ),
                          if (_event!.isMandatory) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.warning,
                              'Sanction Points',
                              _event!.sanctionPoints.toString(),
                              valueColor: Colors.red,
                            ),
                          ],
                          const SizedBox(height: 24),
                          
                          // Description
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_event!.description),
                          const SizedBox(height: 24),
                          
                          // Officer Actions
                          if (isOfficer) ...[
                            const Text(
                              'Officer Actions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text('Scan Attendance'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AttendanceScannerScreen(
                                            eventId: _event!.id,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.list_alt),
                                    label: const Text('View Records'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AttendanceRecordsScreen(
                                            eventId: _event!.id,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // Attendance Statistics
                          if (canEdit || isOfficer) ...[
                            const Text(
                              'Attendance Statistics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildAttendanceStats(),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Column(
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
      ],
    );
  }
  
  Widget _buildAttendanceStats() {
    // Count attendance by status
    int presentCount = 0;
    int absentCount = 0;
    int lateCount = 0;
    int excusedCount = 0;
    
    for (final attendance in _attendances) {
      switch (attendance.status) {
        case AttendanceStatus.present:
          presentCount++;
          break;
        case AttendanceStatus.absent:
          absentCount++;
          break;
        case AttendanceStatus.late:
          lateCount++;
          break;
        case AttendanceStatus.excused:
          excusedCount++;
          break;
        default:
          break;
      }
    }
    
    final total = _attendances.length;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Attendees:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  total.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatRow('Present', presentCount, total, Colors.green),
            const SizedBox(height: 8),
            _buildStatRow('Late', lateCount, total, Colors.orange),
            const SizedBox(height: 8),
            _buildStatRow('Absent', absentCount, total, Colors.red),
            const SizedBox(height: 8),
            _buildStatRow('Excused', excusedCount, total, Colors.blue),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$count ($percentage%)'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: total > 0 ? count / total : 0,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
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

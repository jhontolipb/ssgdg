import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/event_provider.dart';
import 'package:ssg_digi/models/event_model.dart';
import 'package:ssg_digi/widgets/loading_overlay.dart';
import 'package:intl/intl.dart';

class AttendanceRecordsScreen extends StatefulWidget {
  final String? eventId;

  const AttendanceRecordsScreen({
    super.key,
    this.eventId,
  });

  @override
  State<AttendanceRecordsScreen> createState() => _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> {
  EventModel? _selectedEvent;
  List<EventModel> _assignedEvents = [];
  bool _isLoading = true;
  String? _searchQuery;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      await eventProvider.fetchEvents();
      
      setState(() {
        _assignedEvents = eventProvider.events
            .where((event) => event.officersInCharge.contains(authProvider.user!.id))
            .toList();
            
        if (widget.eventId != null) {
          _selectedEvent = _assignedEvents.firstWhere(
            (event) => event.id == widget.eventId,
            orElse: () => _assignedEvents.isNotEmpty ? _assignedEvents.first : null,
          );
        } else if (_assignedEvents.isNotEmpty) {
          _selectedEvent = _assignedEvents.first;
        }
      });
      
      if (_selectedEvent != null) {
        await eventProvider.fetchAttendances(eventId: _selectedEvent!.id);
      }
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onEventChanged(String? eventId) async {
    if (eventId == null) return;
    
    setState(() {
      _isLoading = true;
      _selectedEvent = _assignedEvents.firstWhere(
        (event) => event.id == eventId,
      );
    });
    
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    await eventProvider.fetchAttendances(eventId: eventId);
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateAttendanceStatus(String attendanceId, AttendanceStatus status) async {
    setState(() {
      _isLoading = true;
    });
    
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    await eventProvider.updateAttendanceStatus(
      attendanceId: attendanceId,
      status: status,
    );
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Records'),
        ),
        body: Column(
          children: [
            // Event Selection
            if (_assignedEvents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Event:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedEvent?.id,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: _assignedEvents.map((event) {
                        return DropdownMenuItem(
                          value: event.id,
                          child: Text(event.title),
                        );
                      }).toList(),
                      onChanged: _onEventChanged,
                    ),
                  ],
                ),
              )
            else if (!_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'You are not assigned to any events.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              
            // Search Bar
            if (_selectedEvent != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or ID',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: _searchQuery != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = null;
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.isNotEmpty ? value.toLowerCase() : null;
                    });
                  },
                ),
              ),
              
            // Attendance List
            if (_selectedEvent != null)
              Expanded(
                child: Consumer<EventProvider>(
                  builder: (context, eventProvider, child) {
                    if (eventProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final attendances = eventProvider.attendances;
                    
                    // Filter by search query if provided
                    final filteredAttendances = _searchQuery != null
                        ? attendances.where((a) =>
                            a.studentName.toLowerCase().contains(_searchQuery!) ||
                            a.studentId.toLowerCase().contains(_searchQuery!))
                            .toList()
                        : attendances;
                    
                    if (filteredAttendances.isEmpty) {
                      return const Center(
                        child: Text('No attendance records found'),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredAttendances.length,
                      itemBuilder: (context, index) {
                        final attendance = filteredAttendances[index];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            attendance.studentName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'ID: ${attendance.studentId}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            'Department: ${attendance.department}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildStatusChip(attendance.status),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Time In:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            attendance.timeIn != null
                                                ? DateFormat('hh:mm a').format(attendance.timeIn!)
                                                : 'Not recorded',
                                            style: TextStyle(
                                              color: attendance.timeIn != null
                                                  ? Colors.black
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Time Out:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            attendance.timeOut != null
                                                ? DateFormat('hh:mm a').format(attendance.timeOut!)
                                                : 'Not recorded',
                                            style: TextStyle(
                                              color: attendance.timeOut != null
                                                  ? Colors.black
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatusButton(
                                      'Present',
                                      Icons.check_circle,
                                      Colors.green,
                                      attendance.status == AttendanceStatus.present,
                                      () => _updateAttendanceStatus(
                                        attendance.id,
                                        AttendanceStatus.present,
                                      ),
                                    ),
                                    _buildStatusButton(
                                      'Late',
                                      Icons.watch_later,
                                      Colors.orange,
                                      attendance.status == AttendanceStatus.late,
                                      () => _updateAttendanceStatus(
                                        attendance.id,
                                        AttendanceStatus.late,
                                      ),
                                    ),
                                    _buildStatusButton(
                                      'Absent',
                                      Icons.cancel,
                                      Colors.red,
                                      attendance.status == AttendanceStatus.absent,
                                      () => _updateAttendanceStatus(
                                        attendance.id,
                                        AttendanceStatus.absent,
                                      ),
                                    ),
                                    _buildStatusButton(
                                      'Excused',
                                      Icons.medical_services,
                                      Colors.blue,
                                      attendance.status == AttendanceStatus.excused,
                                      () => _updateAttendanceStatus(
                                        attendance.id,
                                        AttendanceStatus.excused,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(AttendanceStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case AttendanceStatus.present:
        color = Colors.green;
        label = 'Present';
        break;
      case AttendanceStatus.absent:
        color = Colors.red;
        label = 'Absent';
        break;
      case AttendanceStatus.late:
        color = Colors.orange;
        label = 'Late';
        break;
      case AttendanceStatus.excused:
        color = Colors.blue;
        label = 'Excused';
        break;
      default:
        color = Colors.grey;
        label = 'Pending';
    }
    
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

  Widget _buildStatusButton(
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

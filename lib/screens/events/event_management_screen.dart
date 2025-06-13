import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/event_provider.dart';
import 'package:ssg_digi/providers/organization_provider.dart';
import 'package:ssg_digi/models/event_model.dart';
import 'package:ssg_digi/models/organization_model.dart';
import 'package:ssg_digi/widgets/loading_overlay.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EventManagementScreen extends StatefulWidget {
  final String? eventId;

  const EventManagementScreen({
    super.key,
    this.eventId,
  });

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  
  EventType _eventType = EventType.ssg;
  OrganizationModel? _selectedOrganization;
  List<OrganizationModel> _organizations = [];
  List<String> _selectedOfficers = [];
  List<Map<String, dynamic>> _availableOfficers = [];
  
  int _sanctionPoints = 0;
  bool _isMandatory = false;
  
  File? _imageFile;
  String? _existingImageUrl;
  
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final organizationProvider = Provider.of<OrganizationProvider>(context, listen: false);
      
      // Load organizations based on user role
      await organizationProvider.fetchOrganizations();
      
      if (authProvider.user != null) {
        switch (authProvider.user!.role) {
          case UserRole.ssgAdmin:
            _organizations = organizationProvider.organizations;
            break;
          case UserRole.departmentAdmin:
            _organizations = organizationProvider.organizations
                .where((org) => org.type == OrganizationType.department && 
                                org.adminId == authProvider.user!.id)
                .toList();
            _eventType = EventType.department;
            break;
          case UserRole.clubAdmin:
            _organizations = organizationProvider.organizations
                .where((org) => org.type == OrganizationType.club && 
                                org.adminId == authProvider.user!.id)
                .toList();
            _eventType = EventType.club;
            break;
          default:
            _organizations = [];
        }
      }
      
      // Select first organization by default if available
      if (_organizations.isNotEmpty) {
        _selectedOrganization = _organizations.first;
        await _loadOfficers();
      }
      
      // If editing an existing event, load its data
      if (widget.eventId != null) {
        final event = await eventProvider.getEventById(widget.eventId!);
        if (event != null) {
          _titleController.text = event.title;
          _descriptionController.text = event.description;
          _locationController.text = event.location;
          
          _startDate = event.startDate;
          _startTime = TimeOfDay.fromDateTime(event.startDate);
          _endDate = event.endDate;
          _endTime = TimeOfDay.fromDateTime(event.endDate);
          
          _eventType = event.type;
          _sanctionPoints = event.sanctionPoints;
          _isMandatory = event.isMandatory;
          _existingImageUrl = event.imageUrl;
          
          // Find and select the organization
          if (_organizations.isNotEmpty) {
            final org = _organizations.firstWhere(
              (org) => org.id == event.organizerId,
              orElse: () => _organizations.first,
            );
            _selectedOrganization = org;
            await _loadOfficers();
          }
          
          _selectedOfficers = List<String>.from(event.officersInCharge);
        }
      }
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    }
  }

  Future<void> _loadOfficers() async {
    if (_selectedOrganization == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Get officers from the selected organization
      final officerIds = _selectedOrganization!.officersInCharge;
      
      _availableOfficers = [];
      
      for (final officerId in officerIds) {
        final officer = await authProvider.getUserById(officerId);
        if (officer != null) {
          _availableOfficers.add({
            'id': officer.id,
            'name': officer.fullName,
          });
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (pickedDate != null) {
      setState(() {
        _startDate = pickedDate;
        
        // If end date is before start date, update it
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectStartTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    
    if (pickedTime != null) {
      setState(() {
        _startTime = pickedTime;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    
    if (pickedTime != null) {
      setState(() {
        _endTime = pickedTime;
      });
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOrganization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an organization')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      
      // Upload image if selected
      String? imageUrl = _existingImageUrl;
      if (_imageFile != null) {
        // In a real app, you would upload the image to Firebase Storage
        // and get the download URL
        // imageUrl = await _uploadImage(_imageFile!);
      }
      
      final startDateTime = _combineDateAndTime(_startDate, _startTime);
      final endDateTime = _combineDateAndTime(_endDate, _endTime);
      
      if (widget.eventId == null) {
        // Create new event
        await eventProvider.createEvent(
          title: _titleController.text,
          description: _descriptionController.text,
          startDate: startDateTime,
          endDate: endDateTime,
          location: _locationController.text,
          type: _eventType,
          organizerId: _selectedOrganization!.id,
          organizerName: _selectedOrganization!.name,
          officersInCharge: _selectedOfficers,
          sanctionPoints: _sanctionPoints,
          isMandatory: _isMandatory,
          imageUrl: imageUrl,
        );
      } else {
        // Update existing event
        await eventProvider.updateEvent(
          id: widget.eventId!,
          title: _titleController.text,
          description: _descriptionController.text,
          startDate: startDateTime,
          endDate: endDateTime,
          location: _locationController.text,
          officersInCharge: _selectedOfficers,
          sanctionPoints: _sanctionPoints,
          isMandatory: _isMandatory,
          imageUrl: imageUrl,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.eventId == null
                ? 'Event created successfully'
                : 'Event updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
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
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    
    // Determine if user can change event type
    final bool canChangeEventType = user != null && user.role == UserRole.ssgAdmin;
    
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.eventId == null ? 'Create Event' : 'Edit Event'),
          actions: [
            TextButton(
              onPressed: _saveEvent,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: !_isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Image
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              image: _imageFile != null
                                  ? DecorationImage(
                                      image: FileImage(_imageFile!),
                                      fit: BoxFit.cover,
                                    )
                                  : _existingImageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_existingImageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                            ),
                            child: _imageFile == null && _existingImageUrl == null
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Add Event Image',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Event Type
                      if (canChangeEventType) ...[
                        const Text(
                          'Event Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<EventType>(
                          segments: const [
                            ButtonSegment<EventType>(
                              value: EventType.ssg,
                              label: Text('SSG'),
                            ),
                            ButtonSegment<EventType>(
                              value: EventType.department,
                              label: Text('Department'),
                            ),
                            ButtonSegment<EventType>(
                              value: EventType.club,
                              label: Text('Club'),
                            ),
                          ],
                          selected: {_eventType},
                          onSelectionChanged: (Set<EventType> newSelection) {
                            setState(() {
                              _eventType = newSelection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Organization Selection
                      if (_organizations.isNotEmpty) ...[
                        const Text(
                          'Organization',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedOrganization?.id,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          items: _organizations.map((org) {
                            return DropdownMenuItem(
                              value: org.id,
                              child: Text(org.name),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              setState(() {
                                _selectedOrganization = _organizations.firstWhere(
                                  (org) => org.id == value,
                                );
                                _selectedOfficers.clear();
                              });
                              await _loadOfficers();
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Event Title
                      const Text(
                        'Event Title',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter event title',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter event title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Event Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter event description',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter event description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Location
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter event location',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter event location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Date and Time
                      const Text(
                        'Date & Time',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Start Date and Time
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Date'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _selectStartDate,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today),
                                        const SizedBox(width: 8),
                                        Text(DateFormat('MMM d, yyyy').format(_startDate)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Time'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _selectStartTime,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time),
                                        const SizedBox(width: 8),
                                        Text(_startTime.format(context)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // End Date and Time
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Date'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _selectEndDate,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today),
                                        const SizedBox(width: 8),
                                        Text(DateFormat('MMM d, yyyy').format(_endDate)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Time'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _selectEndTime,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time),
                                        const SizedBox(width: 8),
                                        Text(_endTime.format(context)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Officers in Charge
                      if (_availableOfficers.isNotEmpty) ...[
                        const Text(
                          'Officers in Charge',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: _availableOfficers.map((officer) {
                              final isSelected = _selectedOfficers.contains(officer['id']);
                              return CheckboxListTile(
                                title: Text(officer['name']),
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedOfficers.add(officer['id']);
                                    } else {
                                      _selectedOfficers.remove(officer['id']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Mandatory Event Toggle
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mandatory Event',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Students will receive sanctions for non-attendance',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isMandatory,
                            onChanged: (value) {
                              setState(() {
                                _isMandatory = value;
                                if (!value) {
                                  _sanctionPoints = 0;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      
                      // Sanction Points
                      if (_isMandatory) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Sanction Points',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: _sanctionPoints.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter sanction points',
                            suffixText: 'points',
                          ),
                          onChanged: (value) {
                            _sanctionPoints = int.tryParse(value) ?? 0;
                          },
                          validator: (value) {
                            if (_isMandatory && (value == null || value.isEmpty)) {
                              return 'Please enter sanction points';
                            }
                            final points = int.tryParse(value ?? '');
                            if (_isMandatory && (points == null || points < 0)) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 32),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveEvent,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            widget.eventId == null ? 'Create Event' : 'Update Event',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

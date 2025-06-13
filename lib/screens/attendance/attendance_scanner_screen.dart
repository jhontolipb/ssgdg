import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/event_provider.dart';
import 'package:ssg_digi/models/event_model.dart';
import 'package:ssg_digi/widgets/loading_overlay.dart';
import 'dart:io';

class AttendanceScannerScreen extends StatefulWidget {
  final String? eventId;

  const AttendanceScannerScreen({
    super.key,
    this.eventId,
  });

  @override
  State<AttendanceScannerScreen> createState() => _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  String? _scanResult;
  String? _errorMessage;
  EventModel? _selectedEvent;
  List<EventModel> _assignedEvents = [];
  bool _isLoading = true;
  bool _isScanningIn = true; // true for time in, false for time out

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
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
        
        _isLoading = false;
      });
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null) {
        _processQrCode(scanData.code!);
      }
    });
  }

  Future<void> _processQrCode(String qrData) async {
    if (_isProcessing || _selectedEvent == null) return;
    
    setState(() {
      _isProcessing = true;
      _scanResult = null;
      _errorMessage = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      
      // Get student data from QR code
      // In a real app, you might want to verify this data with the server
      // or use a more secure format for the QR code
      
      // For now, we'll assume the QR code contains the student ID
      final studentId = qrData;
      
      // Get student details from Firestore
      final studentDoc = await Provider.of<AuthProvider>(context, listen: false)
          .getUserById(studentId);
          
      if (studentDoc == null) {
        setState(() {
          _errorMessage = 'Invalid QR code. Student not found.';
          _isProcessing = false;
        });
        return;
      }
      
      // Record attendance
      final success = await eventProvider.recordAttendance(
        eventId: _selectedEvent!.id,
        studentId: studentDoc.id,
        studentName: studentDoc.fullName,
        department: studentDoc.department,
        status: AttendanceStatus.present,
        recordedBy: authProvider.user!.id,
        timeIn: _isScanningIn ? DateTime.now() : null,
        timeOut: !_isScanningIn ? DateTime.now() : null,
      );
      
      if (success) {
        setState(() {
          _scanResult = 'Attendance recorded for ${studentDoc.fullName}';
        });
      } else {
        setState(() {
          _errorMessage = eventProvider.error ?? 'Failed to record attendance';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      // Add a delay before allowing another scan
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan Attendance'),
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
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedEvent = _assignedEvents.firstWhere(
                              (event) => event.id == value,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Time In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isScanningIn ? Colors.blue : Colors.grey.shade300,
                              foregroundColor: _isScanningIn ? Colors.white : Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                _isScanningIn = true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.logout),
                            label: const Text('Time Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: !_isScanningIn ? Colors.blue : Colors.grey.shade300,
                              foregroundColor: !_isScanningIn ? Colors.white : Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                _isScanningIn = false;
                              });
                            },
                          ),
                        ),
                      ],
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
              
            // QR Scanner
            if (_selectedEvent != null)
              Expanded(
                flex: 5,
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.blue,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 300,
                  ),
                ),
              ),
              
            // Result Display
            Expanded(
              flex: 1,
              child: Center(
                child: _scanResult != null
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _scanResult!,
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Text(
                            'Scan a student QR code',
                            style: TextStyle(fontSize: 16),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/clearance_provider.dart';
import 'package:ssg_digi/providers/organization_provider.dart';
import 'package:ssg_digi/models/clearance_model.dart';
import 'package:ssg_digi/widgets/loading_overlay.dart';
import 'package:intl/intl.dart';

class ClearanceApprovalScreen extends StatefulWidget {
  const ClearanceApprovalScreen({super.key});

  @override
  State<ClearanceApprovalScreen> createState() => _ClearanceApprovalScreenState();
}

class _ClearanceApprovalScreenState extends State<ClearanceApprovalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _searchQuery;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clearanceProvider = Provider.of<ClearanceProvider>(context, listen: false);
    final organizationProvider = Provider.of<OrganizationProvider>(context, listen: false);

    if (authProvider.user != null) {
      // Load organizations managed by this user
      await organizationProvider.fetchOrganizations(adminId: authProvider.user!.id);
      
      // Load clearances for these organizations
      final organizations = organizationProvider.organizations;
      if (organizations.isNotEmpty) {
        for (final org in organizations) {
          await clearanceProvider.fetchClearances(organizationId: org.id);
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _approveClearance(ClearanceModel clearance) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clearanceProvider = Provider.of<ClearanceProvider>(context, listen: false);

    if (authProvider.user != null) {
      setState(() {
        _isLoading = true;
      });

      final success = await clearanceProvider.approveClearance(
        clearanceId: clearance.id,
        approvedBy: authProvider.user!.id,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clearance approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(clearanceProvider.error ?? 'Failed to approve clearance'),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectClearance(ClearanceModel clearance) async {
    final remarksController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Clearance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject the clearance for ${clearance.studentName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(remarksController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      final clearanceProvider = Provider.of<ClearanceProvider>(context, listen: false);
      final success = await clearanceProvider.rejectClearance(
        clearanceId: clearance.id,
        remarks: result,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clearance rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(clearanceProvider.error ?? 'Failed to reject clearance'),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }

    remarksController.dispose();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Clearance Approval'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by student name or ID',
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
            
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildClearancesList(ClearanceStatus.pending),
                  _buildClearancesList(ClearanceStatus.approved),
                  _buildClearancesList(ClearanceStatus.rejected),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearancesList(ClearanceStatus status) {
    return Consumer<ClearanceProvider>(
      builder: (context, clearanceProvider, child) {
        if (clearanceProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final clearances = clearanceProvider.clearances
            .where((c) => c.status == status)
            .toList();

        // Filter by search query if provided
        final filteredClearances = _searchQuery != null
            ? clearances.where((c) =>
                c.studentName.toLowerCase().contains(_searchQuery!) ||
                c.studentId.toLowerCase().contains(_searchQuery!))
                .toList()
            : clearances;

        if (filteredClearances.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getStatusIcon(status),
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${status.toString().split('.').last} clearances',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredClearances.length,
            itemBuilder: (context, index) {
              final clearance = filteredClearances[index];
              return _buildClearanceCard(clearance);
            },
          ),
        );
      },
    );
  }

  Widget _buildClearanceCard(ClearanceModel clearance) {
    Color statusColor;
    IconData statusIcon;

    switch (clearance.status) {
      case ClearanceStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case ClearanceStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case ClearanceStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clearance.studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${clearance.studentId}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        'Department: ${clearance.department}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    clearance.status.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Organization: ${clearance.organizationName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Type: ${_getClearanceTypeText(clearance.type)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Requested: ${DateFormat('MMM d, yyyy • h:mm a').format(clearance.createdAt)}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (clearance.approvedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Approved: ${DateFormat('MMM d, yyyy • h:mm a').format(clearance.approvedAt!)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            if (clearance.remarks != null && clearance.remarks!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remarks:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(clearance.remarks!),
                  ],
                ),
              ),
            ],
            
            // Action Buttons for Pending Clearances
            if (clearance.status == ClearanceStatus.pending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _approveClearance(clearance),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _rejectClearance(clearance),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(ClearanceStatus status) {
    switch (status) {
      case ClearanceStatus.pending:
        return Icons.pending;
      case ClearanceStatus.approved:
        return Icons.check_circle;
      case ClearanceStatus.rejected:
        return Icons.cancel;
    }
  }

  String _getClearanceTypeText(ClearanceType type) {
    switch (type) {
      case ClearanceType.ssg:
        return 'SSG Clearance';
      case ClearanceType.department:
        return 'Department Clearance';
      case ClearanceType.club:
        return 'Club Clearance';
    }
  }
}

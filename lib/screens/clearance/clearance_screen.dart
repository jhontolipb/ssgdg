import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/clearance_provider.dart';
import 'package:ssg_digi/providers/organization_provider.dart';
import 'package:ssg_digi/models/clearance_model.dart';
import 'package:ssg_digi/models/organization_model.dart';
import 'package:ssg_digi/screens/clearance/clearance_request_screen.dart';
import 'package:ssg_digi/widgets/loading_overlay.dart';
import 'package:intl/intl.dart';

class ClearanceScreen extends StatefulWidget {
  const ClearanceScreen({super.key});

  @override
  State<ClearanceScreen> createState() => _ClearanceScreenState();
}

class _ClearanceScreenState extends State<ClearanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clearanceProvider = Provider.of<ClearanceProvider>(context, listen: false);

    if (authProvider.user != null) {
      await Future.wait([
        clearanceProvider.fetchClearances(studentId: authProvider.user!.id),
        clearanceProvider.fetchUnifiedClearance(authProvider.user!.id),
      ]);
    }

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
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Clearance'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'My Clearances'),
              Tab(text: 'Unified Clearance'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ClearanceRequestScreen(),
                  ),
                ).then((_) => _loadData());
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildClearancesList(),
              _buildUnifiedClearance(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearancesList() {
    return Consumer<ClearanceProvider>(
      builder: (context, clearanceProvider, child) {
        if (clearanceProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final clearances = clearanceProvider.clearances;

        if (clearances.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No clearance requests yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to request clearance',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: clearances.length,
          itemBuilder: (context, index) {
            final clearance = clearances[index];
            return _buildClearanceCard(clearance);
          },
        );
      },
    );
  }

  Widget _buildClearanceCard(ClearanceModel clearance) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (clearance.status) {
      case ClearanceStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case ClearanceStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case ClearanceStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    clearance.organizationName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Type: ${_getClearanceTypeText(clearance.type)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Requested: ${DateFormat('MMM d, yyyy').format(clearance.createdAt)}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (clearance.approvedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Approved: ${DateFormat('MMM d, yyyy').format(clearance.approvedAt!)}',
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
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedClearance() {
    return Consumer<ClearanceProvider>(
      builder: (context, clearanceProvider, child) {
        if (clearanceProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final unifiedClearance = clearanceProvider.unifiedClearance;

        if (unifiedClearance == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No unified clearance available',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Request clearances from organizations first',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        final isComplete = unifiedClearance.ssgApproved &&
            unifiedClearance.departmentApproved &&
            unifiedClearance.pendingClubs.isEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        isComplete ? Icons.check_circle : Icons.pending,
                        size: 48,
                        color: isComplete ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isComplete ? 'Clearance Complete!' : 'Clearance In Progress',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isComplete ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isComplete
                            ? 'All clearances have been approved'
                            : 'Some clearances are still pending',
                        style: TextStyle(
                          color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                      if (isComplete && unifiedClearance.transactionCode != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Transaction Code:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                unifiedClearance.transactionCode!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Download Clearance'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            clearanceProvider.openClearanceDocument();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Clearance Details
              const Text(
                'Clearance Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // SSG Clearance
              _buildClearanceStatusTile(
                'Supreme Student Government',
                unifiedClearance.ssgApproved,
                Icons.account_balance,
              ),

              // Department Clearance
              _buildClearanceStatusTile(
                'Department (${unifiedClearance.department})',
                unifiedClearance.departmentApproved,
                Icons.school,
              ),

              // Club Clearances
              if (unifiedClearance.clubsApproved.isNotEmpty ||
                  unifiedClearance.pendingClubs.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Club Clearances',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Approved Clubs
                ...unifiedClearance.clubsApproved.map((clubId) =>
                    _buildClearanceStatusTile(
                      'Club: $clubId', // In a real app, you'd fetch the club name
                      true,
                      Icons.group,
                    )),

                // Pending Clubs
                ...unifiedClearance.pendingClubs.map((clubId) =>
                    _buildClearanceStatusTile(
                      'Club: $clubId', // In a real app, you'd fetch the club name
                      false,
                      Icons.group,
                    )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildClearanceStatusTile(String title, bool isApproved, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: isApproved ? Colors.green : Colors.orange,
        ),
        title: Text(title),
        trailing: Icon(
          isApproved ? Icons.check_circle : Icons.pending,
          color: isApproved ? Colors.green : Colors.orange,
        ),
        subtitle: Text(
          isApproved ? 'Approved' : 'Pending',
          style: TextStyle(
            color: isApproved ? Colors.green : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/providers/clearance_provider.dart';
import 'package:ssg_digi/providers/organization_provider.dart';
import 'package:ssg_digi/models/clearance_model.dart';
import 'package:ssg_digi/models/organization_model.dart';
import 'package:ssg_digi/widgets/loading_overlay.dart';

class ClearanceRequestScreen extends StatefulWidget {
  const ClearanceRequestScreen({super.key});

  @override
  State<ClearanceRequestScreen> createState() => _ClearanceRequestScreenState();
}

class _ClearanceRequestScreenState extends State<ClearanceRequestScreen> {
  bool _isLoading = false;
  List<OrganizationModel> _organizations = [];
  List<OrganizationModel> _availableOrganizations = [];

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final organizationProvider = Provider.of<OrganizationProvider>(context, listen: false);
      final clearanceProvider = Provider.of<ClearanceProvider>(context, listen: false);

      if (authProvider.user != null) {
        // Load all organizations
        await organizationProvider.fetchOrganizations();
        _organizations = organizationProvider.organizations;

        // Load existing clearances to filter out already requested ones
        await clearanceProvider.fetchClearances(studentId: authProvider.user!.id);
        final existingClearances = clearanceProvider.clearances;

        // Filter organizations based on user's department and clubs
        final user = authProvider.user!;
        _availableOrganizations = [];

        // Add SSG (always available)
        final ssgOrg = _organizations.where((org) => org.type == OrganizationType.ssg).firstOrNull;
        if (ssgOrg != null && !_hasExistingClearance(existingClearances, ssgOrg.id)) {
          _availableOrganizations.add(ssgOrg);
        }

        // Add user's department organization
        final departmentOrgs = _organizations.where((org) =>
            org.type == OrganizationType.department &&
            org.department == user.department).toList();
        for (final org in departmentOrgs) {
          if (!_hasExistingClearance(existingClearances, org.id)) {
            _availableOrganizations.add(org);
          }
        }

        // Add user's clubs
        final clubOrgs = _organizations.where((org) =>
            org.type == OrganizationType.club &&
            user.clubs.contains(org.name)).toList();
        for (final org in clubOrgs) {
          if (!_hasExistingClearance(existingClearances, org.id)) {
            _availableOrganizations.add(org);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _hasExistingClearance(List<ClearanceModel> clearances, String organizationId) {
    return clearances.any((clearance) =>
        clearance.organizationId == organizationId &&
        clearance.status != ClearanceStatus.rejected);
  }

  Future<void> _requestClearance(OrganizationModel organization) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final clearanceProvider = Provider.of<ClearanceProvider>(context, listen: false);

      if (authProvider.user != null) {
        final user = authProvider.user!;

        // Determine clearance type based on organization type
        ClearanceType type;
        switch (organization.type) {
          case OrganizationType.ssg:
            type = ClearanceType.ssg;
            break;
          case OrganizationType.department:
            type = ClearanceType.department;
            break;
          case OrganizationType.club:
            type = ClearanceType.club;
            break;
        }

        final success = await clearanceProvider.requestClearance(
          studentId: user.id,
          studentName: user.fullName,
          department: user.department,
          type: type,
          organizationId: organization.id,
          organizationName: organization.name,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Clearance request sent to ${organization.name}'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(clearanceProvider.error ?? 'Failed to request clearance'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Request Clearance'),
        ),
        body: _availableOrganizations.isEmpty && !_isLoading
            ? const Center(
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
                      'No clearances available to request',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You may have already requested all available clearances',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _availableOrganizations.length,
                itemBuilder: (context, index) {
                  final organization = _availableOrganizations[index];
                  return _buildOrganizationCard(organization);
                },
              ),
      ),
    );
  }

  Widget _buildOrganizationCard(OrganizationModel organization) {
    Color typeColor;
    IconData typeIcon;
    String typeText;

    switch (organization.type) {
      case OrganizationType.ssg:
        typeColor = Colors.blue;
        typeIcon = Icons.account_balance;
        typeText = 'SSG';
        break;
      case OrganizationType.department:
        typeColor = Colors.green;
        typeIcon = Icons.school;
        typeText = 'Department';
        break;
      case OrganizationType.club:
        typeColor = Colors.orange;
        typeIcon = Icons.group;
        typeText = 'Club';
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    typeIcon,
                    color: typeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organization.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: typeColor),
                        ),
                        child: Text(
                          typeText,
                          style: TextStyle(
                            color: typeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              organization.description,
              style: const TextStyle(color: Colors.grey),
            ),
            if (organization.department != null) ...[
              const SizedBox(height: 8),
              Text(
                'Department: ${organization.department}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Request Clearance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _requestClearance(organization),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

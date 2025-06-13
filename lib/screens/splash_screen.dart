import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssg_digi/providers/auth_provider.dart';
import 'package:ssg_digi/screens/auth/login_screen.dart';
import 'package:ssg_digi/screens/dashboard/student_dashboard.dart';
import 'package:ssg_digi/screens/dashboard/officer_dashboard.dart';
import 'package:ssg_digi/screens/dashboard/club_admin_dashboard.dart';
import 'package:ssg_digi/screens/dashboard/department_admin_dashboard.dart';
import 'package:ssg_digi/screens/dashboard/ssg_admin_dashboard.dart';
import 'package:ssg_digi/models/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Add a delay to show splash screen
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isAuthenticated) {
      _navigateToDashboard();
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToDashboard() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user == null) {
      _navigateToLogin();
      return;
    }
    
    Widget dashboard;
    
    switch (user.role) {
      case UserRole.student:
        dashboard = const StudentDashboard();
        break;
      case UserRole.officerInCharge:
        dashboard = const OfficerDashboard();
        break;
      case UserRole.clubAdmin:
        dashboard = const ClubAdminDashboard();
        break;
      case UserRole.departmentAdmin:
        dashboard = const DepartmentAdminDashboard();
        break;
      case UserRole.ssgAdmin:
        dashboard = const SsgAdminDashboard();
        break;
    }
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => dashboard),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/ssg_logo.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 24),
            const Text(
              'SSG Digi',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supreme Student Government\nDigital Management System',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

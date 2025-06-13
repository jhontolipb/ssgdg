import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ssg_digi/models/user_model.dart';
import 'package:uuid/uuid.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _firebaseUser;
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  User? get firebaseUser => _firebaseUser;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _firebaseUser != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((User? user) async {
      _firebaseUser = user;
      if (user != null) {
        await _fetchUserData();
      } else {
        _user = null;
      }
      notifyListeners();
    });
  }

  Future<void> _fetchUserData() async {
    try {
      _isLoading = true;
      notifyListeners();

      final doc = await _firestore.collection('users').doc(_firebaseUser!.uid).get();
      if (doc.exists) {
        _user = UserModel.fromFirestore(doc);
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return true;
    } catch (e) {
      _error = _handleAuthError(e);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
    required String department,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Generate QR code data
      final qrCodeData = const Uuid().v4();

      // Create user document in Firestore
      final newUser = UserModel(
        id: userCredential.user!.uid,
        email: email,
        fullName: fullName,
        studentId: studentId,
        department: department,
        role: UserRole.student,
        clubs: [],
        organizations: [],
        points: 0,
        qrCodeData: qrCodeData,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set(newUser.toMap());
      
      return true;
    } catch (e) {
      _error = _handleAuthError(e);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      _user = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? fullName,
    String? profileImageUrl,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_user == null) return false;

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };

      if (fullName != null) updates['fullName'] = fullName;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

      await _firestore.collection('users').doc(_user!.id).update(updates);
      await _fetchUserData();
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_firebaseUser == null || _user == null) return false;

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: _user!.email,
        password: currentPassword,
      );
      await _firebaseUser!.reauthenticateWithCredential(credential);

      // Change password
      await _firebaseUser!.updatePassword(newPassword);
      
      return true;
    } catch (e) {
      _error = _handleAuthError(e);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);
      
      return true;
    } catch (e) {
      _error = _handleAuthError(e);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'The email address is already in use.';
        case 'weak-password':
          return 'The password is too weak.';
        case 'invalid-email':
          return 'The email address is invalid.';
        default:
          return error.message ?? 'An unknown error occurred.';
      }
    }
    return error.toString();
  }
}

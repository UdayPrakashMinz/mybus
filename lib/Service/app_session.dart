import 'package:firebase_auth/firebase_auth.dart';

/// Defines the available app roles
enum UserRole { customer, management }

/// Global session handler
class AppSession {
  static User? get currentUser => FirebaseAuth.instance.currentUser;
  static String? get uid => currentUser?.uid;

  static UserRole? selectedRole;

  static void setRole(UserRole role) {
    selectedRole = role;
  }

  static Future<void> clear() async {
    selectedRole = null;
    await FirebaseAuth.instance.signOut();
  }

  static bool get isLoggedIn => currentUser != null;
  static bool get isCustomer => selectedRole == UserRole.customer;
  static bool get isManagement => selectedRole == UserRole.management;
}

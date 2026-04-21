import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mybus/Service/app_session.dart';
import 'package:mybus/Pages/login&sighup.dart';
import 'package:mybus/Service/home_main_navigation.dart';
import 'package:mybus/Pages/admin_main_navigation.dart';
import 'package:mybus/Pages/complete_profile_page.dart';

class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in
        if (!snapshot.hasData) {
          return const LoginSignupPage();
        }

        // Logged in → decide next page
        return FutureBuilder<_RouteInfo>(
          future: _resolveRoute(snapshot.data!.uid),
          builder: (context, routeSnapshot) {
            if (routeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!routeSnapshot.hasData) {
              return const LoginSignupPage();
            }

            final info = routeSnapshot.data!;

            // Force profile completion first
            if (!info.profileComplete) {
              return const CompleteProfilePage();
            }

            final role = info.role;
            AppSession.setRole(role);

            return role == UserRole.customer
                ? const HomeMainNavigation()
                : const AdminMainNavigation();
          },
        );
      },
    );
  }

  // ================= ROUTE RESOLUTION =================

  Future<_RouteInfo> _resolveRoute(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      return const _RouteInfo(role: UserRole.customer, profileComplete: false);
    }

    final data = doc.data() ?? {};
    final roles = data['roles'] ?? {};

    final bool profileComplete = data['profileComplete'] == true;

    // If user explicitly chose a mode on the login/signup screen for
    // this session, respect that choice.
    if (AppSession.selectedRole != null) {
      return _RouteInfo(
        role: AppSession.selectedRole!,
        profileComplete: profileComplete,
      );
    }

    final isAdmin = roles['admin'] == true;
    final isBusOwner = roles['busOwner'] == true;
    final isCustomer = roles['customer'] == true;

    // If we don't have an explicit session choice, pick a sensible default.
    // Admins and BusOwners default to MANAGEMENT mode for their workflow.
    if (isAdmin) {
      return _RouteInfo(
        role: UserRole.management,
        profileComplete: profileComplete,
      );
    }

    // BusOwner without admin → Management dashboard.
    if (isBusOwner) {
      return _RouteInfo(
        role: UserRole.management,
        profileComplete: profileComplete,
      );
    }

    // Pure customer → Consumer app.
    if (isCustomer) {
      return _RouteInfo(
        role: UserRole.customer,
        profileComplete: profileComplete,
      );
    }

    // Fallback
    return _RouteInfo(
      role: UserRole.customer,
      profileComplete: profileComplete,
    );
  }
}

class _RouteInfo {
  final UserRole role;
  final bool profileComplete;

  const _RouteInfo({required this.role, required this.profileComplete});
}

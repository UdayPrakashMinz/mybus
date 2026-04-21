import 'package:flutter/material.dart';
import 'package:mybus/Service/app_session.dart';
import 'package:mybus/Service/auth_router.dart';

class RoleSelectionPage extends StatelessWidget {
  final List<UserRole> roles;

  const RoleSelectionPage({super.key, required this.roles});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Mode")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: roles.map((role) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () {
                  AppSession.selectedRole = role;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthRouter()),
                  );
                },
                child: Text(
                  role == UserRole.customer
                      ? "Customer Mode"
                      : "Management Mode",
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

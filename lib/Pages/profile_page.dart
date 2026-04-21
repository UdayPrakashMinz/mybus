import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mybus/Pages/about_page.dart';
import 'package:mybus/Pages/manage_bus_page.dart';
import 'package:mybus/Service/app_session.dart';
import 'package:mybus/Service/auth_router.dart';
import 'package:mybus/Pages/edit_profile_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isManagementMode = AppSession.selectedRole == UserRole.management;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data ?? {};
          final roles = userData['roles'] ?? {};
          final bool isAdmin = roles['admin'] == true;
          final String? avatar = userData['avatar'];
          final String displayName =
              (userData['name'] as String?)?.trim().isNotEmpty == true
              ? (userData['name'] as String).trim()
              : (user?.email ?? "User");
          final String? phone =
              (userData['phone'] as String?)?.trim().isNotEmpty == true
              ? (userData['phone'] as String).trim()
              : null;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              /// PROFILE IMAGE
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: avatar != null ? AssetImage(avatar) : null,
                  child: avatar == null
                      ? const Icon(Icons.person, size: 60, color: Colors.blue)
                      : null,
                ),
              ),

              const SizedBox(height: 16),

              /// NAME / EMAIL
              Center(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Column(
                  children: [
                    if (phone != null)
                      Text(phone, style: const TextStyle(color: Colors.grey)),
                    Text(
                      isManagementMode ? "Management Mode" : "Consumer Mode",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "ACCOUNT & SUPPORT",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              _profileTile(
                icon: Icons.person_outline,
                title: "Edit Profile",
                subtitle: "Update your name and phone",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                },
              ),

              /// Consumer Feature
              if (!isManagementMode)
                _profileTile(
                  icon: Icons.history,
                  title: "My Trips (History)",
                  subtitle: "Review your past travels",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Trips Clicked")),
                    );
                  },
                ),

              /// Management Feature
              if (isManagementMode)
                _profileTile(
                  icon: Icons.directions_bus,
                  title: "Manage Fleet",
                  subtitle: "View and manage your buses",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageBusPage()),
                    );
                  },
                ),

              _profileTile(
                icon: Icons.help_outline,
                title: "Help & Support",
                subtitle: "FAQs and direct chat",
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Help Clicked")));
                },
              ),

              const SizedBox(height: 30),

              _profileTile(
                icon: Icons.info_outline_rounded,
                title: "About",
                subtitle: "About MyBus – A Smart Travel Solution",
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AboutPage()));
                },
              ),

              const SizedBox(height: 12),

              /// ROLE SWITCH (for bus owners and admins)
              if (isAdmin || roles['busOwner'] == true)
                _profileTile(
                  icon: Icons.swap_horiz,
                  title: isManagementMode
                      ? "Switch to Consumer Mode"
                      : "Switch to Management Mode",
                  subtitle: "Change how you are using the app",
                  onTap: () {
                    final nextRole = isManagementMode
                        ? UserRole.customer
                        : UserRole.management;
                    AppSession.setRole(nextRole);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthRouter()),
                      (route) => false,
                    );
                  },
                ),

              const SizedBox(height: 16),

              /// SIGN OUT
              ElevatedButton.icon(
                onPressed: () async {
                  await AppSession.clear();
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text("Sign Out"),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _profileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

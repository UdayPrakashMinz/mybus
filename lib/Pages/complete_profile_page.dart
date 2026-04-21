import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mybus/Service/auth_router.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedAvatar;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final displayName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      _nameController.text = displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _pickAvatar() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final avatars = [
          "assets/avatars/a1.png",
          "assets/avatars/a2.png",
          "assets/avatars/a3.png",
          "assets/avatars/a4.png",
          "assets/avatars/a5.png",
          "assets/avatars/a6.png",
          "assets/avatars/a7.png",
          "assets/avatars/a8.png",
          "assets/avatars/a9.png",
          "assets/avatars/a10.png",
          "assets/avatars/a11.png",
          "assets/avatars/a12.png",
          "assets/avatars/a13.png",
          // add more here
        ];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: avatars.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, index) {
              final avatar = avatars[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAvatar = avatar;
                  });
                  Navigator.pop(context);
                },
                child: CircleAvatar(backgroundImage: AssetImage(avatar)),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text("Complete Profile"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 100,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tell us about you",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "We use this information for tickets and communication.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _selectedAvatar != null
                              ? AssetImage(_selectedAvatar!)
                              : null,
                          child: _selectedAvatar == null
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _pickAvatar,
                          child: const Text("Choose Avatar"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saving ? null : () => _save(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137FEC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Continue",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(User? user) async {
    if (user == null) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty || _selectedAvatar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields and select an avatar"),
        ),
      );
      return;
    }

    try {
      setState(() => _saving = true);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        "name": name,
        "phone": phone,
        "avatar": _selectedAvatar, // 👈 add this
        "profileComplete": true,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      // Go back into the main router; it will now see profileComplete == true
      // and send the user to the correct home/dashboard.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthRouter()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to save profile")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

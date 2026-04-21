import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedAvatar;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};

      _nameController.text = data['name'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _selectedAvatar = data['avatar']; //
    } finally {
      if (mounted) setState(() => _loading = false);
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
      isScrollControlled: true,
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

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.5, // 👈 50% screen
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              itemCount: avatars.length,
              physics: const BouncingScrollPhysics(), // smooth scroll
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (_, index) {
                final avatar = avatars[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () {
                    setState(() {
                      _selectedAvatar = avatar;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedAvatar == avatar
                            ? Colors.blue
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(backgroundImage: AssetImage(avatar)),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile"), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
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
                          child: const Text("Change Avatar"),
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
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Save Changes",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    try {
      setState(() => _saving = true);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        "name": name,
        "phone": phone,
        "avatar": _selectedAvatar, // 👈 ADD THIS
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile updated")));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to update profile")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

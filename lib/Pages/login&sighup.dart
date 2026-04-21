import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mybus/Pages/pass_reset.dart';
import 'package:mybus/Service/app_session.dart';

class LoginSignupPage extends StatefulWidget {
  const LoginSignupPage({super.key});

  @override
  State<LoginSignupPage> createState() => _LoginSignupPageState();
}

class _LoginSignupPageState extends State<LoginSignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.customer;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              /// TITLE
              Text(
                _isSignUp ? "Sign Up" : "Login",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 32),

              /// HEADING
              Text(
                _isSignUp ? "Create your account" : "Ready for your next trip?",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _isSignUp
                    ? "Sign up to manage buses and trips."
                    : "Log in to track your bus and manage bookings.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 32),

              /// ROLE SELECTOR
              _buildRoleSelector(),

              const SizedBox(height: 24),

              /// EMAIL
              _buildInput(
                label: "Email Address",
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              /// PASSWORD
              _buildPasswordInput(
                label: "Password",
                controller: _passwordController,
                showForgot: !_isSignUp,
              ),

              if (_isSignUp) ...[
                const SizedBox(height: 16),
                _buildPasswordInput(
                  label: "Confirm Password",
                  controller: _confirmPasswordController,
                ),
              ],

              const SizedBox(height: 24),

              /// LOGIN / SIGNUP BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : _isSignUp
                      ? _signUpWithEmail
                      : _loginWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF137FEC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isSignUp ? "Create Account" : "Login",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              /// DIVIDER
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text("Or continue with"),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 24),

              /// SOCIAL BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButton(
                    "assets/ui/google.svg",
                    onTap: _signInWithGoogle,
                  ),
                  const SizedBox(width: 16),
                  _socialButton(
                    "assets/ui/apple-logo.svg",
                    onTap: () {
                      final snackBar = SnackBar(content: Text('Coming Soon!'));
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    },
                  ),
                  const SizedBox(width: 16),
                  _socialButton(
                    "assets/ui/facebook.svg",
                    onTap: () {
                      final snackBar = SnackBar(content: Text('Coming Soon!'));
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              /// TOGGLE LOGIN / SIGNUP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? "Already have an account? "
                        : "Don't have an account? ",
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _isSignUp = !_isSignUp);
                    },
                    child: Text(
                      _isSignUp ? "Login" : "Sign Up",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _buildRoleSelector() {
    return DefaultTabController(
      length: 2,
      child: TabBar(
        indicatorColor: const Color(0xFF137FEC),
        labelColor: const Color(0xFF137FEC),
        unselectedLabelColor: Colors.black54,
        onTap: (index) {
          setState(() {
            _selectedRole = index == 0
                ? UserRole.customer
                : UserRole.management;
          });
        },
        tabs: const [
          Tab(text: "CONSUMER"),
          Tab(text: "MANAGEMENT"),
        ],
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: "Enter your ${label.toLowerCase()}",
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.asset(
                "assets/ui/envelope.svg",
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordInput({
    required String label,
    required TextEditingController controller,
    bool showForgot = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: "Enter your password",
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.asset(
                "assets/ui/lock.svg",
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        //  ONLY SHOW WHEN NEEDED
        if (showForgot)
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
              );
            },
            child: const Text("Forgot Password?"),
          ),
      ],
    );
  }

  Widget _socialButton(String svgPath, {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(child: SvgPicture.asset(svgPath, width: 24)),
      ),
    );
  }

  // ================= FIREBASE =================

  Future<void> _signUpWithEmail() async {
    try {
      if (!mounted) return;
      setState(() => _loading = true);

      // set session role early so router can make the right decision
      AppSession.setRole(_selectedRole);

      if (_passwordController.text != _confirmPasswordController.text) {
        _showMessage("Passwords do not match");
        return;
      }

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final user = credential.user!;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        "email": user.email,
        "roles": {
          "customer": true,
          "busOwner": _selectedRole == UserRole.management,
          "admin": false,
        },
        "profileComplete": false,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // role was already set above
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loginWithEmail() async {
    try {
      if (!mounted) return;
      setState(() => _loading = true);

      // pre-set session role so AuthRouter can use it immediately
      AppSession.setRole(_selectedRole);

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user!;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        _showMessage("User profile not found");
        await FirebaseAuth.instance.signOut();
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final roles = data['roles'] ?? {};

      // Allow for old schema where you might have used `endUser`
      // and treat admin as having access to both modes.
      final bool isAdmin = roles['admin'] == true;
      final bool isBusOwner = roles['busOwner'] == true;
      final bool isCustomer = roles['customer'] == true;
      final bool isEndUser = roles['endUser'] == true;

      final bool canUseManagement = isAdmin || isBusOwner;
      final bool canUseCustomer = isAdmin || isCustomer || isEndUser;

      if (_selectedRole == UserRole.customer) {
        if (!canUseCustomer) {
          _showMessage("You are not allowed to login as Customer");
          await FirebaseAuth.instance.signOut();
          return;
        }
      } else {
        if (!canUseManagement) {
          _showMessage("You are not allowed to login as Management");
          await FirebaseAuth.instance.signOut();
          return;
        }
      }

      // Small delay to avoid routing race with AuthRouter
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // for kIsWeb

  Future<void> _signInWithGoogle() async {
    try {
      if (!mounted) return;
      setState(() => _loading = true);

      // Set role early
      AppSession.setRole(_selectedRole);

      UserCredential userCred;

      if (kIsWeb) {
        // ✅ WEB LOGIN (Firebase popup)
        GoogleAuthProvider googleProvider = GoogleAuthProvider();

        userCred = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // ✅ MOBILE LOGIN (GoogleSignIn plugin)
        final googleUser = await GoogleSignIn().signIn();

        if (googleUser == null) {
          AppSession.setRole(UserRole.customer);
          return;
        }

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // ✅ Common logic (both web + mobile)
      final user = userCred.user!;
      final uid = user.uid;

      final usersRef = FirebaseFirestore.instance.collection('users').doc(uid);

      final doc = await usersRef.get();

      if (!doc.exists) {
        await usersRef.set({
          'name': user.displayName ?? '',
          'email': user.email,
          'phone': user.phoneNumber ?? '',
          'roles': {
            'customer': true,
            'busOwner': _selectedRole == UserRole.management,
            'admin': false,
          },
          'profileComplete': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final existing = doc.data() ?? {};
        final existingRoles = existing['roles'] ?? {};

        await usersRef.set({
          'name': existing['name'] ?? user.displayName ?? '',
          'email': user.email,
          'phone': existing['phone'] ?? user.phoneNumber ?? '',
          'roles': {
            'customer': true,
            'busOwner':
                _selectedRole == UserRole.management ||
                existingRoles['busOwner'] == true,
            'admin': existingRoles['admin'] == true,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

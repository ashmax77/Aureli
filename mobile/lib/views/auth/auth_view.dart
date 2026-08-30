import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_card.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _agreeToTerms = false;
      _formKey.currentState?.reset();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141B26),
          title: const Text("Reset Password", style: TextStyle(color: Colors.white, fontFamily: 'Manrope', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Enter your email address and we'll send you a link to reset your password.",
                style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Manrope'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Email address",
                  labelStyle: TextStyle(color: Colors.white60),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF147D64))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) return;

                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final success = await authProvider.sendPasswordResetEmail(email);

                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Reset email sent to $email!"), backgroundColor: const Color(0xFF147D64)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(authProvider.errorMessage ?? "Failed to send reset email"), backgroundColor: const Color(0xFFB42318)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF147D64)),
              child: const Text("Send link", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isLogin) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Passwords do not match"),
            backgroundColor: Color(0xFFB42318),
          ),
        );
        return;
      }
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please agree to the Terms of Service and Privacy Policy"),
            backgroundColor: Color(0xFFB42318),
          ),
        );
        return;
      }
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text;
    final password = _passwordController.text;

    bool success;
    if (_isLogin) {
      success = await authProvider.login(email, password);
    } else {
      success = await authProvider.signUp(email, password);
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLogin ? "Welcome back!" : "Account created successfully!"),
          backgroundColor: const Color(0xFF147D64), // Emerald
        ),
      );
    } else if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: const Color(0xFFB42318), // Error Red
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621), // Dark base background
      body: Stack(
        children: [
          // 1. Decorative glowing colored spheres in the background
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B3B5A).withOpacity(0.5), // Deep Navy
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF147D64).withOpacity(0.4), // Emerald
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.4,
            right: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB45309).withOpacity(0.3), // Amber
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // 2. Main content scroll view
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/icon/app_icon.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Aureli",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "SPEND WITH CLARITY.",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Glass Card wrapper
                  GlassCard(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                           Text(
                            _isLogin ? "Sign In" : "Create your account",
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: _isLogin ? "Email" : "Email address",
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                              prefixIcon: Icon(Icons.email_outlined, color: Colors.white.withOpacity(0.6)),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF147D64)), // Emerald
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter your email";
                              }
                              if (!RegExp(r'^.+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$').hasMatch(value.trim())) {
                                return "Please enter a valid email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Password",
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.white.withOpacity(0.6)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF147D64)),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter your password";
                              }
                              if (value.trim().length < 6) {
                                return "Password must be at least 6 characters";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Forgot password / Confirm password / Terms agreement
                          if (_isLogin) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  "Forgot password?",
                                  style: TextStyle(
                                    color: Color(0xFF147D64),
                                    fontFamily: 'Manrope',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: "Confirm password",
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.white.withOpacity(0.6)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF147D64)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Please confirm your password";
                                }
                                if (value.trim() != _passwordController.text.trim()) {
                                  return "Passwords do not match";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Checkbox(
                                  value: _agreeToTerms,
                                  activeColor: const Color(0xFF147D64),
                                  onChanged: (val) {
                                    setState(() => _agreeToTerms = val ?? false);
                                  },
                                ),
                                const Expanded(
                                  child: Text(
                                    "I agree to the Terms of Service and Privacy Policy",
                                    style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Manrope'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Submit Button
                          authProvider.isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF147D64),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0B3B5A), // Primary Navy
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    _isLogin ? "Sign In" : "Create account",
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 16),

                          // Toggle Mode
                          TextButton(
                            onPressed: _toggleMode,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white.withOpacity(0.7),
                            ),
                            child: Text(
                              _isLogin ? "Don't have an account? Sign up" : "Already have an account? Sign in",
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

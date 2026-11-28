import 'package:aureli/theme/app_colors.dart';
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
  bool _isSubmitting = false;

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
          backgroundColor: context.cardLightBg,
          title: Text(
            "Reset Password",
            style: TextStyle(
              color: context.textPrimary,
              fontFamily: 'Manrope',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Enter your email address and we'll send you a link to reset your password.",
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                  fontFamily: 'Manrope',
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                autofocus: true,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: "Email address",
                  labelStyle: TextStyle(color: context.tokens.inkMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.divider),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.emerald),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(color: context.tokens.inkMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (!RegExp(r'^.+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$')
                    .hasMatch(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a valid email")),
                  );
                  return;
                }

                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                final success = await authProvider.sendPasswordResetEmail(
                  email,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Reset email sent to $email!"),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          authProvider.errorMessage ??
                              "Failed to send reset email",
                        ),
                        backgroundColor: context.tokens.coral,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
              ),
              child: Text(
                "Send link",
                style: TextStyle(color: context.textPrimary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTermsAndConditionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardLightBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.gavel_rounded, color: context.tokens.emerald),
            SizedBox(width: 10),
            Text(
              "Terms & Conditions",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Welcome to Aureli. By creating an account, you agree to the following terms and privacy practices:\n",
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.4),
              ),
              Text(
                "1. Data Privacy & Confidentiality",
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                "Your financial transactions, budgets, and personal details are encrypted in transit. Aureli will never sell or share your personal data with third-party advertisers.\n",
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: context.tokens.inkMuted,
                    fontSize: 12,
                    height: 1.4),
              ),
              Text(
                "2. Account Security",
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                "You are responsible for maintaining the confidentiality of your login credentials and enabling biometric security options when available.\n",
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: context.tokens.inkMuted,
                    fontSize: 12,
                    height: 1.4),
              ),
              Text(
                "3. Service Usage",
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                "Aureli provides personal budget management tools for informational purposes. You agree not to misuse the platform or engage in automated abuse.",
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: context.tokens.inkMuted,
                    fontSize: 12,
                    height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() => _agreeToTerms = true);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(),
            child: Text("I Agree",
                style: TextStyle(
                    color: context.textPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_isLogin) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Passwords do not match"),
            backgroundColor: context.tokens.coral,
          ),
        );
        return;
      }
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please agree to the Terms of Service and Privacy Policy",
            ),
            backgroundColor: context.tokens.coral,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final success = _isLogin
          ? await authProvider.login(email, password)
          : await authProvider.signUp(email, password);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isLogin ? "Welcome back!" : "Account created successfully!",
            ),
          ),
        );
      } else if (authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            backgroundColor: context.tokens.coral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor, // Dynamic base background
      body: Stack(
        children: [
const Positioned.fill(child: AmbientBackdrop()),

          // 2. Main content scroll view
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
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
                          color: Colors.black.withValues(alpha: 0.3),
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
                  SizedBox(height: 12),
                  Text(
                    "Aureli",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Spend with clarity.",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.tokens.inkMuted,
                    ),
                  ),
                  SizedBox(height: 32),

                  // Glass Card wrapper
                  GlassCard(
                    padding: EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isLogin ? "Sign In" : "Create your account",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          SizedBox(height: 20),

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: _isLogin ? "Email" : "Email address",
                              labelStyle: TextStyle(
                                color: context.tokens.inkMuted,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: context.tokens.inkMuted,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: context.tokens.hairline,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: context.tokens.emerald,
                                ), // Emerald
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter your email";
                              }
                              if (!RegExp(
                                r'^.+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$',
                              ).hasMatch(value.trim())) {
                                return "Please enter a valid email";
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: "Password",
                              labelStyle: TextStyle(
                                color: context.tokens.inkMuted,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: context.tokens.inkMuted,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: context.tokens.inkMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: context.tokens.hairline,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: context.tokens.emerald,
                                ),
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
                          SizedBox(height: 8),

                          // Forgot password / Confirm password / Terms agreement
                          if (_isLogin) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  "Forgot password?",
                                  style: TextStyle(
                                    color: context.tokens.emerald,
                                    fontFamily: 'Manrope',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                          ] else ...[
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: TextStyle(color: context.textPrimary),
                              decoration: InputDecoration(
                                labelText: "Confirm password",
                                labelStyle: TextStyle(
                                  color: context.tokens.inkMuted,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: context.tokens.inkMuted,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: context.tokens.inkMuted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: context.tokens.hairline,
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: context.tokens.emerald,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Please confirm your password";
                                }
                                if (value.trim() !=
                                    _passwordController.text.trim()) {
                                  return "Passwords do not match";
                                }
                                return null;
                              },
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: _agreeToTerms,
                                  activeColor: context.tokens.brand,
                                  checkColor: context.textPrimary,
                                  side: BorderSide(
                                      color: context.textMuted, width: 1.5),
                                  onChanged: (val) {
                                    setState(
                                        () => _agreeToTerms = val ?? false);
                                  },
                                ),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        "I agree to the ",
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 12,
                                          fontFamily: 'Manrope',
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _showTermsAndConditionsDialog,
                                        child: Text(
                                          "Terms of Service & Privacy Policy",
                                          style: TextStyle(
                                            color: context.tokens.emerald,
                                            fontSize: 12,
                                            fontFamily: 'Manrope',
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                          ],

                          // Submit Button
                          _isSubmitting || authProvider.isLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: context.tokens.emerald,
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    _isLogin ? "Sign In" : "Create account",
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                          SizedBox(height: 16),

                          // Toggle Mode
                          TextButton(
                            onPressed: _toggleMode,
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  context.tokens.inkSecondary,
                            ),
                            child: Text(
                              _isLogin
                                  ? "Don't have an account? Sign up"
                                  : "Already have an account? Sign in",
                              style: TextStyle(
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

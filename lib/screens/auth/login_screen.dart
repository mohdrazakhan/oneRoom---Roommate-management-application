import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import '../../utils/validators.dart';
import '../../constants.dart';
import '../../app.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'phone_signin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      // Don't navigate manually - AuthWrapper will handle navigation when auth state changes
    } on firebase_auth.FirebaseAuthException catch (e) {
      _showMessage(_firebaseAuthErrorMessage(e));
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).signInWithGoogle();
      // Auth listener handles the rest
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Google sign-in cancelled')),
          );
        }
      } else {
        // Navigate immediately to dashboard to avoid being stuck on login while
        // auth state propagation completes. AuthWrapper will keep things in sync.
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(MyApp.routeDashboard);
        }
      }
      // Don't navigate manually - AuthWrapper will handle navigation when auth state changes
      // The AuthProvider listens to auth state changes and will trigger a rebuild
    } on firebase_auth.FirebaseAuthException catch (e) {
      _showMessage(_firebaseAuthErrorMessage(e));
    } catch (e) {
      final errorMsg = e.toString();
      // Check if it's a Google Play Services error
      if (errorMsg.contains('ApiException: 7') ||
          errorMsg.contains('NeedPermission')) {
        _showMessage(
          'Google Play Services error. Please:\n'
          '1. Ensure you\'re on a physical device with Google Play Services installed\n'
          '2. Or: On emulator, update Google Play Services and ensure network connectivity\n'
          '3. Try: Sign out from Google account and sign back in',
        );
      } else if (errorMsg.contains('ApiException: 10')) {
        _showMessage(
          'Google Sign-In requires a physical device or Google Play Services. '
          'Please use Email/Password login or Phone authentication for testing on emulator.',
        );
      } else if (errorMsg.contains('network_error')) {
        _showMessage(
          'Network error connecting to Google. Please check your internet connection and try again.',
        );
      } else {
        _showMessage('Error: $errorMsg');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handlePhoneSignIn() async {
    // Navigate to phone sign-in screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneSignInScreen()),
    );
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _loading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).signInWithApple();
      // Don't navigate manually control listener handles it
    } on firebase_auth.FirebaseAuthException catch (e) {
      _showMessage(_firebaseAuthErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('SignInWithAppleAuthorizationError')) {
        // User cancelled or failure
        return;
      }
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/Images/logo.png',
                      height: 84,
                      width: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.appName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to continue',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                              ),
                              validator: validateEmail,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock),
                              ),
                              validator: validatePassword,
                            ),
                            const SizedBox(height: 20),
                            PrimaryButton(
                              label: 'Login',
                              onPressed: _handleLogin,
                              loading: _loading,
                              width: double.infinity,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Social login buttons
                  Column(
                    children: [
                      _SocialLoginButton(
                        icon: Image.asset(
                          'assets/Images/google_logo.png',
                          height: 24,
                        ),
                        label: 'Continue with Google',
                        onTap: _handleGoogleSignIn,
                        background: Colors.white,
                        foreground: Colors.black87,
                      ),
                      const SizedBox(height: 16), // Unified spacing
                      if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                        _SocialLoginButton(
                          icon: const Icon(Icons.apple, size: 24),
                          label: 'Continue with Apple',
                          onTap: _handleAppleSignIn,
                          background: Colors.black,
                          foreground: Colors.white,
                        ),
                        const SizedBox(height: 16), // Unified spacing
                      ],
                      _SocialLoginButton(
                        icon: const Icon(Icons.phone_android, size: 24),
                        label: 'Continue with Phone',
                        onTap: _handlePhoneSignIn,
                        background: Theme.of(context).colorScheme.primary,
                        foreground: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Don’t have an account?'),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  const _SocialLoginButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: icon,
        label: Text(label),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}

String _firebaseAuthErrorMessage(firebase_auth.FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'The email address is badly formatted.';
    case 'user-disabled':
      return 'This user has been disabled.';
    case 'user-not-found':
      return 'No user found for that email.';
    case 'wrong-password':
      return 'Wrong password provided for that user.';
    case 'account-exists-with-different-credential':
      return 'Account exists with different credential.';
    case 'network-request-failed':
      return 'Network error. Please try again.';
    default:
      return e.message ?? 'Authentication error';
  }
}

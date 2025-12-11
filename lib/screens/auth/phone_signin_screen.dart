import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';

class PhoneSignInScreen extends StatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  bool _codeSent = false;
  String? _verificationId;
  String _countryCode = '+1'; // Default to USA

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showMessage('Please enter your phone number');
      return;
    }

    // Construct full phone number with country code
    final fullPhone = '$_countryCode$phone';

    setState(() => _loading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await authProvider.sendPhoneVerificationCode(
        phoneNumber: fullPhone,
        verificationCompleted:
            (firebase_auth.PhoneAuthCredential credential) async {
              // Auto-verification (Android only)
              try {
                debugPrint('✅ Phone auto-verification successful');
                await authProvider.signInWithPhoneCredential(credential);
                // Don't navigate manually - AuthWrapper will handle navigation
              } on firebase_auth.FirebaseAuthException catch (e) {
                if (mounted) {
                  _showMessage(_getPhoneAuthErrorMessage(e));
                }
              } catch (e) {
                if (mounted) {
                  _showMessage('Auto-verification failed: ${e.toString()}');
                }
              }
            },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          if (mounted) {
            setState(() => _loading = false);
            _showMessage(_getPhoneAuthErrorMessage(e));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _codeSent = true;
              _loading = false;
            });
            _showMessage('Verification code sent to $fullPhone');
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (mounted && _loading) {
            setState(() => _loading = false);
          }
        },
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_getPhoneAuthErrorMessage(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpCtrl.text.trim();
    if (code.isEmpty) {
      _showMessage('Please enter the verification code');
      return;
    }

    if (_verificationId == null) {
      _showMessage('Please request a code first');
      return;
    }

    setState(() => _loading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      await authProvider.signInWithPhoneCredential(credential);
      // Don't navigate manually - AuthWrapper will handle navigation
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_getPhoneAuthErrorMessage(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage('Verification failed: ${e.toString()}');
      }
    }
  }

  String _getPhoneAuthErrorMessage(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format. Please check and try again.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'session-expired':
        return 'Verification code expired. Please request a new code.';
      case 'app-not-authorized':
        return 'App is not authorized for phone authentication. Please check Firebase configuration.';
      case 'missing-phone-number':
        return 'Phone number is missing.';
      default:
        return e.message ?? 'Phone authentication failed. Please try again.';
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
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Phone icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.phone_android,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _codeSent ? 'Enter Verification Code' : 'Phone Sign In',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? 'Enter the 6-digit code sent to your phone'
                        : 'Enter your phone number to receive a verification code',
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
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
                      child: Column(
                        children: [
                          if (!_codeSent) ...[
                            // Country code selector
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _countryCode,
                                    underline: const SizedBox(),
                                    items: const [
                                      DropdownMenuItem(
                                        value: '+1',
                                        child: Text('🇺🇸 +1'),
                                      ),
                                      DropdownMenuItem(
                                        value: '+91',
                                        child: Text('🇮🇳 +91'),
                                      ),
                                      DropdownMenuItem(
                                        value: '+44',
                                        child: Text('🇬🇧 +44'),
                                      ),
                                      DropdownMenuItem(
                                        value: '+86',
                                        child: Text('🇨🇳 +86'),
                                      ),
                                      DropdownMenuItem(
                                        value: '+81',
                                        child: Text('🇯🇵 +81'),
                                      ),
                                      DropdownMenuItem(
                                        value: '+82',
                                        child: Text('🇰🇷 +82'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _countryCode = val);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Phone Number',
                                      hintText: '1234567890',
                                      prefixIcon: Icon(Icons.phone),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter phone number without country code',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: 'Send Code',
                              onPressed: _sendCode,
                              loading: _loading,
                              width: double.infinity,
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                labelText: 'Verification Code',
                                hintText: '123456',
                                prefixIcon: Icon(Icons.lock),
                              ),
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: 'Verify & Sign In',
                              onPressed: _verifyCode,
                              loading: _loading,
                              width: double.infinity,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _codeSent = false;
                                  _otpCtrl.clear();
                                });
                              },
                              child: const Text('Change Phone Number'),
                            ),
                          ],
                        ],
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
}

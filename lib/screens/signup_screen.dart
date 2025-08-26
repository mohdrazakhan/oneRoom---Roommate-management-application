import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

String _firebaseAuthErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'The email address is badly formatted.';
    case 'email-already-in-use':
      return 'An account already exists for that email.';
    case 'weak-password':
      return 'The password is too weak. Choose a stronger password.';
    case 'network-request-failed':
      return 'Network error. Please try again.';
    default:
      return e.message ?? 'Authentication error';
  }
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  String _gender = 'Prefer not to say';
  DateTime? _dob;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Create an Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Get started with One Room',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(
                    value: 'Prefer not to say',
                    child: Text('Prefer not to say'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _gender = v ?? 'Prefer not to say'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelText: 'Gender',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(now.year - 18),
                    firstDate: DateTime(1900),
                    lastDate: now,
                  );
                  if (picked != null) setState(() => _dob = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelText: 'Date of birth',
                  ),
                  child: Text(
                    _dob == null
                        ? 'Select date'
                        : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password (min. 6 characters)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final user = await _auth.registerWithEmailAndPassword(
                      _emailController.text.trim(),
                      _passwordController.text.trim(),
                    );
                    if (!mounted) return;
                    if (user != null) {
                      // Save profile to Firestore
                      final profile = {
                        'firstName': _firstNameController.text.trim(),
                        'lastName': _lastNameController.text.trim(),
                        'email': _emailController.text.trim(),
                        'mobile': _mobileController.text.trim(),
                        'gender': _gender,
                        'dob': _dob?.toIso8601String(),
                        'createdAt': DateTime.now().toIso8601String(),
                      };
                      // If mobile entered, attempt phone verification and link
                      if (_mobileController.text.trim().isNotEmpty) {
                        final phone = _mobileController.text.trim();
                        final messenger = ScaffoldMessenger.of(context);
                        final localContext = context;
                        try {
                          await FirebaseAuth.instance.verifyPhoneNumber(
                            phoneNumber: phone,
                            verificationCompleted:
                                (PhoneAuthCredential credential) async {
                                  try {
                                    await user.linkWithCredential(credential);
                                  } catch (_) {}
                                },
                            verificationFailed: (e) {
                              // ignore: avoid_print
                              print('Phone verification failed: ${e.message}');
                            },
                            codeSent:
                                (
                                  String verificationId,
                                  int? resendToken,
                                ) async {
                                  final smsController = TextEditingController();
                                  final confirmed = await showDialog<bool>(
                                    context: localContext,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Enter verification code',
                                      ),
                                      content: TextField(
                                        controller: smsController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'SMS code',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Verify'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    final smsCode = smsController.text.trim();
                                    final credential =
                                        PhoneAuthProvider.credential(
                                          verificationId: verificationId,
                                          smsCode: smsCode,
                                        );
                                    try {
                                      await user.linkWithCredential(credential);
                                    } catch (e) {
                                      // linking failed; show user
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Phone verification failed: ${e.toString()}',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                            codeAutoRetrievalTimeout:
                                (String verificationId) {},
                            timeout: const Duration(seconds: 60),
                          );
                        } catch (e) {
                          // ignore phone verification errors here; continue
                        }
                      }
                      try {
                        await _auth.createUserProfile(user.uid, profile);
                      } catch (_) {
                        // non-blocking: profile save failed
                      }
                      Navigator.pop(context);
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Registration failed')),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    final message = _firebaseAuthErrorMessage(e);
                    messenger.showSnackBar(SnackBar(content: Text(message)));
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('An unexpected error occurred'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.indigo,
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(color: Colors.indigo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

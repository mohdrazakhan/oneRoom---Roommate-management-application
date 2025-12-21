import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

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
  String _countryCode = '+91'; // Default to India as requested

  // Comprehensive list of country codes
  final List<Map<String, String>> _countries = [
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'name': 'USA/Canada', 'flag': '🇺🇸'},
    {'code': '+44', 'name': 'UK', 'flag': '🇬🇧'},
    {'code': '+86', 'name': 'China', 'flag': '🇨🇳'},
    {'code': '+81', 'name': 'Japan', 'flag': '🇯🇵'},
    {'code': '+82', 'name': 'South Korea', 'flag': '🇰🇷'},
    {'code': '+61', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': '+49', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': '+33', 'name': 'France', 'flag': '🇫🇷'},
    {'code': '+39', 'name': 'Italy', 'flag': '🇮🇹'},
    {'code': '+7', 'name': 'Russia', 'flag': '🇷🇺'},
    {'code': '+971', 'name': 'UAE', 'flag': '🇦🇪'},
    {'code': '+966', 'name': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': '+92', 'name': 'Pakistan', 'flag': '🇵🇰'},
    {'code': '+880', 'name': 'Bangladesh', 'flag': '🇧🇩'},
    {'code': '+94', 'name': 'Sri Lanka', 'flag': '🇱🇰'},
    {'code': '+977', 'name': 'Nepal', 'flag': '🇳🇵'},
    {'code': '+62', 'name': 'Indonesia', 'flag': '🇮🇩'},
    {'code': '+60', 'name': 'Malaysia', 'flag': '🇲🇾'},
    {'code': '+65', 'name': 'Singapore', 'flag': '🇸🇬'},
    {'code': '+66', 'name': 'Thailand', 'flag': '🇹🇭'},
    {'code': '+84', 'name': 'Vietnam', 'flag': '🇻🇳'},
    {'code': '+63', 'name': 'Philippines', 'flag': '🇵🇭'},
    {'code': '+55', 'name': 'Brazil', 'flag': '🇧🇷'},
    {'code': '+52', 'name': 'Mexico', 'flag': '🇲🇽'},
    {'code': '+20', 'name': 'Egypt', 'flag': '🇪🇬'},
    {'code': '+27', 'name': 'South Africa', 'flag': '🇿🇦'},
    {'code': '+234', 'name': 'Nigeria', 'flag': '🇳🇬'},
    // Add more as needed
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Widget _buildPhoneInput(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Country Code Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _countryCode,
              icon: const Icon(Icons.arrow_drop_down),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              onChanged: (val) {
                if (val != null) setState(() => _countryCode = val);
              },
              menuMaxHeight: 300, // Limit height for scrolling
              items: _countries.map((country) {
                return DropdownMenuItem<String>(
                  value: country['code'],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(country['flag']!),
                      const SizedBox(width: 8),
                      Text(country['code']!),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Container(
            height: 24,
            width: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
              decoration: const InputDecoration(
                hintText: 'Enter Phone Number',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
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
              _dismissVerificationScreen();
              // Auto-verification (Android only)
              try {
                debugPrint('✅ Phone auto-verification successful');
                await authProvider.signInWithPhoneCredential(credential);

                // Verification successful, close the screen
                if (mounted) {
                  Navigator.of(context).pop();
                }
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
          _dismissVerificationScreen();
          if (mounted) {
            setState(() => _loading = false);
            _showMessage(_getPhoneAuthErrorMessage(e));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _dismissVerificationScreen();
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

      // Verification successful, close the screen
      if (mounted) {
        Navigator.of(context).pop();
      }
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

  void _dismissVerificationScreen() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) {
      // Keep popping if the route name starts with /link (our deep link handler)
      final name = route.settings.name;
      return name == null || !name.startsWith('/link');
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF6366F1); // Indigo

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Illustration (Icon)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _codeSent
                      ? Icons.mark_email_read_rounded
                      : Icons.phonelink_ring_rounded,
                  size: 40,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 32),

              // Title & Subtitle
              Text(
                'Verification',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _codeSent
                    ? 'We will send you a One Time Password\non your phone number'
                    : 'We will send you a One Time Password\non your phone number',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 48),

              // Inputs depending on state
              if (!_codeSent)
                _buildPhoneInput(primaryColor)
              else
                _buildOtpInput(primaryColor),

              const Spacer(),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : (_codeSent ? _verifyCode : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: primaryColor.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _codeSent ? 'VERIFY' : 'GET OTP',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _codeSent = false;
                            _otpCtrl.clear();
                          });
                        },
                  child: RichText(
                    text: TextSpan(
                      text: "Didn't receive the verification OTP? ",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Resend again',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpInput(Color primaryColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8.0,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '• • • • • •',
              hintStyle: TextStyle(color: Colors.grey, letterSpacing: 8.0),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

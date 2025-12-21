import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../providers/auth_provider.dart';
import '../../widgets/safe_web_image.dart';
import '../../widgets/primary_button.dart';
import '../../utils/validators.dart';
import '../../constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<AuthProvider>(context, listen: false).profile;
    if (profile != null) {
      _nameCtrl.text = profile.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
      // For now we only preview. Upload to Firebase Storage if needed.
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.firebaseUser?.uid;
    if (uid == null) {
      _showMsg('Not signed in');
      setState(() => _saving = false);
      return;
    }

    try {
      await auth.updateDisplayName(_nameCtrl.text.trim());
      // If you implement photo uploads to Firebase Storage, update photoUrl here
      // await FirestoreService().updateUserProfile(uid, {'photoUrl': newUrl});

      _showMsg('Profile updated');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMsg('Failed to update: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile == null
          ? const Center(child: Text('No profile loaded'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile photo
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.grey[200],
                        foregroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!)
                            : null,
                        child: _pickedImage == null
                            ? (profile.photoUrl != null &&
                                      profile.photoUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: SafeWebImage(
                                        profile.photoUrl!,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person,
                                                size: 48,
                                                color: Colors.white,
                                              );
                                            },
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 48,
                                      color: Colors.white,
                                    ))
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                      ),
                      validator: validateDisplayName,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Email (read-only)
                    TextFormField(
                      initialValue: profile.email ?? '',
                      decoration: const InputDecoration(labelText: 'Email'),
                      readOnly: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Save button
                    PrimaryButton(
                      label: 'Save',
                      onPressed: _saveProfile,
                      loading: _saving,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

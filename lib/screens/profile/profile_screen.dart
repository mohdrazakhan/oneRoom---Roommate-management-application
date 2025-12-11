// lib/screens/profile/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../Models/user_profile.dart';
import '../../constants.dart';
import 'edit_profile_dialogs.dart';
import 'change_password_dialog.dart';
import 'about_screen.dart';
import 'support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;
      if (!mounted) return;

      setState(() => _isUploading = true);

      final authProvider = context.read<AuthProvider>();
      await authProvider.uploadProfilePhoto(File(image.path));

      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeProfilePhoto() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text(
          'Are you sure you want to remove your profile photo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isUploading = true);

      final authProvider = context.read<AuthProvider>();
      await authProvider.removeProfilePhoto();

      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo removed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPhotoOptions(bool hasPhoto) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(hasPhoto ? 'Change Photo' : 'Add Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage();
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.red),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.profile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('No profile data')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, profile),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileSection(context, profile),
                const SizedBox(height: 16),
                _buildPersonalInfoSection(context, profile),
                const SizedBox(height: 16),
                _buildNotificationSection(context, profile),
                const SizedBox(height: 16),
                _buildSecuritySection(context),
                const SizedBox(height: 16),
                _buildSupportSection(context),
                const SizedBox(height: 32),
                _buildSignOutButton(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, UserProfile profile) {
    return SliverAppBar(
      // Increased to prevent layout overflow when name + tagline + avatar
      expandedHeight: 260,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple, Colors.deepPurple.shade700],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildProfileImage(profile),
                    const SizedBox(height: 12),
                    Text(
                      profile.displayName ?? 'No Name',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((profile.tagline ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          profile.tagline!.trim(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(UserProfile profile) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            child: profile.photoUrl != null
                ? ClipOval(
                    child: Image.network(
                      profile.photoUrl!,
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            _getInitials(
                              profile.displayName ?? profile.email ?? '?',
                            ),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      _getInitials(profile.displayName ?? profile.email ?? '?'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
          ),
        ),
        if (_isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          )
        else
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _showPhotoOptions(profile.photoUrl != null),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildProfileSection(BuildContext context, UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildProfileTile(
            icon: Icons.person_outline_rounded,
            title: 'Display Name',
            value: profile.displayName ?? 'Not set',
            color: Colors.blue,
            onTap: () => _showEditNameDialog(context, profile),
          ),
          const Divider(height: 1),
          _buildProfileTile(
            icon: Icons.email_outlined,
            title: 'Email',
            value: profile.email ?? 'Not set',
            color: Colors.green,
            onTap: null, // Email usually can't be changed
          ),
          const Divider(height: 1),
          _buildProfileTile(
            icon: Icons.format_quote_rounded,
            title: 'Tagline',
            value: profile.tagline ?? 'Add a tagline',
            color: Colors.orange,
            onTap: () => _showEditTaglineDialog(context, profile),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context, UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          _buildProfileTile(
            icon: Icons.phone_outlined,
            title: 'Phone Number',
            value: profile.phoneNumber ?? 'Add phone number',
            color: Colors.teal,
            onTap: () => _showEditPhoneDialog(context, profile),
          ),
          const Divider(height: 1),
          _buildProfileTile(
            icon: Icons.cake_outlined,
            title: 'Date of Birth',
            value: profile.dateOfBirth != null
                ? DateFormat('MMM dd, yyyy').format(profile.dateOfBirth!)
                : 'Add date of birth',
            color: Colors.pink,
            onTap: () => _showEditDOBDialog(context, profile),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection(BuildContext context, UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive notifications',
            value: profile.notificationsEnabled,
            color: Colors.purple,
            onChanged: (val) =>
                _updateNotificationSetting('notifications', val),
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            icon: Icons.task_alt_rounded,
            title: 'Task Reminders',
            subtitle: 'Get reminded about tasks',
            value: profile.taskRemindersEnabled,
            color: Colors.blue,
            onChanged: (val) =>
                _updateNotificationSetting('taskReminders', val),
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            icon: Icons.attach_money_rounded,
            title: 'Expense Reminders',
            subtitle: 'Get expense notifications',
            value: profile.expenseRemindersEnabled,
            color: Colors.green,
            onChanged: (val) =>
                _updateNotificationSetting('expenseReminders', val),
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            icon: Icons.chat_bubble_rounded,
            title: 'Chat Notifications',
            subtitle: 'Get notified about new messages',
            value: profile.chatNotificationsEnabled,
            color: Colors.orange,
            onChanged: (val) =>
                _updateNotificationSetting('chatNotifications', val),
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            icon: Icons.payment_rounded,
            title: 'Expense/Payment Alerts',
            subtitle: 'Get alerts for expense add/edit/delete',
            value: profile.expensePaymentAlertsEnabled,
            color: Colors.teal,
            onChanged: (val) =>
                _updateNotificationSetting('expensePaymentAlerts', val),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Security',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          _buildProfileTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            value: 'Update your password',
            color: Colors.red,
            onTap: () => _showChangePasswordDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Support & About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          _buildProfileTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            value: 'Get help and contact us',
            color: Colors.indigo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
          ),
          const Divider(height: 1),
          _buildProfileTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            value: 'Learn more about One Room',
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded, color: Colors.grey[400])
          : null,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: color,
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              if (!context.mounted) return;
              try {
                await context.read<AuthProvider>().signOut();
                if (!context.mounted) return;
                // Navigate back to login
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text(
            'Sign Out',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, UserProfile profile) {
    showEditNameDialog(context, profile);
  }

  void _showEditTaglineDialog(BuildContext context, UserProfile profile) {
    showEditTaglineDialog(context, profile);
  }

  void _showEditPhoneDialog(BuildContext context, UserProfile profile) {
    showEditPhoneDialog(context, profile);
  }

  void _showEditDOBDialog(BuildContext context, UserProfile profile) {
    showEditDOBDialog(context, profile);
  }

  void _showChangePasswordDialog(BuildContext context) {
    showChangePasswordDialog(context);
  }

  Future<void> _updateNotificationSetting(String type, bool value) async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.updateNotificationSettings(type, value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings updated'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

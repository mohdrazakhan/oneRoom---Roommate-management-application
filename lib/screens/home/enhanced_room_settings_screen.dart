// ignore_for_file: deprecated_member_use
import 'dart:io';
import '../../widgets/safe_web_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/subscription_service.dart';
import 'package:flutter/services.dart';
import '../../Models/room.dart';
import '../../services/firestore_service.dart';
import '../../services/expense_export_service.dart';
import 'expense_analytics_screen.dart';
import '../../widgets/premium_avatar_wrapper.dart';

class EnhancedRoomSettingsScreen extends StatefulWidget {
  final Room room;

  const EnhancedRoomSettingsScreen({super.key, required this.room});

  @override
  State<EnhancedRoomSettingsScreen> createState() =>
      _EnhancedRoomSettingsScreenState();
}

class _EnhancedRoomSettingsScreenState
    extends State<EnhancedRoomSettingsScreen> {
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  bool _isLoadingProfiles = true;
  bool _isUploadingPhoto = false;
  double _totalExpenditure = 0.0;
  int _totalTransactions = 0;
  final _firestoreService = FirestoreService();
  final _picker = ImagePicker();

  final List<String> _currencies = [
    '₹',
    '\$',
    '€',
    '£',
    '¥',
    'R\$',
    'A\$',
    'C\$',
  ];

  @override
  void initState() {
    super.initState();
    _loadMemberProfiles();
    _loadExpenseStats();
  }

  Future<void> _loadMemberProfiles() async {
    try {
      final profiles = await _firestoreService.getUsersProfiles(
        widget.room.members,
      );

      if (mounted) {
        setState(() {
          _memberProfiles = profiles;
          _isLoadingProfiles = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading member profiles: $e');
      if (mounted) {
        setState(() => _isLoadingProfiles = false);
      }
    }
  }

  Future<void> _loadExpenseStats() async {
    try {
      final expenses = await _firestoreService
          .getExpenses(widget.room.id)
          .first;
      final total = expenses.fold<double>(
        0.0,
        (sum, expense) => sum + expense.amount,
      );

      if (mounted) {
        setState(() {
          _totalExpenditure = total;
          _totalTransactions = expenses.length;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading expense stats: $e');
    }
  }

  String _getMemberDisplayName(String uid) {
    final profile = _memberProfiles[uid];
    if (profile == null) return 'Member ${uid.substring(0, 4)}';

    if (profile['displayName'] != null &&
        profile['displayName'].toString().isNotEmpty) {
      return profile['displayName'];
    }

    if (profile['email'] != null) {
      final email = profile['email'].toString();
      final username = email.split('@')[0];
      return username;
    }

    return 'Member ${uid.substring(0, 4)}';
  }

  String _getMemberInitials(String uid) {
    final name = _getMemberDisplayName(uid);
    if (name.startsWith('Member')) {
      return name.substring(7, 8).toUpperCase();
    }
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  Future<void> _uploadRoomPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'rooms/${widget.room.id}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Upload new photo (don't try to delete old one, as it causes issues)
      final uploadTask = await storageRef.putFile(File(image.path));
      final photoUrl = await uploadTask.ref.getDownloadURL();

      // Update room in Firestore
      await _firestoreService.updateRoom(widget.room.id, {
        'photoUrl': photoUrl,
      });

      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room photo updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Pop and return to refresh the room data
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Error uploading photo: $e');
      if (mounted) {
        setState(() => _isUploadingPhoto = false);

        String errorMessage = 'Error uploading photo';
        if (e.toString().contains('permission') ||
            e.toString().contains('unauthorized') ||
            e.toString().contains('403')) {
          errorMessage =
              'Permission denied. Please configure Firebase Storage rules to allow uploads.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage = 'Error uploading photo: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _changeRoomName() async {
    final controller = TextEditingController(text: widget.room.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Room Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Room Name',
            hintText: 'Enter new room name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != widget.room.name) {
      try {
        await _firestoreService.updateRoom(widget.room.id, {'name': newName});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room name updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating name: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _changeCurrency() async {
    final newCurrency = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _currencies.map((currency) {
            return RadioListTile<String>(
              title: Text(currency),
              value: currency,
              groupValue: widget.room.currency,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (newCurrency != null && newCurrency != widget.room.currency) {
      try {
        await _firestoreService.updateRoom(widget.room.id, {
          'currency': newCurrency,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Currency updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating currency: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _leaveRoom() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Check if user is creator
    if (widget.room.createdBy == currentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Room creator cannot leave. Please delete the room instead.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Room'),
        content: Text(
          'Are you sure you want to leave "${widget.room.name}"? You won\'t be able to access this room\'s data anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.leaveRoom(widget.room.id, currentUserId);

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have left the room'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error leaving room: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportToPDF() async {
    final subService = Provider.of<SubscriptionService>(context, listen: false);
    if (!subService.isPremium) {
      Navigator.pushNamed(context, '/subscription');
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get all expenses
      final expenses = await _firestoreService
          .getExpenses(widget.room.id)
          .first;

      // Create member names map
      final memberNames = <String, String>{};
      for (final uid in widget.room.members) {
        memberNames[uid] = _getMemberDisplayName(uid);
      }

      // Generate PDF
      await ExpenseExportService.generateAndSharePDF(
        expenses: expenses,
        roomName: widget.room.name,
        currency: widget.room.currency,
        memberNames: memberNames,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    final subService = Provider.of<SubscriptionService>(context, listen: false);
    if (!subService.isPremium) {
      Navigator.pushNamed(context, '/subscription');
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get all expenses
      final expenses = await _firestoreService
          .getExpenses(widget.room.id)
          .first;

      // Create member names map
      final memberNames = <String, String>{};
      for (final uid in widget.room.members) {
        memberNames[uid] = _getMemberDisplayName(uid);
      }

      // Generate Excel
      await ExpenseExportService.generateAndShareExcel(
        expenses: expenses,
        roomName: widget.room.name,
        currency: widget.room.currency,
        memberNames: memberNames,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCreator = widget.room.createdBy == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Room Photo and Info Card
            _buildRoomInfoCard(context),

            const SizedBox(height: 24),

            // Invite Section with QR code and sharing
            _buildInviteSection(context),

            const SizedBox(height: 24),

            // Total Expenditure Card
            _buildExpenditureCard(context),

            const SizedBox(height: 24),

            // Room Settings Section
            _buildSettingsSection(context, isCreator),

            const SizedBox(height: 24),

            // Export Section
            _buildExportSection(context),

            const SizedBox(height: 24),

            // Members Section
            _buildMembersSection(context),

            const SizedBox(height: 24),

            // Leave Room Button (for non-creators)
            if (!isCreator) _buildLeaveRoomButton(context),

            // Delete Room Button (for creators only)
            if (isCreator) _buildDeleteRoomButton(context),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Room Photo
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child:
                    widget.room.photoUrl != null &&
                        widget.room.photoUrl!.isNotEmpty
                    ? ClipOval(
                        child: SafeWebImage(
                          widget.room.photoUrl!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.home_rounded,
                              size: 50,
                              color: Colors.white,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.home_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
              ),
              if (_isUploadingPhoto)
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
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _uploadRoomPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Room Name
          Text(
            widget.room.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Member Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${widget.room.members.length} members',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Currency Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Currency: ${widget.room.currency}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenditureCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to analytics screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpenseAnalyticsScreen(room: widget.room),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Total Expenditure',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.room.currency}${_totalExpenditure.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalTransactions transactions',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Icon(Icons.trending_up, color: Colors.green[600], size: 48),
              ],
            ),
            const SizedBox(height: 12),
            // Tap to view details hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to view detailed analytics',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isCreator) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Room Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Change Room Name'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changeRoomName,
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Change Currency'),
            subtitle: Text('Current: ${widget.room.currency}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changeCurrency,
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Export Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),

          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.red[700]),
            title: const Text('Export as PDF'),
            subtitle: const Text('View-only document'),
            trailing: const Icon(Icons.share),
            onTap: _exportToPDF,
          ),

          const Divider(height: 1),

          ListTile(
            leading: Icon(Icons.table_chart, color: Colors.green[700]),
            title: const Text('Export as Excel'),
            subtitle: const Text('View-only spreadsheet'),
            trailing: const Icon(Icons.share),
            onTap: _exportToExcel,
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove $memberName from the room?',
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

    if (confirmed == true) {
      try {
        await _firestoreService.leaveRoom(widget.room.id, memberId);

        if (mounted) {
          setState(() {
            widget.room.members.remove(memberId);
            _memberProfiles.remove(memberId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$memberName has been removed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing member: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildMembersSection(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isViewerCreator = widget.room.createdBy == currentUserId;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Members',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_isLoadingProfiles)
            const Center(child: CircularProgressIndicator())
          else
            ...widget.room.members.asMap().entries.map((entry) {
              final index = entry.key;
              final memberId = entry.value;
              final isMemberCreator = memberId == widget.room.createdBy;
              final memberName = _getMemberDisplayName(memberId);
              final profile = _memberProfiles[memberId];
              final photoUrl = profile?['photoUrl'] as String?;

              final tier = profile?['subscriptionTier'] as String? ?? 'free';
              final isLegacyPremium = profile?['isPremium'] == true;
              final isPremium = tier != 'free' || isLegacyPremium;

              final avatarContent = CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: photoUrl != null
                    ? ClipOval(
                        child: SafeWebImage(
                          photoUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              _getMemberInitials(memberId),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        _getMemberInitials(memberId),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              );

              return Column(
                children: [
                  if (index > 0) const Divider(height: 24),
                  Row(
                    children: [
                      if (isPremium)
                        PremiumAvatarWrapper(
                          isPremium: true,
                          size: 26,
                          borderWidth: 2,
                          child: avatarContent,
                        )
                      else
                        avatarContent,
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              memberName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            if (profile?['email'] != null)
                              Text(
                                profile!['email'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isMemberCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber[800],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Creator',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isViewerCreator)
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeMember(memberId, memberName),
                          tooltip: 'Remove member',
                        ),
                    ],
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLeaveRoomButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: _leaveRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[50],
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.exit_to_app),
        label: const Text(
          'Leave Room',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDeleteRoomButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: _deleteRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.delete_forever),
        label: const Text(
          'Delete Room',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _deleteRoom() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Verify user is the creator
    if (widget.room.createdBy != currentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the room creator can delete the room.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.room.name}"?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'All expenses, tasks, and room data will be permanently deleted for all members.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red[700],
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
        }

        // Delete the room
        await _firestoreService.deleteRoom(widget.room.id);

        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();

          // Navigate back to dashboard
          Navigator.of(context).popUntil((route) => route.isFirst);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting room: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildInviteSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_add_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text(
                'Invite Roommates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: QrImageView(
              data: widget.room.id,
              version: QrVersions.auto,
              size: 120,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              widget.room.id,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.content_copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.room.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Room code copied to clipboard!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'Copy code',
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: () {
                  final message =
                      'Join my room "${widget.room.name}" on One Room app!\n\n'
                      'Room Code: ${widget.room.id}\n\n'
                      'Use this code to join and sync all our tasks and expenses.';
                  Share.share(message, subject: 'Join my One Room group!');
                },
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'Share code',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scan the QR code or use the room code to join and sync all data.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

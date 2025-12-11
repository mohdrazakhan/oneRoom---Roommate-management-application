// lib/screens/profile/report_bug_screen.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReportBugScreen extends StatefulWidget {
  const ReportBugScreen({super.key});

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _attachments = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _contactCtrl.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _stepsCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Add Photo'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded),
              title: const Text('Add Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );

    if (choice == null) return;
    try {
      final XFile? picked;
      if (choice == 'image') {
        picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
      } else {
        picked = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 2),
        );
      }
      if (picked != null && mounted) {
        final file = picked;
        setState(() => _attachments.add(file));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;

    try {
      final attachmentUrls = <Map<String, dynamic>>[];
      for (final file in _attachments) {
        final fileName = file.name;
        final ref = FirebaseStorage.instance.ref().child(
          'bug_reports/${uid ?? 'anonymous'}/$timestamp/$fileName',
        );
        final uploadTask = await ref.putFile(File(file.path));
        final url = await uploadTask.ref.getDownloadURL();
        attachmentUrls.add({
          'name': fileName,
          'url': url,
          'type':
              file.mimeType ??
              (file.path.endsWith('.mp4') ? 'video/mp4' : 'file'),
        });
      }

      await FirebaseFirestore.instance.collection('bug_reports').add({
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'steps': _stepsCtrl.text.trim(),
        'contact': _contactCtrl.text.trim(),
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'attachments': attachmentUrls,
        'status': 'open',
        'appVersion': null, // optionally fill if you track it
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bug report sent. Thank you!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Bug')),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHelpBanner(),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildField(
                        controller: _titleCtrl,
                        label: 'Title',
                        hint: 'Short summary (e.g., Expense split not saving)',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),
                      _buildField(
                        controller: _descriptionCtrl,
                        label: 'What happened?',
                        hint: 'Describe the issue and what you expected.',
                        maxLines: 4,
                        validator: (v) => (v == null || v.trim().length < 10)
                            ? 'Please add at least 10 characters'
                            : null,
                      ),
                      _buildField(
                        controller: _stepsCtrl,
                        label: 'Steps to reproduce (optional)',
                        hint: '1) ... 2) ... 3) ...',
                        maxLines: 3,
                      ),
                      _buildField(
                        controller: _contactCtrl,
                        label: 'Contact (email/phone)',
                        hint: 'We will reach out if more info is needed',
                      ),
                      const SizedBox(height: 12),
                      _buildAttachments(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _submitting ? 'Sending...' : 'Send Report',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bug_report_rounded, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tell us what broke. Include a screenshot or a short screen recording if possible.',
              style: TextStyle(color: Colors.grey[800], height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Attachments (images/videos)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _attachments.length >= 4 ? null : _pickAttachment,
              icon: const Icon(Icons.add_rounded),
              label: Text(_attachments.length >= 4 ? 'Max 4' : 'Add'),
            ),
          ],
        ),
        if (_attachments.isEmpty)
          Text(
            'Add up to 4 files to help us reproduce the issue.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        if (_attachments.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _attachments
                .asMap()
                .entries
                .map(
                  (entry) => Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildAttachmentPreview(entry.value),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () {
                            setState(() => _attachments.removeAt(entry.key));
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildAttachmentPreview(XFile file) {
    final isVideo =
        file.mimeType?.startsWith('video') ?? file.path.endsWith('.mp4');
    if (isVideo) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      );
    }
    return Image.file(
      File(file.path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image_rounded)),
    );
  }
}

// lib/screens/profile/video_tutorials_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoTutorialsScreen extends StatelessWidget {
  const VideoTutorialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Tutorials')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildCard(
            title: 'Getting Started (Rooms & Invites)',
            description:
                'Create or join rooms, share invite codes/QR, and manage members.',
            url: 'https://example.com/oneroom/getting-started',
          ),
          _buildCard(
            title: 'Expenses & Settlements',
            description:
                'Add expenses, split equally/exact/percent, and mark settlements.',
            url: 'https://example.com/oneroom/expenses',
          ),
          _buildCard(
            title: 'Tasks & Reminders',
            description:
                'Create task categories, schedule rotations, swap tasks, and reminders.',
            url: 'https://example.com/oneroom/tasks',
          ),
          _buildCard(
            title: 'Chat, Polls, and Links',
            description:
                'Send messages, media, polls, payment reminders, and link tasks/expenses.',
            url: 'https://example.com/oneroom/chat',
          ),
          const SizedBox(height: 24),
          Text(
            'More tutorials coming soon. Need a specific video? Email us from Customer Care.',
            style: TextStyle(color: Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String description,
    required String url,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            description,
            style: TextStyle(color: Colors.grey[700], height: 1.4),
          ),
        ),
        trailing: const Icon(Icons.open_in_new_rounded),
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }
}

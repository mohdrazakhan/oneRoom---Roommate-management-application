// lib/screens/profile/support_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Customer Care',
            icon: Icons.headset_mic_rounded,
            color: Colors.blue,
            children: [
              _buildContactTile(
                icon: Icons.phone_outlined,
                title: 'Phone Support',
                subtitle: '+91 8279677833',
                onTap: () => _launchUrl('tel:+918279677833'),
              ),
              _buildContactTile(
                icon: Icons.email_outlined,
                title: 'Email Support',
                subtitle: 'mohdrazakhan32@gmail.com',
                onTap: () => _launchUrl('mailto:mohdrazakhan32@gmail.com'),
              ),
              _buildContactTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Live Chat',
                subtitle: 'Coming soon',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Live chat coming soon!')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'FAQs',
            icon: Icons.help_outline_rounded,
            color: Colors.green,
            children: [
              _buildFAQTile(
                question: 'How do I add roommates?',
                answer:
                    'Go to your room, tap the menu, and select "Add Member". Share the invite code with your roommate.',
              ),
              _buildFAQTile(
                question: 'How are expenses split?',
                answer:
                    'Expenses are automatically calculated and split equally among selected members.',
              ),
              _buildFAQTile(
                question: 'Can I have multiple rooms?',
                answer:
                    'Yes! You can create or join multiple rooms for different living situations.',
              ),
              _buildFAQTile(
                question: 'How do notifications work?',
                answer:
                    'You can customize notification preferences in your profile settings.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Resources',
            icon: Icons.library_books_outlined,
            color: Colors.orange,
            children: [
              _buildResourceTile(
                icon: Icons.article_outlined,
                title: 'User Guide',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening user guide...')),
                  );
                },
              ),
              _buildResourceTile(
                icon: Icons.video_library_outlined,
                title: 'Video Tutorials',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening tutorials...')),
                  );
                },
              ),
              _buildResourceTile(
                icon: Icons.bug_report_outlined,
                title: 'Report a Bug',
                onTap: () =>
                    _launchUrl('mailto:mohdrazakhan32@gmail.com?subject=Bug Report'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Legal',
            icon: Icons.gavel_rounded,
            color: Colors.purple,
            children: [
              _buildResourceTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening privacy policy...')),
                  );
                },
              ),
              _buildResourceTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening terms of service...'),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  Widget _buildResourceTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  Widget _buildFAQTile({required String question, required String answer}) {
    return ExpansionTile(
      leading: const Icon(
        Icons.question_answer_outlined,
        color: Colors.deepPurple,
      ),
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}

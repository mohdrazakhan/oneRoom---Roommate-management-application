// lib/screens/profile/support_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'user_guide_screen.dart';
import 'report_bug_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _showAllFAQs = false;

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
                subtitle: 'care.oneroom@gmail.com',
                onTap: () => _launchUrl('mailto:care.oneroom@gmail.com'),
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
                question: 'How do I create or join a room?',
                answer:
                    'To create a room, tap "Create Room" on the dashboard and enter room details. To join, tap "Join Room" and enter the room code shared by a roommate, or scan the QR code.',
              ),
              _buildFAQTile(
                question: 'How do I add roommates?',
                answer:
                    'Go to your room, tap the three-dot menu, select "Add Member", then share the room code or QR code. Your roommate can join by entering the code or scanning the QR.',
              ),
              _buildFAQTile(
                question: 'How are expenses split?',
                answer:
                    'When adding an expense, you can choose: Equal split (divided equally), Exact amounts (specify each person\'s share), or Percentage split. The app automatically calculates who owes what and tracks settlements.',
              ),
              if (_showAllFAQs) ...[
                _buildFAQTile(
                  question: 'How do task assignments work?',
                  answer:
                      'Create task categories, add tasks with schedules (daily, weekly, custom). Tasks rotate automatically among selected members. You can swap tasks with roommates, and everyone gets notifications for their assignments.',
                ),
                _buildFAQTile(
                  question: 'Can I have multiple rooms?',
                  answer:
                      'Yes! You can create or join multiple rooms for different living situations. Switch between rooms from the dashboard to manage each one independently.',
                ),
                _buildFAQTile(
                  question: 'How do notifications work?',
                  answer:
                      'You can customize notification preferences in Profile > Notifications. Control: Push Notifications (master toggle), Task Reminders, Expense Reminders, Chat Notifications, and Expense/Payment Alerts individually.',
                ),
                _buildFAQTile(
                  question: 'How does the chat feature work?',
                  answer:
                      'Each room has a dedicated chat. Send text messages, images, videos, polls, payment reminders, and link expenses or tasks. Tap linked items to view full details.',
                ),
                _buildFAQTile(
                  question: 'How do I settle expenses?',
                  answer:
                      'View any expense to see who owes what. Tap "Settle" next to your name when you\'ve paid your share. The expense shows as fully settled when everyone has paid.',
                ),
                _buildFAQTile(
                  question: 'Can I edit or delete tasks and expenses?',
                  answer:
                      'Yes! Tap the three-dot menu on any task or expense to edit or delete. Changes sync automatically for all room members.',
                ),
                _buildFAQTile(
                  question: 'How do I view all members across my rooms?',
                  answer:
                      'From the dashboard, tap the "Members" card to see a comprehensive list of all unique members from all your rooms, grouped by room.',
                ),
                _buildFAQTile(
                  question: 'How do I manage my profile?',
                  answer:
                      'Go to Profile to update your name, tagline, date of birth, profile photo, password, and notification settings. You can also remove your profile photo if needed.',
                ),
                _buildFAQTile(
                  question: 'What if I want to leave a room?',
                  answer:
                      'Go to the room, tap the menu, and select "Leave Room". Note: If you\'re the creator and last member, the room will be deleted.',
                ),
              ],
              // Show More/Less Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAllFAQs = !_showAllFAQs;
                      });
                    },
                    icon: Icon(
                      _showAllFAQs
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.green,
                    ),
                    label: Text(
                      _showAllFAQs ? 'Show Less' : 'Show More Questions',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserGuideScreen(),
                    ),
                  );
                },
              ),
              _buildResourceTile(
                icon: Icons.video_library_outlined,
                title: 'Video Tutorials',
                onTap: () =>
                    _launchUrl('https://www.youtube.com/@care.oneroom'),
              ),
              _buildResourceTile(
                icon: Icons.bug_report_outlined,
                title: 'Report a Bug',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportBugScreen(),
                    ),
                  );
                },
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              _buildResourceTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TermsOfServiceScreen(),
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
            color: Colors.grey.withValues(alpha: 0.1),
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
                    color: color.withValues(alpha: 0.1),
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

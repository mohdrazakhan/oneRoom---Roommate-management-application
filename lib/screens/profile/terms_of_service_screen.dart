// lib/screens/profile/terms_of_service_screen.dart
import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            title: 'Introduction',
            content:
                'Welcome to OneRoom! These Terms of Service ("Terms") govern your use of the OneRoom mobile application and services. By using OneRoom, you agree to these Terms. Please read them carefully.',
          ),
          _buildSection(
            title: '1. Acceptance of Terms',
            content:
                'By creating an account and using OneRoom, you acknowledge that you have read, understood, and agree to be bound by these Terms. If you do not agree to these Terms, please do not use our services.',
          ),
          _buildSection(
            title: '2. Description of Service',
            content:
                'OneRoom is a roommate management application that helps you:\n\n'
                '• Create and join rooms with roommates\n'
                '• Track and split expenses equally, by exact amounts, or by percentage\n'
                '• Manage and assign household tasks with automatic rotation\n'
                '• Communicate via in-room chat with text, images, videos, and polls\n'
                '• Receive notifications for tasks, expenses, and messages\n'
                '• View member information across all your rooms\n'
                '• Settle payments and track who owes what',
          ),
          _buildSection(
            title: '3. User Accounts',
            content:
                'To use OneRoom, you must:\n\n'
                '• Be at least 13 years of age\n'
                '• Provide accurate and complete registration information\n'
                '• Maintain the security of your account credentials\n'
                '• Notify us immediately of any unauthorized access\n'
                '• Be responsible for all activities under your account\n'
                '• Not share your account with others',
          ),
          _buildSection(
            title: '4. User Conduct',
            content:
                'You agree to:\n\n'
                '• Use the service only for lawful purposes\n'
                '• Respect other users and communicate courteously\n'
                '• Provide accurate expense and task information\n'
                '• Not harass, abuse, or harm other users\n'
                '• Not upload malicious content or spam\n'
                '• Not attempt to gain unauthorized access to the service\n'
                '• Not use the service for any illegal activities\n'
                '• Respect intellectual property rights',
          ),
          _buildSection(
            title: '5. Rooms and Memberships',
            content:
                '• You can create multiple rooms or join existing ones\n'
                '• Room creators can add members via invite codes or QR codes\n'
                '• Members can view all room data including expenses, tasks, and chat\n'
                '• You can leave a room at any time\n'
                '• If you\'re the creator and last member, the room will be deleted\n'
                '• Room data is shared among all members',
          ),
          _buildSection(
            title: '6. Expenses and Financial Data',
            content:
                '• Expense tracking is for informational purposes only\n'
                '• OneRoom does not process actual payments\n'
                '• You are responsible for settling payments outside the app\n'
                '• The app calculates splits based on your input\n'
                '• Mark expenses as settled when payments are complete\n'
                '• We are not responsible for disputes between roommates',
          ),
          _buildSection(
            title: '7. Tasks and Assignments',
            content:
                '• Tasks are assigned based on rotation schedules you set\n'
                '• You can swap tasks with other members\n'
                '• Task reminders are sent based on your notification settings\n'
                '• Completing tasks is based on the honor system\n'
                '• We are not responsible for task completion disputes',
          ),
          _buildSection(
            title: '8. Content and Messages',
            content:
                '• You retain ownership of content you post\n'
                '• By posting, you grant us license to store and display your content\n'
                '• You are responsible for your messages and uploads\n'
                '• We may remove content that violates these Terms\n'
                '• Chat messages are visible to all room members\n'
                '• Do not share sensitive personal or financial information in chat',
          ),
          _buildSection(
            title: '9. Notifications',
            content:
                '• We send push notifications for app activities\n'
                '• You can control notification preferences in settings\n'
                '• Notification types include: tasks, expenses, chat, and payments\n'
                '• Notifications require device permissions\n'
                '• We use Firebase Cloud Messaging for delivery',
          ),
          _buildSection(
            title: '10. Privacy and Data',
            content:
                '• Your use of OneRoom is subject to our Privacy Policy\n'
                '• We use Firebase services for data storage and authentication\n'
                '• Your data is encrypted and stored securely\n'
                '• We do not sell your personal information\n'
                '• You can delete your account and data at any time',
          ),
          _buildSection(
            title: '11. Intellectual Property',
            content:
                'The OneRoom app, including its design, features, and content, is owned by us and protected by copyright and other intellectual property laws. You may not copy, modify, distribute, or reverse engineer any part of the service.',
          ),
          _buildSection(
            title: '12. Disclaimers',
            content:
                'OneRoom is provided "as is" without warranties of any kind. We do not guarantee:\n\n'
                '• Uninterrupted or error-free service\n'
                '• Accuracy of calculations or data\n'
                '• Resolution of roommate disputes\n'
                '• Actual payment settlements\n'
                '• Data backup or recovery',
          ),
          _buildSection(
            title: '13. Limitation of Liability',
            content:
                'We are not liable for:\n\n'
                '• Disputes between roommates\n'
                '• Financial losses or unpaid expenses\n'
                '• Data loss or corruption\n'
                '• Indirect or consequential damages\n'
                '• Issues arising from third-party services\n'
                '• Unauthorized access to your account',
          ),
          _buildSection(
            title: '14. Account Termination',
            content:
                'We reserve the right to suspend or terminate accounts that:\n\n'
                '• Violate these Terms\n'
                '• Engage in abusive behavior\n'
                '• Attempt to harm the service\n'
                '• Are inactive for extended periods\n\n'
                'You may delete your account at any time from the app settings.',
          ),
          _buildSection(
            title: '15. Changes to Terms',
            content:
                'We may update these Terms from time to time. We will notify you of material changes through the app. Your continued use after changes constitutes acceptance of the updated Terms.',
          ),
          _buildSection(
            title: '16. Contact Information',
            content:
                'If you have questions about these Terms, please contact us:\n\n'
                'Email: care.oneroom@gmail.com\n'
                'Phone: +91 8279677833',
          ),
          _buildSection(
            title: '17. Governing Law',
            content:
                'These Terms are governed by and construed in accordance with applicable laws. Any disputes will be resolved in the appropriate jurisdiction.',
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Last Updated: December 11, 2025',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

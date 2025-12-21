// lib/screens/profile/privacy_policy_screen.dart
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            title: 'Introduction',
            content:
                'Welcome to OneRoom. We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our roommate management application.',
          ),
          _buildSection(
            title: '1. Information We Collect',
            content:
                'We collect information that you provide directly to us, including:\n\n'
                '• Account Information: Name, email address, phone number, profile photo\n'
                '• Room Information: Room names, member lists, room codes\n'
                '• Financial Data: Expense details, payment information, settlement records\n'
                '• Task Data: Task assignments, schedules, completion status\n'
                '• Communication Data: Chat messages, images, videos, polls\n'
                '• Device Information: Device type, operating system, app version\n'
                '• Usage Data: App usage patterns, preferences, notification settings',
          ),
          _buildSection(
            title: '2. How We Use Your Information',
            content:
                'We use the information we collect to:\n\n'
                '• Provide and maintain the OneRoom service\n'
                '• Process and track expenses among roommates\n'
                '• Manage task assignments and schedules\n'
                '• Enable communication between room members\n'
                '• Send notifications about tasks, expenses, and messages\n'
                '• Improve and optimize our services\n'
                '• Respond to your requests and provide customer support\n'
                '• Ensure security and prevent fraud',
          ),
          _buildSection(
            title: '3. Data Storage and Security',
            content:
                'Your data is stored securely using Firebase Cloud Firestore and Firebase Storage. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.\n\n'
                'Your data includes:\n'
                '• Profile information and photos\n'
                '• Expense records and financial calculations\n'
                '• Task assignments and completion history\n'
                '• Chat messages and media files\n'
                '• Notification preferences',
          ),
          _buildSection(
            title: '4. Data Sharing',
            content:
                'We do not sell or rent your personal information to third parties. We only share your information:\n\n'
                '• With other members in your rooms (as necessary for app functionality)\n'
                '• With Firebase services (Google) for data storage and authentication\n'
                '• When required by law or to protect our rights\n'
                '• With your explicit consent',
          ),
          _buildSection(
            title: '5. Your Rights',
            content:
                'You have the right to:\n\n'
                '• Access your personal data\n'
                '• Update or correct your information\n'
                '• Delete your account and associated data\n'
                '• Control notification preferences\n'
                '• Leave rooms and remove your participation\n'
                '• Export your data (contact us for assistance)',
          ),
          _buildSection(
            title: '6. Notifications',
            content:
                'We send push notifications for:\n\n'
                '• New chat messages\n'
                '• Expense additions, edits, and deletions\n'
                '• Task assignments and reminders\n'
                '• Task swap requests and responses\n\n'
                'You can customize notification preferences in Profile > Notifications, including:\n'
                '• Push Notifications (master toggle)\n'
                '• Task Reminders\n'
                '• Expense Reminders\n'
                '• Chat Notifications\n'
                '• Expense/Payment Alerts',
          ),
          _buildSection(
            title: '7. Children\'s Privacy',
            content:
                'OneRoom is not intended for users under the age of 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us.',
          ),
          _buildSection(
            title: '8. Changes to Privacy Policy',
            content:
                'We may update this privacy policy from time to time. We will notify you of any changes by posting the new privacy policy in the app. You are advised to review this privacy policy periodically for any changes.',
          ),
          _buildSection(
            title: '9. Contact Us',
            content:
                'If you have any questions about this privacy policy or our data practices, please contact us:\n\n'
                'Email: care.oneroom@gmail.com\n'
                'Phone: +91 8279677833',
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

// lib/screens/profile/user_guide_screen.dart
import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final headline = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);

    return Scaffold(
      appBar: AppBar(title: const Text('User Guide')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroCard(headline),
          const SizedBox(height: 16),
          _buildCardSection(
            icon: Icons.rocket_launch_rounded,
            color: Colors.deepPurple,
            title: 'Quick Start (3 steps)',
            bullets: const [
              'Create or join a room (code/QR) from the dashboard.',
              'Add roommates via room menu > Add Member.',
              'Finish profile and set notifications (Profile > Notifications).',
            ],
          ),
          _buildCardSection(
            icon: Icons.receipt_long_rounded,
            color: Colors.orange,
            title: 'Expenses & Payments',
            bullets: const [
              'Add expenses with equal, exact, or percentage split; attach receipts.',
              'See who owes what; tap “Settle” when someone pays.',
              'Use Expense/Payment Alerts toggle to control notifications.',
            ],
          ),
          _buildCardSection(
            icon: Icons.task_alt_rounded,
            color: Colors.blue,
            title: 'Tasks & Reminders',
            bullets: const [
              'Create categories and schedule tasks (daily/weekly/custom).',
              'Tasks rotate automatically; swap with roommates when needed.',
              'Turn on Task Reminders to get timely pings.',
            ],
          ),
          _buildCardSection(
            icon: Icons.chat_bubble_rounded,
            color: Colors.teal,
            title: 'Chat & Links',
            bullets: const [
              'Send messages, images, videos, polls, and payment reminders.',
              'Link expenses or tasks from chat and tap to open details.',
              'Mute or tweak Chat Notifications in Profile > Notifications.',
            ],
          ),
          _buildCardSection(
            icon: Icons.group_rounded,
            color: Colors.green,
            title: 'Members',
            bullets: const [
              'View members per room, or “All Members” across rooms from dashboard.',
              'Invite via code/QR; remove or leave rooms from the room menu.',
            ],
          ),
          _buildCardSection(
            icon: Icons.verified_user_rounded,
            color: Colors.pink,
            title: 'Profile & Security',
            bullets: const [
              'Update name, tagline, DOB, and profile photo (add/remove).',
              'Change password; manage all notification toggles.',
              'If something looks off, pull to refresh; sign out/in if needed.',
            ],
          ),
          const SizedBox(height: 12),
          _buildTipBox(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroCard(TextStyle? headline) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'OneRoom Quick Guide',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Set up your room, split expenses, assign tasks, and stay aligned with your roommates.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroPill(label: 'Create/Join Room'),
              _HeroPill(label: 'Invite Roommates'),
              _HeroPill(label: 'Add Expenses'),
              _HeroPill(label: 'Schedule Tasks'),
              _HeroPill(label: 'Chat & Notify'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> bullets,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Need help? Email Support from Customer Care. If something looks off, pull to refresh or sign out/in.',
              style: TextStyle(color: Colors.grey[800], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;

  const _HeroPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// lib/screens/profile/about_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final List<String> _expandedSections = [];

  void _toggleSection(String section) {
    setState(() {
      if (_expandedSections.contains(section)) {
        _expandedSections.remove(section);
      } else {
        _expandedSections.add(section);
      }
    });
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF5B3FE6),
                      Color(0xFF7C5DEE),
                      Color(0xFF9B7FED),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image.asset(
                        'assets/Images/logo.png',
                        height: 100,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.home_rounded,
                              size: 100,
                              color: Colors.white,
                            ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'One Room',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About Section
                  _buildExpandableSection(
                    context,
                    'About',
                    'One Room is a comprehensive roommate management app designed to make shared living easier and more organized. Manage tasks, track expenses, and coordinate with your roommates all in one place.',
                  ),
                  const SizedBox(height: 20),

                  // Features Section
                  _buildExpandableSection(
                    context,
                    'Features',
                    '',
                    isFeatures: true,
                  ),
                  const SizedBox(height: 20),

                  // Developer Section
                  _buildDeveloperCard(context),
                  const SizedBox(height: 20),

                  // Organization Section
                  _buildOrganizationCard(context),
                  const SizedBox(height: 20),

                  // Connect Section
                  _buildConnectSection(context),
                  const SizedBox(height: 20),

                  // Footer
                  const Divider(height: 32),
                  Center(
                    child: Text(
                      '© 2025 One Room. All rights reserved.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Built with ❤️ for roommates',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.deepPurple[400],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection(
    BuildContext context,
    String title,
    String description, {
    bool isFeatures = false,
  }) {
    final isExpanded = _expandedSections.contains(title);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleSection(title),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade50, Colors.blue.shade50],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B3FE6),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Color(0xFF5B3FE6),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.grey[700],
                      ),
                    ),
                  if (isFeatures) ...[
                    _buildFeatureItem(
                      Icons.task_alt_rounded,
                      'Task Management',
                      'Create and assign tasks to roommates',
                      Colors.blue.shade600,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      Icons.attach_money_rounded,
                      'Expense Tracking',
                      'Split bills and track shared expenses',
                      Colors.amber.shade600,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      Icons.groups_rounded,
                      'Room Management',
                      'Manage multiple rooms and members',
                      Colors.green.shade600,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      Icons.notifications_active_rounded,
                      'Smart Notifications',
                      'Stay updated with personalized reminders',
                      Colors.red.shade600,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      Icons.chat_rounded,
                      'Room Chat',
                      'Communicate with roommates in real-time',
                      Colors.indigo.shade600,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6D4FE6), Color(0xFF8B6FEE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF5B3FE6).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Developer',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mohd Raza Khan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContactLink(
            Icons.email_rounded,
            'Email',
            'mohdrazakhan32@gmail.com',
            'mailto:mohdrazakhan32@gmail.com',
          ),
          const SizedBox(height: 12),
          _buildContactLink(
            Icons.phone_rounded,
            'Mobile',
            '+91 8279677833',
            'tel:+918279677833',
          ),
          const SizedBox(height: 12),
          _buildContactLink(
            Icons.work_rounded,
            'LinkedIn',
            'linkedin.com/in/mohdrazakhan32',
            'https://www.linkedin.com/in/mohdrazakhan32',
          ),
        ],
      ),
    );
  }

  Widget _buildContactLink(
    IconData icon,
    String label,
    String value,
    String url,
  ) {
    return InkWell(
      onTap: () => _launchURL(url),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.open_in_new_rounded,
            color: Colors.white.withValues(alpha: 0.6),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFB923C), Color(0xFFFFB84D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFB923C).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Organization',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'One Room',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContactLink(
            Icons.email_rounded,
            'Email',
            'care.oneroom@gmail.com',
            'mailto:care.oneroom@gmail.com',
          ),
          const SizedBox(height: 12),
          _buildContactLink(
            Icons.play_circle_rounded,
            'YouTube Channel',
            'youtube.com/@care.oneroom',
            'https://www.youtube.com/@care.oneroom',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect With Us',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5B3FE6),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSocialButton(
                icon: Icons.language_rounded,
                label: 'Website',
                onTap: () => _launchURL('https://www.mohdrazakhan.me'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSocialButton(
                icon: Icons.play_circle_rounded,
                label: 'YouTube',
                onTap: () =>
                    _launchURL('https://www.youtube.com/@care.oneroom'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFF7C5DEE), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Color(0xFF5B3FE6), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B3FE6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

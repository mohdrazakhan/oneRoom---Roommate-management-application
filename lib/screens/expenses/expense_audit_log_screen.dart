import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';

class ExpenseAuditLogScreen extends StatelessWidget {
  final String roomId;

  const ExpenseAuditLogScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Activity Log'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestoreService.getRoomAuditLogStream(roomId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final List<Map<String, dynamic>> logs = snapshot.data ?? const [];

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No activity yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final Map<String, dynamic> logData = logs[index];
              final log = AuditLogEntry(
                action: logData['action'] ?? 'unknown',
                performedBy: logData['performedBy'] ?? '',

                timestamp: logData['timestamp'] ?? DateTime.now(),
                expenseDescription: logData['expenseDescription'],
                changes: logData['changes'] != null
                    ? Map<String, String>.from(logData['changes'])
                    : null,
              );
              return _buildLogEntry(context, log, firestoreService);
            },
          );
        },
      ),
    );
  }

  Widget _buildLogEntry(
    BuildContext context,
    AuditLogEntry log,
    FirestoreService firestoreService,
  ) {
    return FutureBuilder<String>(
      future: _getUserName(firestoreService, log.performedBy),
      builder: (context, snapshot) {
        final userName = snapshot.data ?? 'Loading...';

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon based on action
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getActionColor(log.action).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getActionIcon(log.action),
                  color: _getActionColor(log.action),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action description
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: userName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' ${_getActionText(log.action)} '),
                          if (log.expenseDescription != null)
                            TextSpan(
                              text: '"${log.expenseDescription}"',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Changes detail
                    if (log.changes != null && log.changes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...log.changes!.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }),
                    ],

                    // Timestamp
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(log.timestamp),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              // Lock icon to show it's uneditable
              Icon(Icons.lock_outline, size: 16, color: Colors.grey[400]),
            ],
          ),
        );
      },
    );
  }

  Future<String> _getUserName(FirestoreService service, String uid) async {
    try {
      final profiles = await service.getUsersProfiles([uid]);
      final profile = profiles[uid];
      return profile?['displayName'] ??
          profile?['name'] ??
          profile?['email']?.split('@')[0] ??
          'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return Icons.add_circle_outline;
      case 'updated':
      case 'edited':
        return Icons.edit_outlined;
      case 'deleted':
        return Icons.delete_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return Colors.green;
      case 'updated':
      case 'edited':
        return Colors.orange;
      case 'deleted':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getActionText(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return 'added expense';
      case 'updated':
      case 'edited':
        return 'edited expense';
      case 'deleted':
        return 'deleted expense';
      default:
        return action;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Model for audit log entries displayed in the UI
class AuditLogEntry {
  final String action;
  final String performedBy;
  final DateTime timestamp;
  final String? expenseDescription;
  final Map<String, String>? changes;

  AuditLogEntry({
    required this.action,
    required this.performedBy,
    required this.timestamp,
    this.expenseDescription,
    this.changes,
  });
}

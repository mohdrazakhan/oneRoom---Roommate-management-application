import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'package:intl/intl.dart';

class MyTasksDashboard extends StatefulWidget {
  const MyTasksDashboard({super.key});

  @override
  State<MyTasksDashboard> createState() => _MyTasksDashboardState();
}

class _MyTasksDashboardState extends State<MyTasksDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestoreService = FirestoreService();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Don't auto-generate on init - let user trigger it manually or when tasks are created
  }

  Future<void> _generateTaskInstances() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || _isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      await _firestoreService.generateTaskInstancesForUser(currentUserId);
    } catch (e) {
      debugPrint('Error generating task instances: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  // ignore: unused_element
  Future<void> _clearAndRegenerateTaskInstances() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || _isGenerating) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear & Regenerate Tasks'),
        content: const Text(
          'This will delete all existing task instances and create new ones with updated information. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear & Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      // Get all rooms for this user
      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where('members', arrayContains: currentUserId)
          .get();

      // Delete all task instances for each room
      for (var roomDoc in roomsSnapshot.docs) {
        await _firestoreService.deleteAllTaskInstances(roomDoc.id);
      }

      // Regenerate task instances
      await _firestoreService.generateTaskInstancesForUser(currentUserId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task instances regenerated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing and regenerating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Tasks')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              tooltip: 'Generate Task Schedule',
              onPressed: _generateTaskInstances,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.today_rounded), text: 'Today'),
            Tab(icon: Icon(Icons.upcoming_rounded), text: 'Upcoming'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTasks(currentUserId),
          _buildUpcomingTasks(currentUserId),
        ],
      ),
    );
  }

  Widget _buildTodayTasks(String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getTodayTasksForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final tasks = snapshot.data ?? [];

        if (tasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'No tasks for today',
            subtitle: 'Enjoy your free time!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return _buildTodayTaskCard(tasks[index], userId);
          },
        );
      },
    );
  }

  Widget _buildUpcomingTasks(String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getUpcomingTasksForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final tasks = snapshot.data ?? [];

        if (tasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_available,
            title: 'No upcoming tasks',
            subtitle: 'Tasks assigned to you will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return _buildUpcomingTaskCard(tasks[index], userId);
          },
        );
      },
    );
  }

  Widget _buildTodayTaskCard(Map<String, dynamic> taskData, String userId) {
    final title = taskData['title'] ?? taskData['taskTitle'] ?? 'Task';
    final roomName = taskData['roomName'] ?? 'Unknown Room';
    final isCompleted = taskData['isCompleted'] == true;
    final roomId = taskData['roomId'];
    final taskInstanceId = taskData['taskInstanceId'];
    final swappedWith = taskData['swappedWith'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: Checkbox(
              value: isCompleted,
              onChanged: (value) {
                if (value != null) {
                  _markTaskAsCompleted(roomId, taskInstanceId, value);
                }
              },
              shape: const CircleBorder(),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      roomName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCompleted ? '✓ Completed' : '⏳ Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Show swap info if task was swapped
          if (swappedWith != null) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Swapped with ${swappedWith['userName'] ?? 'Member'} by ${swappedWith['swappedBy'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingTaskCard(Map<String, dynamic> taskData, String userId) {
    final title = taskData['title'] ?? taskData['taskTitle'] ?? 'Task';
    final roomName = taskData['roomName'] ?? 'Unknown Room';
    final dueDate = (taskData['scheduledDate'] as Timestamp?)?.toDate();
    final swapRequest = taskData['swapRequest'] as Map<String, dynamic>?;
    final swappedWith = taskData['swappedWith'] as Map<String, dynamic>?;
    final roomId = taskData['roomId'];
    final taskInstanceId = taskData['taskInstanceId'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.task_alt,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      roomName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (dueDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(dueDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'swap') {
                  _showSwapDialog(roomId, taskInstanceId, taskData);
                } else if (value == 'reschedule') {
                  _showRescheduleDialog(roomId, taskInstanceId);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'swap',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz),
                      SizedBox(width: 8),
                      Text('Swap with someone'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reschedule',
                  child: Row(
                    children: [
                      Icon(Icons.schedule),
                      SizedBox(width: 8),
                      Text('Request Reschedule'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Show swap info if task was swapped
          if (swappedWith != null) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Swapped with ${swappedWith['userName'] ?? 'Member'} by ${swappedWith['swappedBy'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (swapRequest != null) ...[
            const Divider(height: 1),
            _buildSwapRequestBanner(
              swapRequest,
              userId,
              roomId,
              taskInstanceId,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwapRequestBanner(
    Map<String, dynamic> swapRequest,
    String userId,
    String roomId,
    String taskInstanceId,
  ) {
    final targetId = swapRequest['targetId'];
    final status = swapRequest['status'] ?? 'pending';
    final requesterName = swapRequest['requesterName'] ?? 'Someone';
    final targetName = swapRequest['targetName'] ?? 'Someone';

    if (status == 'approved' || status == 'rejected') {
      return Container(
        padding: const EdgeInsets.all(12),
        color: status == 'approved' ? Colors.green[50] : Colors.red[50],
        child: Row(
          children: [
            Icon(
              status == 'approved' ? Icons.check_circle : Icons.cancel,
              color: status == 'approved' ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status == 'approved'
                    ? 'Swap approved with $targetName'
                    : 'Swap request rejected',
                style: TextStyle(
                  fontSize: 13,
                  color: status == 'approved'
                      ? Colors.green[900]
                      : Colors.red[900],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Pending swap request
    final isTarget = targetId == userId;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.blue[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTarget
                      ? '$requesterName wants to swap with you'
                      : 'Waiting for $targetName to approve swap',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
          if (isTarget) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      _respondToSwapRequest(roomId, taskInstanceId, false),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      _respondToSwapRequest(roomId, taskInstanceId, true),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _markTaskAsCompleted(
    String roomId,
    String taskInstanceId,
    bool isCompleted,
  ) async {
    try {
      await _firestoreService.markTaskInstanceAsCompleted(
        roomId,
        taskInstanceId,
        isCompleted,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCompleted
                  ? 'Task marked as completed!'
                  : 'Task marked as pending',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showSwapDialog(
    String roomId,
    String taskInstanceId,
    Map<String, dynamic> taskData,
  ) async {
    final members = await _firestoreService.getRoomMembers(roomId);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (!mounted) return;

    final selectedMember = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Swap Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a member to swap this task with:'),
            const SizedBox(height: 16),
            ...members
                .where((m) => m['uid'] != currentUserId)
                .map(
                  (member) => ListTile(
                    leading: CircleAvatar(
                      child: Text(member['displayName'][0].toUpperCase()),
                    ),
                    title: Text(member['displayName']),
                    onTap: () => Navigator.pop(context, member),
                  ),
                ),
          ],
        ),
      ),
    );

    if (selectedMember != null) {
      try {
        await _firestoreService.createSwapRequest(
          roomId: roomId,
          taskInstanceId: taskInstanceId,
          targetUserId: selectedMember['uid'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Swap request sent!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showRescheduleDialog(
    String roomId,
    String taskInstanceId,
  ) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      try {
        await _firestoreService.requestReschedule(
          roomId: roomId,
          taskInstanceId: taskInstanceId,
          newDate: selectedDate,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reschedule request sent!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _respondToSwapRequest(
    String roomId,
    String taskInstanceId,
    bool approve,
  ) async {
    try {
      await _firestoreService.respondToSwapRequest(
        roomId: roomId,
        taskInstanceId: taskInstanceId,
        approve: approve,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Swap approved!' : 'Swap rejected'),
            backgroundColor: approve ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

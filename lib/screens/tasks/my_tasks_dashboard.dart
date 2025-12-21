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
      body: Column(
        children: [
          _buildIncomingSwapRequests(currentUserId),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTasks(currentUserId),
                _buildUpcomingTasks(currentUserId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingSwapRequests(String userId) {
    return Column(
      children: [
        // 1. Incoming offers for tasks I wanted to swap (Phase 3: Finalize)
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.getSwapOffersForUser(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              color: Colors.amber.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 20,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Received Offers',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150, // Slightly taller for buttons
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return _buildSwapOfferCard(
                          snapshot.data![index],
                          userId,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 2. Incoming requests from others (Phase 1: Propose)
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.roomsForUser(userId),
          builder: (context, roomSnapshot) {
            if (!roomSnapshot.hasData || roomSnapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              children: roomSnapshot.data!.map((room) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestoreService.getPendingSwapRequests(
                    room['id'],
                    userId,
                  ),
                  builder: (ctx, snap) {
                    if (!snap.hasData || snap.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _buildRoomSwapRequestsSection(
                      room['name'] ?? 'Room',
                      snap.data!,
                      userId,
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSwapOfferCard(Map<String, dynamic> task, String userId) {
    final title = task['title'] ?? 'Task';
    final request = task['swapRequest'] ?? {};
    final responderName = request['responderName'] ?? 'Unknown';
    final offeredTaskTitle = request['offeredTaskTitle'] ?? 'Task';
    final offeredTaskDate = (request['offeredTaskDate'] as Timestamp?)
        ?.toDate();

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$responderName offers:',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                offeredTaskTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (offeredTaskDate != null)
                Text(
                  DateFormat('MMM dd').format(offeredTaskDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              const SizedBox(height: 4),
              Text(
                'for your task: "$title"',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _finalizeSwap(task, false),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _finalizeSwap(task, true),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeSwap(Map<String, dynamic> task, bool approve) async {
    final roomId = task['roomId'];
    final taskInstanceId = task['taskInstanceId'];
    if (roomId == null || taskInstanceId == null) return;

    try {
      if (approve) {
        // Show loading or optimistic update?
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Finalizing swap...')));
      }

      await _firestoreService.finalizeSwap(
        roomId: roomId,
        taskInstanceId: taskInstanceId,
        approve: approve,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Swap completed successfully!' : 'Swap offer rejected.',
            ),
            backgroundColor: approve ? Colors.green : Colors.grey,
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

  Widget _buildRoomSwapRequestsSection(
    String roomName,
    List<Map<String, dynamic>> requests,
    String userId,
  ) {
    return Container(
      color: Colors.blue.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Swap Requests in $roomName',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${requests.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: requests.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final req = requests[index];
                return _buildSwapRequestCard(req, userId);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapRequestCard(Map<String, dynamic> task, String userId) {
    final title = task['title'] ?? 'Task';
    final request = task['swapRequest'] ?? {};
    final requesterName = request['requesterName'] ?? 'Unknown';
    final date = (task['scheduledDate'] as Timestamp?)?.toDate();

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$requesterName asks to swap:',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (date != null)
                Text(
                  DateFormat('MMM dd').format(date),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showSwapOfferDialog(task),
              style: ElevatedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('View & Respond'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSwapOfferDialog(Map<String, dynamic> incomingTask) async {
    final roomId = incomingTask['roomId'];
    final incomingTaskInstanceId = incomingTask['taskInstanceId'];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || roomId == null) return;

    // Fetch my upcoming tasks
    // We can't reuse the stream easily, so we'll fetch once or listen
    // For simplicity, fetch once
    final myTasksSnapshot = await _firestoreService
        .getUpcomingTasksForUser(currentUserId)
        .first;
    // Filter tasks from same room? Not strictly required but better for roommates.
    // Filter tasks that are NOT pending or completed
    final myOfferableTasks = myTasksSnapshot.where((t) {
      return t['roomId'] == roomId &&
          t['isCompleted'] != true &&
          t['assignedTo'] == currentUserId;
    }).toList();

    if (!mounted) return;

    final selectedTask = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offer a Swap'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select one of your tasks to offer in exchange for "${incomingTask['title']}":',
              ),
              const SizedBox(height: 12),
              if (myOfferableTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'You have no upcoming tasks in this room to offer.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: myOfferableTasks.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final t = myOfferableTasks[i];
                      final date = (t['scheduledDate'] as Timestamp?)?.toDate();
                      return ListTile(
                        title: Text(t['title'] ?? 'Task'),
                        subtitle: date != null
                            ? Text(DateFormat('MMM dd').format(date))
                            : null,
                        onTap: () => Navigator.pop(context, t),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedTask != null) {
      _proposeSwap(
        roomId,
        incomingTaskInstanceId,
        selectedTask['taskInstanceId'],
      );
    }
  }

  Future<void> _proposeSwap(
    String roomId,
    String targetTaskInstanceId,
    String offeredTaskInstanceId,
  ) async {
    try {
      await _firestoreService.proposeSwap(
        roomId: roomId,
        taskInstanceId: targetTaskInstanceId, // Task I want
        offeredTaskInstanceId: offeredTaskInstanceId, // Task I give
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Swap proposal sent! Waiting for approval.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error proposing swap: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

        // Deduplicate: Show only next upcoming instance for each task
        final uniqueTasks = <Map<String, dynamic>>[];
        final seenTaskIds = <String>{};

        for (var task in tasks) {
          final taskId = task['taskId'] as String?;
          if (taskId != null && !seenTaskIds.contains(taskId)) {
            seenTaskIds.add(taskId);
            uniqueTasks.add(task);
          }
        }

        if (uniqueTasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_available,
            title: 'No upcoming tasks',
            subtitle: 'Tasks assigned to you will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: uniqueTasks.length,
          itemBuilder: (context, index) {
            return _buildUpcomingTaskCard(uniqueTasks[index], userId);
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
    final assignedTo = taskData['assignedTo'];
    final isVolunteer = assignedTo == 'volunteer';

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
            leading: isVolunteer
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pan_tool_outlined,
                      color: Colors.blue,
                      size: 20,
                    ),
                  )
                : Checkbox(
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
                    color: isCompleted
                        ? Colors.green[50]
                        : (isVolunteer ? Colors.blue[50] : Colors.orange[50]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCompleted
                        ? '✓ Completed'
                        : (isVolunteer ? '✋ Volunteer Needed' : '⏳ Pending'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? Colors.green[700]
                          : (isVolunteer
                                ? Colors.blue[700]
                                : Colors.orange[700]),
                    ),
                  ),
                ),
              ],
            ),
            trailing: isVolunteer
                ? ElevatedButton(
                    onPressed: () => _claimTask(roomId, taskInstanceId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Volunteer'),
                  )
                : null,
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
    final assignedTo = taskData['assignedTo'];
    final isVolunteer = assignedTo == 'volunteer';

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
                color: isVolunteer
                    ? Colors.blue[50]
                    : Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isVolunteer ? Icons.pan_tool_outlined : Icons.task_alt,
                color: isVolunteer
                    ? Colors.blue
                    : Theme.of(context).colorScheme.primary,
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
                if (isVolunteer) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '✋ Volunteer Needed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: isVolunteer
                ? ElevatedButton(
                    onPressed: () => _claimTask(roomId, taskInstanceId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Volunteer'),
                  )
                : PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'swap') {
                        _showSwapDialog(roomId, taskInstanceId, taskData);
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
                  onPressed: () => _showSwapOfferDialog({
                    'roomId': roomId,
                    'taskInstanceId': taskInstanceId,
                    'title': 'Task',
                    'swapRequest': swapRequest,
                  }),
                  child: const Text('Propose Task'),
                ),
              ],
            ),
          ] else ...[
            // I am Requester. Show Withdraw.
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _withdrawSwapRequest(roomId, taskInstanceId),
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                label: const Text(
                  'Withdraw Request',
                  style: TextStyle(color: Colors.red),
                ),
              ),
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
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.groups_rounded, color: Colors.white),
              ),
              title: const Text('Open to All (Anyone can accept)'),
              subtitle: const Text('Post request to whole room'),
              onTap: () => Navigator.pop(context, {
                'uid': 'anyone',
                'displayName': 'Anyone',
              }),
            ),
            const Divider(),
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
          targetUserId: selectedMember['uid'] == 'anyone'
              ? null
              : selectedMember['uid'],
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

  // ... (keep existing methods)

  Future<void> _claimTask(String roomId, String taskInstanceId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('taskInstances')
          .doc(taskInstanceId)
          .update({'assignedTo': currentUserId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task claimed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _respondToSwapRequest(
    String roomId,
    String taskInstanceId,
    bool approve,
  ) async {
    try {
      await _firestoreService.finalizeSwap(
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

  Future<void> _withdrawSwapRequest(
    String roomId,
    String taskInstanceId,
  ) async {
    try {
      await _firestoreService.withdrawSwapRequest(
        roomId: roomId,
        taskInstanceId: taskInstanceId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request withdrawn'),
            backgroundColor: Colors.orange,
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

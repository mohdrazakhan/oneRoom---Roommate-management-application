// lib/screens/tasks/category_tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Models/task_category.dart';
import '../../Models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/rooms_provider.dart';
import '../../services/firestore_service.dart';
import 'create_task_sheet.dart';

class CategoryTasksScreen extends StatefulWidget {
  final TaskCategory category;
  final String roomId;

  const CategoryTasksScreen({
    super.key,
    required this.category,
    required this.roomId,
  });

  @override
  State<CategoryTasksScreen> createState() => _CategoryTasksScreenState();
}

class _CategoryTasksScreenState extends State<CategoryTasksScreen> {
  late String _categoryName;
  Map<String, Map<String, dynamic>> _memberProfiles = {}; // uid -> profile

  @override
  void initState() {
    super.initState();
    _categoryName = widget.category.name;
    _loadMemberProfiles();
  }

  Future<void> _loadMemberProfiles() async {
    final roomsProvider = context.read<RoomsProvider>();
    final room = roomsProvider.getRoomById(widget.roomId);
    if (room == null) return;

    try {
      final profiles = await FirestoreService().getUsersProfiles(room.members);
      profiles.forEach((uid, profile) {});
      if (mounted) {
        setState(() {
          _memberProfiles = profiles;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading profiles: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _getMemberDisplayName(String uid) {
    final profile = _memberProfiles[uid];
    if (profile == null) {
      return 'Member ${uid.substring(0, 4)}';
    } // Try different field names that might exist
    final displayName = profile['displayName'];
    final name = profile['name'];
    final email = profile['email'];

    // Return first available identifier
    if (displayName != null && displayName.toString().isNotEmpty) {
      return displayName.toString();
    }
    if (name != null && name.toString().isNotEmpty) {
      return name.toString();
    }
    if (email != null) {
      final emailStr = email.toString();
      if (emailStr.contains('@')) {
        return emailStr.split('@')[0]; // Return part before @
      }
      return emailStr;
    }

    return 'Member ${uid.substring(0, 4)}';
  }

  Future<void> _promptRename(BuildContext context) async {
    final controller = TextEditingController(text: _categoryName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new name'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (newName != null && newName.isNotEmpty) {
      if (!context.mounted) return;
      await context.read<TasksProvider>().renameCategory(
        widget.roomId,
        widget.category.id,
        newName,
      );
      if (!mounted) return;
      setState(() => _categoryName = newName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category renamed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showEditTask(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTaskSheet(
        roomId: widget.roomId,
        category: widget.category,
        existingTask: task,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: 'category-icon-${widget.category.id}',
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.category.icon,
                  color: widget.category.color,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _categoryName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'rename') {
                _promptRename(context);
              } else if (value == 'delete') {
                _confirmDelete(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Rename Category'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Delete Category',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Task>>(
        stream: context.read<TasksProvider>().getTasksStream(
          widget.roomId,
          widget.category.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              return _buildTaskCard(context, tasks[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTask(context),
        backgroundColor: widget.category.color,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: widget.category.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.category.icon,
              size: 80,
              color: widget.category.color,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tasks in $_categoryName',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Create your first task to get started with organizing ${_categoryName.toLowerCase()}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showCreateTask(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.category.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Task'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task) {
    final tasksProvider = context.read<TasksProvider>();
    final assignee = tasksProvider.getCurrentAssignee(task);
    final service = context.read<FirestoreService>();
    final today = DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (task.description != null &&
                          task.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEditTask(context, task);
                    } else if (value == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Task?'),
                          content: Text(
                            'Delete "${task.title}"? This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await tasksProvider.deleteTask(widget.roomId, task.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Task deleted'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Edit Task'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Task',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: task.isActive,
                  onChanged: (value) {
                    tasksProvider.toggleTaskActive(widget.roomId, task);
                  },
                  activeThumbColor: widget.category.color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  Icons.repeat_rounded,
                  task.frequency.displayName,
                  widget.category.color,
                ),
                _buildChip(
                  Icons.sync_rounded,
                  task.rotationType.displayName,
                  widget.category.color,
                ),
                if (task.timeSlot != null)
                  _buildChip(
                    Icons.access_time_rounded,
                    task.timeSlot!.format(context),
                    widget.category.color,
                  ),
                _buildChip(
                  Icons.timer_outlined,
                  '${task.estimatedMinutes} min',
                  widget.category.color,
                ),
                if (assignee != null)
                  _buildChip(
                    Icons.person_outline_rounded,
                    'Current: ${_getMemberDisplayName(assignee)}',
                    widget.category.color,
                  ),
                if (task.rotationType == RotationType.volunteer)
                  _buildChip(
                    Icons.pan_tool_outlined,
                    'Volunteer Based',
                    Colors.blue,
                  ),

                // Live status for today's instance
                StreamBuilder<Map<String, dynamic>?>(
                  stream: service.watchTaskInstanceForDate(
                    widget.roomId,
                    task.id,
                    today,
                  ),
                  builder: (context, snap) {
                    final instance = snap.data;
                    if (instance == null) {
                      // Not generated yet
                      return _buildChip(
                        Icons.hourglass_empty_rounded,
                        'No instance today',
                        Colors.grey,
                      );
                    }
                    final completed =
                        (instance['isCompleted'] as bool?) ?? false;
                    final assignedTo = instance['assignedTo'];

                    if (assignedTo == 'volunteer' && !completed) {
                      return InkWell(
                        onTap: () => _showAssignmentOptions(
                          context,
                          widget.roomId,
                          instance['taskInstanceId'],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: _buildChip(
                          Icons.pan_tool_rounded,
                          'Unclaimed: Tap to Assign',
                          Colors.blue,
                        ),
                      );
                    }

                    return _buildChip(
                      completed
                          ? Icons.check_circle_rounded
                          : Icons.pending_outlined,
                      completed ? 'Today: Completed' : 'Today: Pending',
                      completed ? Colors.green : Colors.orange,
                    );
                  },
                ),

                // Overdue counter (last 30 days)
                FutureBuilder<int>(
                  future: service.countOverdueTaskInstances(
                    widget.roomId,
                    task.id,
                    lookbackDays: 30,
                  ),
                  builder: (context, snap) {
                    if (!snap.hasData || (snap.data ?? 0) == 0) {
                      return const SizedBox.shrink();
                    }
                    final overdue = snap.data!;
                    return _buildChip(
                      Icons.warning_amber_rounded,
                      'Overdue: $overdue day${overdue == 1 ? '' : 's'}',
                      Colors.red,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateTask(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CreateTaskSheet(roomId: widget.roomId, category: widget.category),
    );
  }

  void _showAssignmentOptions(
    BuildContext context,
    String roomId,
    String taskInstanceId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Assign Task',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.back_hand_rounded, color: Colors.blue),
              title: const Text('Volunteer (Assign to Me)'),
              onTap: () async {
                Navigator.pop(context);
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  await _assignTaskInstance(
                    roomId,
                    taskInstanceId,
                    currentUser.uid,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_rounded, color: Colors.orange),
              title: const Text('Assign to Roommate'),
              onTap: () {
                Navigator.pop(context);
                _showMemberSelectionDialog(context, roomId, taskInstanceId);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMemberSelectionDialog(
    BuildContext context,
    String roomId,
    String taskInstanceId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Member'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _memberProfiles.length,
            itemBuilder: (context, index) {
              final uid = _memberProfiles.keys.elementAt(index);
              final name = _getMemberDisplayName(uid);
              return ListTile(
                leading: CircleAvatar(child: Text(name[0].toUpperCase())),
                title: Text(name),
                onTap: () async {
                  Navigator.pop(context);
                  await _assignTaskInstance(roomId, taskInstanceId, uid);
                },
              );
            },
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
  }

  Future<void> _assignTaskInstance(
    String roomId,
    String taskInstanceId,
    String userId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('taskInstances')
          .doc(taskInstanceId)
          .update({'assignedTo': userId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task assigned to ${_getMemberDisplayName(userId)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'This will delete "$_categoryName" and all its tasks. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              try {
                await context.read<TasksProvider>().deleteCategory(
                  widget.roomId,
                  widget.category.id,
                );
                if (context.mounted) {
                  Navigator.pop(context); // go back to tasks home
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

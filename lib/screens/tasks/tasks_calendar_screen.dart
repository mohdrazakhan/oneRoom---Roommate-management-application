import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';

class TasksCalendarScreen extends StatefulWidget {
  final String roomId;

  const TasksCalendarScreen({super.key, required this.roomId});

  @override
  State<TasksCalendarScreen> createState() => _TasksCalendarScreenState();
}

class _TasksCalendarScreenState extends State<TasksCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();
  String? _filterUid; // null = all
  Map<String, String> _memberNames = {};
  bool _isLoadingMembers = true;

  late Stream<List<Map<String, dynamic>>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _updateStream();
    _loadMemberProfiles();
  }

  void _updateStream() {
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month + 1,
      0,
      23,
      59,
      59,
    );
    _tasksStream = _firestoreService.getTaskInstancesStream(
      widget.roomId,
      startOfMonth.subtract(const Duration(days: 7)),
      endOfMonth.add(const Duration(days: 7)),
    );
  }

  Future<void> _loadMemberProfiles() async {
    try {
      final members = await _firestoreService.getRoomMembers(widget.roomId);
      if (mounted) {
        setState(() {
          _memberNames = {
            for (var m in members)
              m['uid'] as String: m['displayName'] as String,
          };
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading member profiles: $e');
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Calendar'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Calendar',
            onPressed: () {
              setState(() {
                _updateStream();
              });
              _loadMemberProfiles();
            },
          ),
          _buildMemberFilter(),
        ],
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          _buildDaysOfWeekHeader(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _tasksStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final tasks = snapshot.data ?? [];

                // Group tasks by date string YYYY-MM-DD
                final tasksByDate = <String, List<Map<String, dynamic>>>{};
                for (var task in tasks) {
                  // Filter by user if selected
                  if (_filterUid != null && task['assignedTo'] != _filterUid) {
                    continue;
                  }

                  final ts = task['scheduledDate'] as Timestamp?;
                  if (ts == null) continue;
                  final dateKey = DateFormat('yyyy-MM-dd').format(ts.toDate());
                  tasksByDate.putIfAbsent(dateKey, () => []).add(task);
                }

                return _buildCalendarGrid(tasksByDate);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberFilter() {
    return PopupMenuButton<String?>(
      icon: const Icon(Icons.filter_list_rounded),
      tooltip: 'Filter by member',
      onSelected: (val) => setState(() => _filterUid = val),
      itemBuilder: (context) {
        final list = <PopupMenuEntry<String?>>[
          const PopupMenuItem(value: null, child: Text('All Members')),
        ];

        if (!_isLoadingMembers) {
          for (var entry in _memberNames.entries) {
            list.add(PopupMenuItem(value: entry.key, child: Text(entry.value)));
          }
        }

        return list;
      },
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                _updateStream();
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_focusedDay),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                _updateStream();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeekHeader() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days
            .map(
              (d) => SizedBox(
                width: 40,
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(
    Map<String, List<Map<String, dynamic>>> tasksByDate,
  ) {
    // Generate days for the grid
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedDay.year,
      _focusedDay.month,
    );
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1=Mon, 7=Sun

    // Calculate leading empty cells (if Mon is 1, and first day is Wed(3), we need 2 empty cells)
    final leadingEmpty = firstWeekday - 1;

    final totalCells = leadingEmpty + daysInMonth;
    // Round up to multiple of 7 for full rows
    // final rows = (totalCells / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.8, // Taller cells for task dots
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < leadingEmpty) {
          return const SizedBox.shrink();
        }
        final day = index - leadingEmpty + 1;
        final date = DateTime(_focusedDay.year, _focusedDay.month, day);
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final dayTasks = tasksByDate[dateKey] ?? [];

        final isToday = DateUtils.isSameDay(date, DateTime.now());

        return GestureDetector(
          onTap: () => _showDayDetails(date, dayTasks),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isToday ? Colors.blue[50] : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? Border.all(color: Colors.blue.withValues(alpha: 0.3))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.blue : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (dayTasks.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    runSpacing: 2,
                    children: dayTasks.take(4).map((t) {
                      final isCompleted = t['isCompleted'] == true;
                      return Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                if (dayTasks.length > 4)
                  Text(
                    '+${dayTasks.length - 4}',
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDayDetails(DateTime date, List<Map<String, dynamic>> tasks) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(date),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (tasks.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No tasks for this day'),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isCompleted = task['isCompleted'] == true;
                      final assigneeId = task['assignedTo'] as String?;
                      String assigneeName = 'Unknown';

                      if (assigneeId == 'volunteer') {
                        assigneeName = 'Volunteer Needed';
                      } else if (assigneeId != null) {
                        assigneeName =
                            _memberNames[assigneeId] ?? 'Unknown Member';
                      }

                      return ListTile(
                        leading: Icon(
                          isCompleted
                              ? Icons.check_circle
                              : (assigneeId == 'volunteer'
                                    ? Icons.pan_tool_outlined
                                    : Icons.circle_outlined),
                          color: isCompleted
                              ? Colors.green
                              : (assigneeId == 'volunteer'
                                    ? Colors.blue
                                    : Colors.orange),
                        ),
                        title: Text(
                          task['title'] ?? 'Task',
                          style: TextStyle(
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text('Assigned to: $assigneeName'),
                        trailing: (assigneeId == 'volunteer' && !isCompleted)
                            ? ElevatedButton(
                                onPressed: () {
                                  _claimTask(
                                    widget.roomId,
                                    task['taskInstanceId'],
                                  );
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Volunteer'),
                              )
                            : (isCompleted
                                  ? null
                                  : const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                    )),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _claimTask(String roomId, String taskInstanceId) async {
    final user = context.read<AuthProvider>().firebaseUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('taskInstances')
          .doc(taskInstanceId)
          .update({'assignedTo': user.uid});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task claimed successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error claiming task: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error claiming task: $e')));
      }
    }
  }
}

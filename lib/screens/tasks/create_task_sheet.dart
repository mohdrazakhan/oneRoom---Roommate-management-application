// ignore_for_file: avoid_print
// lib/screens/tasks/create_task_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Models/task_category.dart';
import '../../Models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/rooms_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/subscription_service.dart';
import '../../providers/auth_provider.dart';

class CreateTaskSheet extends StatefulWidget {
  final String roomId;
  final TaskCategory category;
  final Task? existingTask; // null => create, non-null => edit

  const CreateTaskSheet({
    super.key,
    required this.roomId,
    required this.category,
    this.existingTask,
  });

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  TaskFrequency _frequency = TaskFrequency.daily;
  RotationType _rotationType = RotationType.roundRobin;
  TimeOfDay? _timeSlot;
  int _estimatedMinutes = 30;
  List<String> _selectedMembers = [];
  List<int> _selectedWeekDays = []; // 1=Mon...7=Sun
  int? _selectedMonthDay;
  Map<String, Map<String, dynamic>> _memberProfiles = {}; // uid -> profile
  bool _isSaving = false;

  bool get _isEditing => widget.existingTask != null;

  int? _repeatInterval = 1;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    if (t != null) {
      _titleController.text = t.title;
      _descController.text = t.description ?? '';
      _frequency = t.frequency;
      _rotationType = t.rotationType;
      _timeSlot = t.timeSlot;
      _estimatedMinutes = t.estimatedMinutes;
      _selectedMembers = List<String>.from(t.memberIds);
      _selectedWeekDays = List<int>.from(t.weekDays ?? []);
      _selectedMonthDay = t.monthDay;
      _repeatInterval = t.repeatInterval ?? 1;
    } else {
      // Default to current user
      final currentUser = context.read<AuthProvider>().firebaseUser;
      if (currentUser != null) {
        _selectedMembers.add(currentUser.uid);
      }
    }
    // Load profiles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMemberProfiles();
    });
  }

  Future<void> _loadMemberProfiles() async {
    final roomsProvider = context.read<RoomsProvider>();
    final room = roomsProvider.getRoomById(widget.roomId);
    if (room == null) return;

    try {
      final profiles = await FirestoreService().getUsersProfiles(room.members);
      print(
        '🔍 Loaded ${profiles.length} profiles for ${room.members.length} members',
      );
      profiles.forEach((uid, profile) {
        print('👤 Profile $uid: ${profile.toString()}');
      });
      if (mounted) {
        setState(() {
          _memberProfiles = profiles;
        });
      }
    } catch (e) {
      print('❌ Error loading profiles: $e');
      if (mounted) {
        // Handle error
      }
    }
  }

  String _getMemberDisplayName(String uid) {
    final profile = _memberProfiles[uid];
    if (profile == null) {
      print('⚠️ No profile found for $uid');
      return 'Member ${uid.substring(0, 4)}';
    }

    print('👤 Full profile data for $uid: $profile');

    // Try different field names that might exist
    final displayName = profile['displayName'];
    final name = profile['name'];
    final email = profile['email'];

    print('  - displayName: $displayName');
    print('  - name: $name');
    print('  - email: $email');

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

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomsProvider = context.watch<RoomsProvider>();
    final room = roomsProvider.getRoomById(widget.roomId);
    final primaryColor = widget.category.color;

    if (room == null) {
      return Container(
        height: 300,
        color: Colors.white,
        child: const Center(child: Text('Room not found')),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            widget.category.icon,
                            color: primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEditing ? 'Edit Task' : 'Create Task',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'in ${widget.category.name}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Inputs
                    _buildTextField(
                      controller: _titleController,
                      label: 'Task Title',
                      hint: 'e.g., Clean the kitchen',
                      icon: Icons.edit_rounded,
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descController,
                      label: 'Description',
                      hint: 'Add any details...',
                      icon: Icons.description_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 32),

                    // Frequency Section
                    _buildSectionLabel('Frequency'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: TaskFrequency.values.map((freq) {
                        return _buildSelectionChip(
                          label: freq.displayName,
                          isSelected: _frequency == freq,
                          color: primaryColor,
                          onTap: () => setState(() => _frequency = freq),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Conditional Frequency Options (Weekly/Monthly)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.fastOutSlowIn,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_frequency == TaskFrequency.weekly ||
                              _frequency == TaskFrequency.biweekly) ...[
                            Text(
                              _frequency == TaskFrequency.biweekly
                                  ? 'Repeats every 2 weeks on'
                                  : 'Repeats On',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final dayIndex = entry.key + 1;
                                    final isSelected = _selectedWeekDays
                                        .contains(dayIndex);
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedWeekDays.remove(dayIndex);
                                          } else {
                                            _selectedWeekDays.add(dayIndex);
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(30),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 42,
                                        height: 42,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? primaryColor
                                              : Colors.grey[100],
                                          shape: BoxShape.circle,
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: primaryColor
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Text(
                                          entry.value,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey[500],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (_frequency == TaskFrequency.monthly) ...[
                            Text(
                              'Repeats on the ${_selectedMonthDay ?? 1}${_getDaySuffix(_selectedMonthDay ?? 1)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: primaryColor,
                                inactiveTrackColor: primaryColor.withValues(
                                  alpha: 0.2,
                                ),
                                thumbColor: primaryColor,
                                overlayColor: primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                              ),
                              child: Slider(
                                value: (_selectedMonthDay ?? 1).toDouble(),
                                min: 1,
                                max: 31,
                                divisions: 30,
                                onChanged: (val) {
                                  setState(
                                    () => _selectedMonthDay = val.toInt(),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (_frequency == TaskFrequency.custom) ...[
                            Text(
                              'Repeats every',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue:
                                        _repeatInterval?.toString() ?? '1',
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      suffixText: 'Days',
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _repeatInterval =
                                            int.tryParse(val) ?? 1;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),

                    // Rotation Section
                    _buildSectionLabel('Assignment Type'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: RotationType.values.map((type) {
                        return _buildSelectionChip(
                          label: type.displayName,
                          isSelected: _rotationType == type,
                          color: primaryColor,
                          onTap: () => setState(() => _rotationType = type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Member Selection & Ordering
                    _buildSectionLabel('Participants & Order'),
                    const SizedBox(height: 12),

                    // 1. Select Participants (Checkboxes)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          'Select Participants (${_selectedMembers.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        children: room.members.map((memberId) {
                          final isSelected = _selectedMembers.contains(
                            memberId,
                          );
                          final displayName = _getMemberDisplayName(memberId);
                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: primaryColor,
                            title: Text(displayName),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  if (!_selectedMembers.contains(memberId)) {
                                    _selectedMembers.add(memberId);
                                  }
                                } else {
                                  _selectedMembers.remove(memberId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Ordering (Reorderable List) - Only for Round Robin
                    if (_selectedMembers.isNotEmpty &&
                        _rotationType == RotationType.roundRobin) ...[
                      Text(
                        'Rotation Order (Drag to reorder)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey[50],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: true,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _selectedMembers.removeAt(oldIndex);
                              _selectedMembers.insert(newIndex, item);
                            });
                          },
                          children: _selectedMembers.map((memberId) {
                            final displayName = _getMemberDisplayName(memberId);
                            return ListTile(
                              key: ValueKey(memberId),
                              tileColor: Colors.white,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.drag_handle,
                                color: Colors.grey,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Time & Duration
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: Column(
                        children: [
                          // Time Slot
                          InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _timeSlot ?? TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() => _timeSlot = time);
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Time Preference',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Text(
                                    _timeSlot?.format(context) ?? 'Any time',
                                    style: TextStyle(
                                      color: _timeSlot != null
                                          ? Colors.black87
                                          : Colors.grey[500],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 32),
                          // Duration
                          Row(
                            children: [
                              Icon(Icons.timer_outlined, color: primaryColor),
                              const SizedBox(width: 12),
                              const Text(
                                'Duration',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$_estimatedMinutes mins',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: primaryColor,
                              inactiveTrackColor: Colors.grey[200],
                              thumbColor: primaryColor,
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                            ),
                            child: Slider(
                              value: _estimatedMinutes.toDouble(),
                              min: 5,
                              max: 180,
                              divisions: 35,
                              onChanged: (val) => setState(
                                () => _estimatedMinutes = val.toInt(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100), // Spacing for fab/button
                  ],
                ),
              ),
            ),
          ),

          // Bottom Button Area
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              // Ensure bottom safe area
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isEditing ? 'Save Changes' : 'Create Task',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          validator: validator,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.category.color, width: 1.5),
            ),
            prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildSelectionChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Future<void> _saveTask() async {
    // Prevent re-entrancy / duplicate submissions
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // For round-robin, we need at least one member selected
    if (_rotationType == RotationType.roundRobin && _selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member for rotation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (mounted) setState(() => _isSaving = true);
      final provider = context.read<TasksProvider>();

      // Check Task Limit if creating new task
      if (!_isEditing) {
        final subService = context.read<SubscriptionService>();
        if (!subService.isPremium) {
          final count = await provider.getTotalTaskCount(widget.roomId);
          if (count >= 5) {
            if (!mounted) return;
            // Reset saving state
            if (mounted) setState(() => _isSaving = false);

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Limit Reached'),
                content: const Text(
                  'Free version allows only 5 tasks per room.\n\nUpgrade to Premium for unlimited tasks!',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/subscription');
                    },
                    child: const Text('Go Premium'),
                  ),
                ],
              ),
            );
            return;
          }
        }
      }

      if (_isEditing) {
        final t = widget.existingTask!;
        final updated = t.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          frequency: _frequency,
          rotationType: _rotationType,
          memberIds: _selectedMembers,
          timeSlot: _timeSlot,
          weekDays: _frequency == TaskFrequency.weekly ? _selectedWeekDays : [],
          monthDay: _frequency == TaskFrequency.monthly
              ? _selectedMonthDay
              : null,
          estimatedMinutes: _estimatedMinutes,
        );
        await provider.updateTask(widget.roomId, updated);
      } else {
        print('Creating task...');
        await provider.createTask(
          roomId: widget.roomId,
          categoryId: widget.category.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          frequency: _frequency,
          rotationType: _rotationType,
          memberIds: _selectedMembers,
          timeSlot: _timeSlot,
          estimatedMinutes: _estimatedMinutes,
          weekDays: _frequency == TaskFrequency.weekly ? _selectedWeekDays : [],
          monthDay: _frequency == TaskFrequency.monthly
              ? _selectedMonthDay
              : null,
        );
        print('Task created successfully!');
      }

      print('About to pop navigator...');
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
        print('Navigator popped!');

        // Show success message after a small delay to ensure context is valid
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isEditing ? 'Task updated!' : 'Task created successfully!',
                ),
                backgroundColor: widget.category.color,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    } catch (e) {
      print('ERROR creating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

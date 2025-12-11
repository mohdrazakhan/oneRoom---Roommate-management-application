// ignore_for_file: avoid_print
// lib/screens/tasks/create_task_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Models/task_category.dart';
import '../../Models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/rooms_provider.dart';
import '../../services/firestore_service.dart';

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
  Map<String, Map<String, dynamic>> _memberProfiles = {}; // uid -> profile
  bool _loadingProfiles = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existingTask != null;

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
    }
    _loadMemberProfiles();
  }

  Future<void> _loadMemberProfiles() async {
    final roomsProvider = context.read<RoomsProvider>();
    final room = roomsProvider.getRoomById(widget.roomId);
    if (room == null) return;

    setState(() => _loadingProfiles = true);

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
          _loadingProfiles = false;
        });
      }
    } catch (e) {
      print('❌ Error loading profiles: $e');
      if (mounted) {
        setState(() => _loadingProfiles = false);
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

    if (room == null) {
      return Container(
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
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.category.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.category.icon,
                        color: widget.category.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Task' : 'Create Task',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'in ${widget.category.name}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Task Title
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Task Title *',
                    hintText: 'e.g., Make breakfast',
                    prefixIcon: const Icon(Icons.title_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Add details about this task',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 20),

                // Frequency
                const Text(
                  'Frequency',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TaskFrequency.values.map((freq) {
                    final isSelected = _frequency == freq;
                    return ChoiceChip(
                      label: Text(freq.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _frequency = freq);
                      },
                      selectedColor: widget.category.color.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? widget.category.color
                            : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Rotation Type
                const Text(
                  'Rotation Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: RotationType.values.map((type) {
                    final isSelected = _rotationType == type;
                    return ChoiceChip(
                      label: Text(type.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _rotationType = type);
                      },
                      selectedColor: widget.category.color.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? widget.category.color
                            : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Time Slot
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.access_time_rounded,
                    color: widget.category.color,
                  ),
                  title: const Text(
                    'Time Slot (optional)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _timeSlot == null
                        ? 'No time set'
                        : _timeSlot!.format(context),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _timeSlot ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() => _timeSlot = time);
                      }
                    },
                    child: Text(_timeSlot == null ? 'Set' : 'Change'),
                  ),
                ),
                const Divider(),

                // Estimated Duration
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.timer_outlined,
                    color: widget.category.color,
                  ),
                  title: const Text(
                    'Estimated Duration',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('$_estimatedMinutes minutes'),
                ),
                Slider(
                  value: _estimatedMinutes.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  label: '$_estimatedMinutes min',
                  activeColor: widget.category.color,
                  onChanged: (value) {
                    setState(() => _estimatedMinutes = value.toInt());
                  },
                ),
                const SizedBox(height: 12),

                // Select Members (for round-robin)
                if (_rotationType == RotationType.roundRobin) ...[
                  const Text(
                    'Select Members for Rotation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingProfiles)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    ...room.members.map((memberId) {
                      final isSelected = _selectedMembers.contains(memberId);
                      final displayName = _getMemberDisplayName(memberId);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedMembers.add(memberId);
                            } else {
                              _selectedMembers.remove(memberId);
                            }
                          });
                        },
                        title: Text(
                          displayName,
                          style: const TextStyle(fontSize: 14),
                        ),
                        activeColor: widget.category.color,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.category.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isEditing ? 'Saving…' : 'Creating…',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _isEditing ? 'Save Changes' : 'Create Task',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
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

      if (_isEditing) {
        final t = widget.existingTask!;
        final updated = t.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          frequency: _frequency,
          rotationType: _rotationType,
          memberIds: _rotationType == RotationType.roundRobin
              ? _selectedMembers
              : [],
          timeSlot: _timeSlot,
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
          memberIds: _rotationType == RotationType.roundRobin
              ? _selectedMembers
              : [],
          timeSlot: _timeSlot,
          estimatedMinutes: _estimatedMinutes,
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

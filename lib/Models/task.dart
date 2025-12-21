// lib/Models/task.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum TaskFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  custom;

  String get displayName {
    switch (this) {
      case TaskFrequency.daily:
        return 'Daily';
      case TaskFrequency.weekly:
        return 'Weekly';
      case TaskFrequency.biweekly:
        return 'Bi-weekly';
      case TaskFrequency.monthly:
        return 'Monthly';
      case TaskFrequency.custom:
        return 'Custom';
    }
  }
}

enum RotationType {
  roundRobin,
  manual,
  volunteer;

  String get displayName {
    switch (this) {
      case RotationType.roundRobin:
        return 'Auto-rotate';
      case RotationType.manual:
        return 'Manual assign';
      case RotationType.volunteer:
        return 'Volunteer-based';
    }
  }
}

class Task {
  final String id;
  final String title;
  final String? description;
  final String categoryId;
  final String roomId;
  final TaskFrequency frequency;
  final RotationType rotationType;
  final List<String> memberIds; // All members who can be assigned
  final TimeOfDay? timeSlot;
  final int estimatedMinutes;
  final bool isActive;
  final DateTime createdAt;
  final int currentRotationIndex; // For round-robin
  final List<int>? weekDays; // For weekly: 1=Mon, 7=Sun
  final int? monthDay; // For monthly: 1-31
  final int? repeatInterval; // For custom: every X days

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.categoryId,
    required this.roomId,
    required this.frequency,
    required this.rotationType,
    required this.memberIds,
    this.timeSlot,
    this.estimatedMinutes = 30,
    this.isActive = true,
    required this.createdAt,
    this.currentRotationIndex = 0,
    this.weekDays,
    this.monthDay,
    this.repeatInterval,
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    TimeOfDay? timeSlot;
    if (data['timeSlotHour'] != null && data['timeSlotMinute'] != null) {
      timeSlot = TimeOfDay(
        hour: data['timeSlotHour'] as int,
        minute: data['timeSlotMinute'] as int,
      );
    }

    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      categoryId: data['categoryId'] ?? '',
      roomId: data['roomId'] ?? '',
      frequency: TaskFrequency.values.firstWhere(
        (e) => e.name == data['frequency'],
        orElse: () => TaskFrequency.daily,
      ),
      rotationType: RotationType.values.firstWhere(
        (e) => e.name == data['rotationType'],
        orElse: () => RotationType.manual,
      ),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      timeSlot: timeSlot,
      estimatedMinutes: data['estimatedMinutes'] ?? 30,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentRotationIndex: data['currentRotationIndex'] ?? 0,
      weekDays: data['weekDays'] != null
          ? List<int>.from(data['weekDays'])
          : null,
      monthDay: data['monthDay'],
      repeatInterval: data['repeatInterval'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'roomId': roomId,
      'frequency': frequency.name,
      'rotationType': rotationType.name,
      'memberIds': memberIds,
      'timeSlotHour': timeSlot?.hour,
      'timeSlotMinute': timeSlot?.minute,
      'estimatedMinutes': estimatedMinutes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentRotationIndex': currentRotationIndex,
      'weekDays': weekDays,
      'monthDay': monthDay,
      'repeatInterval': repeatInterval,
    };
  }

  Task copyWith({
    String? title,
    String? description,
    TaskFrequency? frequency,
    RotationType? rotationType,
    List<String>? memberIds,
    TimeOfDay? timeSlot,
    int? estimatedMinutes,
    bool? isActive,
    int? currentRotationIndex,
    List<int>? weekDays,
    int? monthDay,
    int? repeatInterval,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId,
      roomId: roomId,
      frequency: frequency ?? this.frequency,
      rotationType: rotationType ?? this.rotationType,
      memberIds: memberIds ?? this.memberIds,
      timeSlot: timeSlot ?? this.timeSlot,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      currentRotationIndex: currentRotationIndex ?? this.currentRotationIndex,
      weekDays: weekDays ?? this.weekDays,
      monthDay: monthDay ?? this.monthDay,
      repeatInterval: repeatInterval ?? this.repeatInterval,
    );
  }
}

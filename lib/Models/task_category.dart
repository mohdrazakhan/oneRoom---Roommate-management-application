// lib/Models/task_category.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskCategory {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final String roomId;
  final DateTime createdAt;

  TaskCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.roomId,
    required this.createdAt,
  });

  // Tree-shaking friendly icon resolution:
  // Avoid constructing IconData with a variable codePoint (non-constant) which breaks
  // flutter's icon font tree shaking in release. Instead keep a static map of the
  // IconData constants we allow and look them up by codePoint. All entries are const
  // so the tree shaker can see and retain only the used glyphs.
  static final Map<int, IconData> _iconDataByCodePoint = {
    Icons.task_alt_rounded.codePoint: Icons.task_alt_rounded,
    Icons.check_circle_outline.codePoint: Icons.check_circle_outline,
    Icons.edit.codePoint: Icons.edit,
    Icons.delete.codePoint: Icons.delete,
    Icons.chat.codePoint: Icons.chat,
    Icons.swap_horiz.codePoint: Icons.swap_horiz,
    Icons.calendar_month.codePoint: Icons.calendar_month,
    Icons.attach_money.codePoint: Icons.attach_money,
    Icons.work.codePoint: Icons.work,
    Icons.home.codePoint: Icons.home,
    Icons.shopping_cart.codePoint: Icons.shopping_cart,
    Icons.done_all.codePoint: Icons.done_all,
    Icons.notifications.codePoint: Icons.notifications,
  };

  IconData get icon =>
      _iconDataByCodePoint[iconCodePoint] ?? Icons.task_alt_rounded;
  Color get color => Color(colorValue);

  factory TaskCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskCategory(
      id: doc.id,
      name: data['name'] ?? '',
      iconCodePoint: data['iconCodePoint'] ?? Icons.task_alt_rounded.codePoint,
      colorValue: data['colorValue'] ?? Colors.blue.toARGB32(),
      roomId: data['roomId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'roomId': roomId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

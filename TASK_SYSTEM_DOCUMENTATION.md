# Task System Documentation

## Overview
The task system allows roommates to create, assign, and manage recurring tasks within rooms. Tasks are organized into categories and generate scheduled instances for assigned members.

## Architecture

### 1. Data Structure

#### Task Template (`/rooms/{roomId}/tasks/{taskId}`)
- **Purpose**: Defines the task blueprint
- **Fields**:
  - `title`: Task name
  - `categoryId`: Reference to task category
  - `assignedTo`: User ID of assigned member
  - `recurrence`: Frequency (`daily`, `weekly`, `monthly`, `custom`)
  - `startDate`: When task scheduling begins
  - `endDate`: Optional end date for recurring tasks
  - `createdBy`: Creator's user ID
  - `createdAt`: Timestamp

#### Task Instance (`/rooms/{roomId}/taskInstances/{instanceId}`)
- **Purpose**: Represents a specific occurrence of a task
- **Fields**:
  - `taskId`: Reference to parent task template
  - `assignedTo`: User ID (can be swapped)
  - `scheduledDate`: When this instance is due
  - `isCompleted`: Completion status
  - `completedAt`: Timestamp when marked complete
  - `swapRequest`: Pending swap request data
  - `swappedWith`: Swap history

#### Task Category (`/rooms/{roomId}/task_categories/{categoryId}`)
- **Purpose**: Groups related tasks
- **Fields**:
  - `name`: Category name (e.g., "Cleaning", "Cooking")
  - `icon`: Icon identifier
  - `color`: Color code
  - `createdBy`: Creator's user ID

### 2. Key Components

#### Services
- **`FirestoreService`** (`lib/services/firestore_service.dart`)
  - `getTodayTasksForUser()`: Stream of today's tasks for a user
  - `getUpcomingTasksForUser()`: Stream of upcoming tasks (next 30 days)
  - `generateTaskInstancesForRoom()`: Creates task instances based on templates
  - `deleteTaskInstancesForTask()`: Cleans up instances when task is deleted
  - `_cleanupOrphanedInstances()`: Background cleanup of orphaned instances

#### Providers
- **`TasksProvider`** (`lib/providers/tasks_provider.dart`)
  - `createTask()`: Creates new task template
  - `updateTask()`: Updates existing task
  - `deleteTask()`: Deletes task and all its instances
  - Manages task state and notifications

#### Screens
- **`MyTasksDashboard`** (`lib/screens/tasks/my_tasks_dashboard.dart`)
  - Displays user's personal task list
  - Two tabs: "Today" and "Upcoming"
  - Supports task completion, swapping, and rescheduling

- **`CategoryTasksScreen`** (`lib/screens/tasks/category_tasks_screen.dart`)
  - Shows all tasks in a category
  - Task management interface for room admins

- **`TaskManagerScreen`** (`lib/screens/tasks/task_manager_screen.dart`)
  - Category management
  - Task creation and organization

## Task Lifecycle

### 1. Creation Flow
```
User creates task → Task template saved → Instances generated → Assigned users notified
```

### 2. Instance Generation
- Triggered by `generateTaskInstancesForRoom()`
- Creates instances based on recurrence pattern
- Assigns to specified user or rotates among members
- Generates up to 30 days in advance

### 3. Completion Flow
```
User marks complete → Instance updated → Completion timestamp recorded → Stats updated
```

### 4. Deletion Flow
```
User deletes task → Task template deleted → All instances deleted → Members notified
```

## Recent Fixes (Dec 13, 2024)

### Problem: Orphaned Task Instances
**Issue**: Deleted tasks left behind orphaned instances that still appeared in "My Tasks"

**Root Cause**: Task deletion removed the template but instances weren't always cleaned up properly due to:
- Race conditions
- Query timing issues
- Missing validation in display queries

**Solution Implemented**:
1. **Optimized Validation**: Batch-fetch all valid task IDs per room instead of checking one-by-one
2. **Auto-Cleanup**: Mark orphaned instances for background deletion
3. **Performance**: Reduced query time from O(n²) to O(n) where n = number of instances

**Code Changes**:
- Modified `getTodayTasksForUser()` to pre-fetch valid tasks
- Modified `getUpcomingTasksForUser()` with same optimization
- Added `_cleanupOrphanedInstances()` helper for background cleanup

### Before vs After

**Before**:
```dart
// For each instance, query if parent task exists (slow)
for (instance in instances) {
  final taskExists = await checkTask(instance.taskId);
  if (!taskExists) await instance.delete();
}
```

**After**:
```dart
// Fetch all valid tasks once
final validTaskIds = await getAllTaskIds();

// Filter instances in memory (fast)
for (instance in instances) {
  if (!validTaskIds.contains(instance.taskId)) {
    orphanedInstances.add(instance.id);
  }
}

// Cleanup in background
_cleanupOrphanedInstances(orphanedInstances);
```

## Best Practices

### For Developers
1. **Always delete instances when deleting tasks**
   ```dart
   await deleteTask(taskId);
   await deleteTaskInstancesForTask(roomId, taskId);
   ```

2. **Validate parent task exists before displaying instances**
   - Already implemented in `getTodayTasksForUser()` and `getUpcomingTasksForUser()`

3. **Use batch operations for cleanup**
   - Don't await cleanup operations that aren't critical
   - Let them run in background

### For Users
1. **Task Manager**: Create categories before tasks
2. **My Tasks**: Use "Generate Task Schedule" button if tasks don't appear
3. **Swapping**: Both parties must approve swap requests
4. **Completion**: Mark tasks complete daily for accurate stats

## Troubleshooting

### Tasks not appearing in "My Tasks"
1. Check if task instances were generated
2. Click the sparkle icon (⚡) to generate instances
3. Verify task is assigned to you
4. Check scheduled date is within range

### Deleted tasks still showing
- Fixed as of Dec 13, 2024
- Orphaned instances are now auto-cleaned
- Navigate away and back to trigger cleanup

### Performance issues
- Optimized batch queries implemented
- Background cleanup prevents blocking
- Consider limiting instance generation to 30 days

## Future Improvements

1. **Batch Instance Generation**: Generate instances for multiple tasks at once
2. **Smart Rotation**: AI-based fair task distribution
3. **Reminders**: Push notifications for upcoming tasks
4. **Analytics**: Task completion stats and trends
5. **Templates**: Pre-defined task sets for common scenarios

## Related Files
- `/lib/services/firestore_service.dart` - Core task queries
- `/lib/providers/tasks_provider.dart` - Task state management
- `/lib/screens/tasks/` - Task UI screens
- `/lib/Models/task.dart` - Task data models
- `/firestore.rules` - Security rules for tasks

## Security Rules
Tasks and instances are protected by room membership:
```javascript
match /rooms/{roomId}/tasks/{taskId} {
  allow read, write: if isMemberOfRoom(roomId);
}

match /rooms/{roomId}/taskInstances/{instanceId} {
  allow read, write: if isMemberOfRoom(roomId);
}
```

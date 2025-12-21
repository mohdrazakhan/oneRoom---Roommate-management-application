# Task Swap Feature - Test Scenario

## Feature Description
The task swap feature allows roommates to exchange their scheduled task instances with each other.

## How It Works

### Scenario: Raza wants to swap with Amit

**Initial State:**
- Raza has "Lunch" task on Dec 14
- Amit has "Lunch" task on Dec 15

**Swap Process:**
1. **Raza initiates swap** (Dec 14 task)
   - Raza opens his Dec 14 "Lunch" task
   - Taps "Swap with someone"
   - Selects "Amit" from the list
   - System creates swap request on Raza's Dec 14 task instance

2. **Amit receives notification**
   - Amit gets push notification: "Raza wants to swap tasks with you"
   - Amit sees swap request banner on his task list

3. **Amit approves swap**
   - Amit opens the task with pending swap request
   - Taps "Approve"
   - System performs the swap:

**After Swap:**
- ✅ **Dec 14 "Lunch"** → Now assigned to **Amit** (was Raza's)
- ✅ **Dec 15 "Lunch"** → Now assigned to **Raza** (was Amit's)
- ✅ Both tasks marked with `swappedWith` metadata
- ✅ Swap indicator shown on both users' screens
- ✅ All other tasks remain unchanged

## Implementation Details

### Code Logic (firestore_service.dart)

```dart
// 1. Find requester's (Raza's) NEXT instance of the SAME task
final requesterTasksSnapshot = await _rooms
    .doc(roomId)
    .collection('taskInstances')
    .where('assignedTo', isEqualTo: requesterId)  // Raza
    .where('taskId', isEqualTo: taskId)            // Same "Lunch" task
    .get();

// 2. Filter for tasks AFTER current date (Dec 15, not Dec 14)
final requesterNextTask = requesterTasksSnapshot.docs.where((doc) {
  final docDate = DateTime(...);
  return docDate.compareTo(scheduledDateOnly) > 0;  // Strictly after
}).toList();

// 3. Swap the assignees
// Raza's Dec 14 task → Amit
await taskInstanceRef.update({
  'assignedTo': requesterId,  // Amit gets Raza's task
  'swappedWith': {
    'userId': requesterId,
    'userName': 'Amit',
    'originalDate': amitOriginalDate,  // Dec 15
    'swappedAt': now,
    'swappedBy': 'Amit',
  },
});

// Amit's Dec 15 task → Raza
await _rooms.doc(roomId).collection('taskInstances')
    .doc(requesterTaskInstanceId)
    .update({
      'assignedTo': currentAssignee,  // Raza gets Amit's task
      'swappedWith': {
        'userId': currentAssignee,
        'userName': 'Raza',
        'originalDate': razaOriginalDate,  // Dec 14
        'swappedAt': now,
        'swappedBy': 'Amit',
      },
    });
```

### Key Constraints

1. **Same Task Only**: Can only swap instances of the SAME task (e.g., both "Lunch")
2. **Future Tasks**: Requester must have a future instance to swap
3. **One-to-One**: Each swap affects exactly 2 task instances
4. **Immutable History**: `swappedWith` metadata preserves swap history
5. **No Chain Swaps**: Once swapped, tasks can't be swapped again (current implementation)

## UI Indicators

### Swap Request Banner (Pending)
```
┌─────────────────────────────────────┐
│ 🔄 Raza wants to swap with you      │
│ [Reject]  [Approve]                 │
└─────────────────────────────────────┘
```

### Swapped Task Indicator (After Approval)
```
┌─────────────────────────────────────┐
│ Lunch                               │
│ 🏠 December Alpha 1                 │
│ 📅 Dec 14, 2025                     │
│ ─────────────────────────────────── │
│ 🔄 Swapped with Amit by Amit        │
└─────────────────────────────────────┘
```

## Test Cases

### ✅ Test Case 1: Basic Swap
- **Given**: Raza (Dec 14), Amit (Dec 15)
- **When**: Raza requests swap, Amit approves
- **Then**: Dec 14 → Amit, Dec 15 → Raza

### ✅ Test Case 2: Rejection
- **Given**: Raza (Dec 14), Amit (Dec 15)
- **When**: Raza requests swap, Amit rejects
- **Then**: No changes, swap request marked rejected

### ✅ Test Case 3: No Future Task
- **Given**: Raza (Dec 14), Amit has no future "Lunch" tasks
- **When**: Raza requests swap with Amit
- **Then**: Error: "No upcoming instance found for requester to swap"

### ✅ Test Case 4: Different Tasks
- **Given**: Raza has "Lunch", Amit has "Dinner"
- **When**: Raza tries to swap
- **Then**: System only shows members with same task type

### ✅ Test Case 5: Multiple Future Tasks
- **Given**: Amit has "Lunch" on Dec 15, Dec 16, Dec 17
- **When**: Raza (Dec 14) swaps with Amit
- **Then**: Swaps with Dec 15 (earliest future task)

## Recent Fix (Dec 13, 2024)

### Bug Found
The comparison was using `>=` instead of `>`, which could match the same date:
```dart
// WRONG - could swap with same instance
return docDate.compareTo(scheduledDateOnly) >= 0;

// CORRECT - finds next instance
return docDate.compareTo(scheduledDateOnly) > 0;
```

### Impact
- **Before**: Could potentially swap with the same task instance
- **After**: Correctly finds the requester's NEXT task instance

## Database Schema

### Task Instance with Swap Request
```json
{
  "taskId": "lunch_task_123",
  "assignedTo": "amit_uid",
  "scheduledDate": "2025-12-14T00:00:00Z",
  "swapRequest": {
    "requesterId": "raza_uid",
    "requesterName": "Raza",
    "targetId": "amit_uid",
    "targetName": "Amit",
    "status": "pending",
    "createdAt": "2025-12-13T10:00:00Z"
  }
}
```

### Task Instance After Swap
```json
{
  "taskId": "lunch_task_123",
  "assignedTo": "amit_uid",  // Changed from raza_uid
  "scheduledDate": "2025-12-14T00:00:00Z",
  "swapRequest": {
    "status": "approved",
    "approvedAt": "2025-12-13T11:00:00Z"
  },
  "swappedWith": {
    "userId": "raza_uid",
    "userName": "Raza",
    "originalDate": "2025-12-15T00:00:00Z",
    "swappedAt": "2025-12-13T11:00:00Z",
    "swappedBy": "Amit"
  }
}
```

## Notifications

1. **Swap Request**: Sent to target user
2. **Swap Approved**: Sent to requester
3. **Swap Rejected**: Sent to requester

## Limitations

1. Can't swap already completed tasks
2. Can't swap tasks from different categories
3. No automatic undo (would need manual re-swap)
4. Swap history is preserved but not reversible

## Future Enhancements

1. Allow swapping different task types
2. Multi-party swaps (3+ people)
3. Temporary swaps with auto-revert
4. Swap history view
5. Bulk swap operations

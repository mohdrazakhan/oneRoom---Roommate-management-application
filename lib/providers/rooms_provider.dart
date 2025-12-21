// lib/providers/rooms_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/room.dart';
import '../services/firestore_service.dart';

class RoomsProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  List<Room> rooms = [];
  bool isLoading = false;
  String? error;

  StreamSubscription<List<Map<String, dynamic>>>? _roomsSub;
  StreamSubscription<Map<String, dynamic>?>? _userProfileSub;
  String? _listeningUid;
  List<String> _currentRoomOrder = [];

  /// Check if we are currently listening to this user's rooms
  bool isListeningTo(String uid) {
    return _listeningUid == uid && _roomsSub != null;
  }

  /// Start listening to rooms for a specific user UID.
  /// Call this after user logs in. If already listening to the same uid, it will restart ONLY if forceRestart is true.
  void startListening(String uid, {bool forceRestart = false}) {
    debugPrint(
      '🏠 RoomsProvider.startListening called for uid: $uid, forceRestart: $forceRestart',
    );

    // If we are already listening to this UID and not forced to restart, do nothing.
    if (_listeningUid == uid && !forceRestart && _roomsSub != null) {
      debugPrint('🏠 Already listening to this uid, skipping startListening');
      return;
    }

    _stopAllListeners();
    _listeningUid = uid;

    // Reset state for new listener
    isLoading = true;
    error = null;
    rooms = [];
    _currentRoomOrder = [];

    notifyListeners();

    debugPrint('🏠 Starting Firestore listener for rooms...');

    // Listen to User Profile to get Order
    _userProfileSub = _fs.streamUserProfile(uid).listen((profileMap) {
      if (profileMap != null) {
        final order = List<String>.from(profileMap['roomOrder'] ?? []);
        _currentRoomOrder = order;
        _sortRooms();
        notifyListeners();
      }
    });

    // Listen to Rooms
    _roomsSub = _fs
        .roomsForUser(uid)
        .listen(
          (listMap) {
            debugPrint('🏠 Received ${listMap.length} rooms from Firestore');
            final loadedRooms = listMap.map((m) {
              final id = (m['id'] ?? '') as String;
              return Room.fromMap(Map<String, dynamic>.from(m), id);
            }).toList();

            rooms = loadedRooms;
            _sortRooms();

            isLoading = false;
            error = null;
            debugPrint('🏠 Rooms loaded: ${rooms.length}, notifying listeners');
            notifyListeners();
          },
          onError: (e) {
            debugPrint('🏠 ❌ Error loading rooms: $e');
            error = e.toString();
            isLoading = false;
            notifyListeners();
          },
        );
  }

  void _sortRooms() {
    if (_currentRoomOrder.isEmpty) return; // Keep default sort (createdAt desc)

    // Sort based on _currentRoomOrder
    // If a room is not in the order list, put it at the end (or beginning?)
    // Let's put new rooms at the TOP if not ordered yet, or bottom?
    // Usually new items go to top. But if I have a custom order, new items might be forgotten.
    // Let's append them.

    final orderMap = {
      for (var i = 0; i < _currentRoomOrder.length; i++)
        _currentRoomOrder[i]: i,
    };

    rooms.sort((a, b) {
      final idxA = orderMap[a.id];
      final idxB = orderMap[b.id];

      if (idxA != null && idxB != null) {
        return idxA.compareTo(idxB);
      }
      if (idxA != null) return -1; // A is in order, B is not -> A comes first
      if (idxB != null) return 1; // B is in order, A is not -> B comes first

      // Both not in order, fallback to createdAt desc
      // (assuming original list was sorted by createdAt desc from Firestore Service)
      // Actually FirestoreService sorts them.
      return 0;
    });
  }

  /// Reorder rooms locally and sync to cloud
  void reorderRooms(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Room item = rooms.removeAt(oldIndex);
    rooms.insert(newIndex, item);
    notifyListeners();

    // Sync to Firestore
    if (_listeningUid != null) {
      final newOrder = rooms.map((r) => r.id).toList();
      _currentRoomOrder = newOrder; // Update local order state immediately
      _fs.updateUserRoomOrder(_listeningUid!, newOrder);
    }
  }

  void _stopAllListeners() {
    _roomsSub?.cancel();
    _userProfileSub?.cancel();
    _roomsSub = null;
    _userProfileSub = null;
  }

  /// Stop listening (e.g., on sign out or provider dispose)
  Future<void> stopListening() async {
    _stopAllListeners();
    _listeningUid = null;
    rooms = [];
    notifyListeners();
    debugPrint('🏠 Stopped listening to rooms');
  }

  /// Refresh rooms data (restarts the listener)
  Future<void> refresh() async {
    debugPrint('🏠 RoomsProvider.refresh() called');
    if (_listeningUid != null) {
      // Just call startListening again with forceRestart=true
      startListening(_listeningUid!, forceRestart: true);
    } else {
      // Fallback: Check if there is a logged-in user we should be listening to
      // This handles cases where refresh() is called before the provider was properly initialized
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint(
          '🏠 Refresh: Found current user ${user.uid}, starting listener',
        );
        startListening(user.uid, forceRestart: true);
      } else {
        debugPrint('🏠 Cannot refresh: No listening UID and no current user');
      }
    }
  }

  /// Create a new room (delegates to FirestoreService)
  Future<void> createRoom({
    required String name,
    required String createdBy,
  }) async {
    try {
      // We don't set isLoading here for the whole list, as it might block the UI unnecessarily?
      // But user expects feedback.
      // Usually createRoom is awaited by the UI to show a dialog loader or similar.
      // If we set isLoading = true here, the dashboard might flicker.
      // Let's just delegate.
      await _fs.createRoom(name: name, createdBy: createdBy);
    } catch (e) {
      error = e.toString();
      rethrow;
    }
  }

  /// Add a member uid to a room
  Future<void> addMember(String roomId, String uid) async {
    try {
      await _fs.addMember(roomId, uid);
    } catch (e) {
      error = e.toString();
      rethrow;
    }
  }

  Room? getRoomById(String id) {
    try {
      return rooms.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    super.dispose();
  }
}

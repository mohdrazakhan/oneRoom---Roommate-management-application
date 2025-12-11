// lib/providers/rooms_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../Models/room.dart';
import '../services/firestore_service.dart';

class RoomsProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  List<Room> rooms = [];
  bool isLoading = false;
  String? error;

  StreamSubscription<List<Map<String, dynamic>>>? _roomsSub;
  String? _listeningUid;

  /// Start listening to rooms for a specific user UID.
  /// Call this after user logs in. If already listening to the same uid, it will restart.
  void startListening(String uid, {bool forceRestart = false}) {
    debugPrint(
      '🏠 RoomsProvider.startListening called for uid: $uid, forceRestart: $forceRestart',
    );
    debugPrint(
      '🏠 Current state: _listeningUid=$_listeningUid, _roomsSub=${_roomsSub != null}',
    );

    if (_listeningUid == uid && !forceRestart && _roomsSub != null) {
      debugPrint('🏠 Already listening to this uid, skipping');
      return; // already listening
    }
    _roomsSub?.cancel();
    _listeningUid = uid;
    isLoading = true;
    notifyListeners();

    debugPrint('🏠 Starting Firestore listener for rooms...');
    _roomsSub = _fs
        .roomsForUser(uid)
        .listen(
          (listMap) {
            debugPrint('🏠 Received ${listMap.length} rooms from Firestore');
            rooms = listMap.map((m) {
              // m is a map with fields and 'id' present (as used in the FirestoreService earlier)
              final id = (m['id'] ?? '') as String;
              debugPrint('🏠 Room: $id - ${m['name']}');
              return Room.fromMap(Map<String, dynamic>.from(m), id);
            }).toList();
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

  /// Stop listening (e.g., on sign out or provider dispose)
  Future<void> stopListening() async {
    await _roomsSub?.cancel();
    _roomsSub = null;
    _listeningUid = null;
    rooms = [];
    notifyListeners();
  }

  /// Refresh rooms data (restarts the listener)
  Future<void> refresh() async {
    if (_listeningUid != null) {
      final uid = _listeningUid!;
      await _roomsSub?.cancel();
      isLoading = true;
      notifyListeners();

      _roomsSub = _fs
          .roomsForUser(uid)
          .listen(
            (listMap) {
              rooms = listMap.map((m) {
                final id = (m['id'] ?? '') as String;
                return Room.fromMap(Map<String, dynamic>.from(m), id);
              }).toList();
              isLoading = false;
              error = null;
              notifyListeners();
            },
            onError: (e) {
              error = e.toString();
              isLoading = false;
              notifyListeners();
            },
          );
    }
  }

  /// Create a new room (delegates to FirestoreService)
  Future<void> createRoom({
    required String name,
    required String createdBy,
  }) async {
    try {
      isLoading = true;
      notifyListeners();
      await _fs.createRoom(name: name, createdBy: createdBy);
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
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

# Unresolved Issues

## 1. Rooms Not Showing After Login
**Status:** Open
**Severity:** High (User Experience)
**Description:**
After logging in, the `DashboardScreen` shows 0 rooms (empty state). The rooms only appear after restarting the application.
- **Observed Behavior:**
    - Authentication is successful.
    - `AuthWrapper` rebuilds.
    - `RoomsProvider` listener seems to start (logs show subscription), but no data is emitted or the UI doesn't update immediately.
    - "Force Refresh" button manually fetches data, but automatic fetch on login fails or delays.
    - Logs show `Phenotype.API` errors and some permission warnings, possibly related to Firestore cache or Auth token propagation delay.
**Attempted Fixes:**
- Modified `AuthWrapper` to ensure `startListening` is called.
- Added `isListeningTo` check in `RoomsProvider` to prevent redundant/missed subscriptions.
- Added `Force Refresh` button for manual recovery.
- Cleaned build cache.
**Next Steps:**
- Investigate Firestore offline persistence/cache settings.
- Check `AuthWrapper` vs `StreamBuilder` timing.
- Revisit after completing other tasks.

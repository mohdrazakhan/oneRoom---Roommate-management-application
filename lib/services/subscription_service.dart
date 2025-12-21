// lib/services/subscription_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

enum SubscriptionStatus { free, standard, plus }

class SubscriptionService extends ChangeNotifier {
  final FirestoreService _fs;
  SubscriptionStatus _status = SubscriptionStatus.free;
  DateTime? _expiryDate;
  bool _isLoading = false;

  SubscriptionService(this._fs);

  SubscriptionStatus get status => _status;
  DateTime? get expiryDate => _expiryDate;

  bool _isPlanDropped = false;

  bool get isPremium => true; // Enabled for ALL users per new request
  bool get isAdFree => _status == SubscriptionStatus.plus;
  bool get isPlanDropped => _isPlanDropped;
  bool get isLoading => _isLoading;

  /// Initialize Subscription Service
  Future<void> init(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _checkFirestoreStatus(uid);
    } catch (e) {
      debugPrint('SubscriptionService Init Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// RESTORE PURCHASES (Now just syncs with Firestore)
  Future<void> restorePurchases(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _checkFirestoreStatus(uid);
      await _fs.updateUserProfile(uid, {'isPremiumPaused': false});
      // Logic removed/unused
      notifyListeners();
    } catch (e) {
      debugPrint("Restore Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// PERMANENTLY Drop Plan (Remove from DB)
  Future<void> dropPlan(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _fs.updateUserProfile(uid, {
        'isPremium': false,
        'subscriptionTier': 'free',
        'subscriptionExpiry': null,
        'isPremiumPaused': false,
        'isPlanDropped': true,
        'activePromoCode': FieldValue.delete(),
      });

      _status = SubscriptionStatus.free;
      _expiryDate = null;
      // _isPremiumPaused = false; // logic removed/unused
      _isPlanDropped = true;
      _activeDiscount = 0.0;
      _activePromoCode = null;
    } catch (e) {
      debugPrint("Drop Plan Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Simulated Purchase (Works completely via Firestore)
  Future<bool> simulateDiscountedPurchase({
    required String uid,
    required String tier,
    required String duration,
    required double originalPrice,
  }) async {
    _isLoading = true;
    notifyListeners();

    final discountAmount = originalPrice * _activeDiscount;
    final finalPrice = originalPrice - discountAmount;

    try {
      await Future.delayed(const Duration(seconds: 2));

      DateTime newExpiry;
      final now = DateTime.now();
      if (duration == 'weekly') {
        newExpiry = now.add(const Duration(days: 7));
      } else if (duration == 'monthly') {
        newExpiry = now.add(const Duration(days: 30));
      } else {
        newExpiry = now.add(const Duration(days: 365));
      }

      await _fs.updateUserProfile(uid, {
        'isPremium': true,
        'subscriptionTier': tier,
        'subscriptionExpiry': Timestamp.fromDate(newExpiry),
        'subscriptionStartDate': FieldValue.serverTimestamp(),
        'activePromoCode': _activePromoCode ?? 'DISCOUNTED',
        'paymentMethod': 'SIMULATED_PURCHASE',
        'amountPaid': finalPrice,
        'isPlanDropped': false,
      });

      _status = tier == 'plus'
          ? SubscriptionStatus.plus
          : SubscriptionStatus.standard;
      _expiryDate = newExpiry;

      _activeDiscount = 0.0;
      _activePromoCode = null;
      _isPlanDropped = false;

      return true;
    } catch (e) {
      debugPrint("Simulated purchase failed: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Local logic for manual deactivation
  Future<void> deactivatePremium(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _fs.updateUserProfile(uid, {'isPremiumPaused': true});
      await _fs.updateUserProfile(uid, {'isPremiumPaused': true});
      // _isPremiumPaused = true; // logic removed/unused
    } catch (e) {
      debugPrint("Deactivate Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Core logic: Check Firestore for subscription status
  Future<void> _checkFirestoreStatus(String uid) async {
    try {
      final profile = await _fs.getUserProfile(uid);
      if (profile != null) {
        final tier = profile['subscriptionTier'] as String? ?? 'free';
        final expiryTimestamp = profile['subscriptionExpiry'] as Timestamp?;
        // final paused = profile['isPremiumPaused'] as bool? ?? false; // unused

        // Logic removed/unused
        _isPlanDropped = profile['isPlanDropped'] as bool? ?? false;

        if (_isPlanDropped) {
          _status = SubscriptionStatus.free;
          return;
        }

        bool isManualPro = tier == 'plus' || tier == 'standard';
        final dbExpiry = expiryTimestamp?.toDate();

        if (isManualPro &&
            dbExpiry != null &&
            DateTime.now().isBefore(dbExpiry)) {
          _status = tier == 'plus'
              ? SubscriptionStatus.plus
              : SubscriptionStatus.standard;
          _expiryDate = dbExpiry;
        } else {
          _status = SubscriptionStatus.free;
          _expiryDate = null;
        }
      }
    } catch (e) {
      debugPrint("Firestore check failed: $e");
    }
  }

  // Placeholder for missing RevenueCat UI methods
  void showCustomerCenter() {
    debugPrint("Customer Center is disabled (RevenueCat removed).");
  }

  // Promo Code Logic
  double _activeDiscount = 0.0;
  String? _activePromoCode;
  double get activeDiscount => _activeDiscount;
  String? get activePromoCode => _activePromoCode;

  String? applyPromoCode(String code) {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode == 'FREEE100') {
      _activeDiscount = 1.0;
      _activePromoCode = normalizedCode;
      notifyListeners();
      return 'Code applied! 100% OFF.';
    } else if (normalizedCode.startsWith('GETT')) {
      _activeDiscount = 0.50; // Generic discount
      _activePromoCode = normalizedCode;
      notifyListeners();
      return 'Code applied! Discount applied.';
    }
    return null;
  }

  void clearPromoCode() {
    _activeDiscount = 0.0;
    _activePromoCode = null;
    notifyListeners();
  }
}

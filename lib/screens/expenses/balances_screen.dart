// lib/screens/expenses/balances_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Models/expense.dart';
import '../../services/firestore_service.dart';

class BalancesScreen extends StatelessWidget {
  final String roomId;

  const BalancesScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Balances')),
      body: StreamBuilder<List<Expense>>(
        stream: firestoreService.getExpensesStream(roomId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final expenses = snapshot.data ?? [];

          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add expenses to see balances',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Calculate balances
          final balances = BalanceCalculator.calculateBalances(expenses);
          final settlements = BalanceCalculator.simplifySettlements(balances);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Individual balances
              Text(
                'Individual Balances',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              ...balances.entries.map((entry) {
                final uid = entry.key;
                final balance = entry.value;
                final isCurrentUser = uid == currentUser.uid;

                return FutureBuilder<String>(
                  future: _getUserName(firestoreService, uid),
                  builder: (context, snapshot) {
                    final userName = snapshot.data ?? 'Loading...';
                    final isOwed = balance > 0.01;
                    final isSettled = balance.abs() <= 0.01;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isCurrentUser ? Colors.blue[50] : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSettled
                              ? Colors.grey[300]
                              : isOwed
                              ? Colors.green[100]
                              : Colors.red[100],
                          child: Icon(
                            isSettled
                                ? Icons.check
                                : isOwed
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isSettled
                                ? Colors.grey[700]
                                : isOwed
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                        title: Text(
                          userName + (isCurrentUser ? ' (You)' : ''),
                          style: TextStyle(
                            fontWeight: isCurrentUser
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          isSettled
                              ? 'Settled up'
                              : isOwed
                              ? 'Gets back'
                              : 'Owes',
                          style: TextStyle(
                            color: isSettled
                                ? Colors.grey[600]
                                : isOwed
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        trailing: Text(
                          isSettled
                              ? '₹0.00'
                              : '₹${balance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSettled
                                ? Colors.grey[700]
                                : isOwed
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),

              const SizedBox(height: 32),

              // Simplified settlements
              if (settlements.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Suggested Settlements',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${settlements.length} payment${settlements.length == 1 ? '' : 's'}',
                      ),
                      backgroundColor: Colors.blue[100],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Minimize transactions with these simplified payments',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                ...settlements.map((settlement) {
                  return FutureBuilder<List<String>>(
                    future: Future.wait([
                      _getUserName(firestoreService, settlement.from),
                      _getUserName(firestoreService, settlement.to),
                    ]),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Card(
                          child: ListTile(title: Text('Loading...')),
                        );
                      }

                      final fromName = snapshot.data![0];
                      final toName = snapshot.data![1];
                      final isCurrentUserPaying =
                          settlement.from == currentUser.uid;
                      final isCurrentUserReceiving =
                          settlement.to == currentUser.uid;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: (isCurrentUserPaying || isCurrentUserReceiving)
                            ? Colors.amber[50]
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // From person
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fromName +
                                          (isCurrentUserPaying ? ' (You)' : ''),
                                      style: TextStyle(
                                        fontWeight: isCurrentUserPaying
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'pays',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),

                              // Arrow and amount
                              Column(
                                children: [
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[700],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '₹${settlement.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // To person
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      toName +
                                          (isCurrentUserReceiving
                                              ? ' (You)'
                                              : ''),
                                      style: TextStyle(
                                        fontWeight: isCurrentUserReceiving
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'receives',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),

                const SizedBox(height: 16),

                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'These payments will settle all balances with the minimum number of transactions.',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 48,
                        color: Colors.green[700],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All Settled!',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Everyone is settled up. No pending payments.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.green[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<String> _getUserName(
    FirestoreService firestoreService,
    String uid,
  ) async {
    try {
      final profile = await firestoreService.getUserProfile(uid);
      return _pickName(profile, uid);
    } catch (e) {
      return _fallbackFromUid(uid);
    }
  }

  String _pickName(Map<String, dynamic>? profile, String uid) {
    if (profile == null) return _fallbackFromUid(uid);

    // Log the profile data for debugging
    print('👤 Profile data for $uid: $profile');

    // Try displayName first (most common)
    if (profile['displayName'] is String &&
        (profile['displayName'] as String).trim().isNotEmpty) {
      return (profile['displayName'] as String).trim();
    }

    // Try other name fields
    final candidates = ['name', 'fullName', 'username'];
    for (final key in candidates) {
      final v = profile[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }

    // Use email username as fallback
    final email = profile['email'];
    if (email is String && email.trim().isNotEmpty) {
      final username = email.split('@')[0];
      if (username.isNotEmpty) return username;
    }

    // Use phone number as last resort
    final phone = profile['phoneNumber'];
    if (phone is String && phone.trim().isNotEmpty) {
      return 'User ${phone.substring(0, 4)}';
    }

    return _fallbackFromUid(uid);
  }

  String _fallbackFromUid(String uid) {
    return uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;
  }
}

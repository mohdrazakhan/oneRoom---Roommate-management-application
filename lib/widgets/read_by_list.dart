import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ReadByList extends StatelessWidget {
  final List<String> userIds;

  const ReadByList({super.key, required this.userIds});

  @override
  Widget build(BuildContext context) {
    if (userIds.isEmpty) {
      return const Text('Read by 0 people');
    }

    // Fetch up to 10 readers
    final displayIds = userIds.take(10).toList();
    final remaining = userIds.length - displayIds.length;

    return FutureBuilder<List<Map<String, dynamic>?>>(
      future: Future.wait(
        displayIds.map((uid) => FirestoreService().getUserProfile(uid)),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('Loading readers...');
        }

        final names = snapshot.data!
            .map((data) => data?['displayName'] as String? ?? 'Unknown')
            .join(', ');

        String text = 'Read by: $names';
        if (remaining > 0) {
          text += ' and $remaining others';
        }

        return Text(text);
      },
    );
  }
}

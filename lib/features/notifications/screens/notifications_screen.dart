import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view notifications')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Text('Failed to load notifications: ${snap.error}'),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          final docs = [...snap.data!.docs]..sort((a, b) {
              final da = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final db = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final ta = da?.toDate();
              final tb = db?.toDate();
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final message = data['message'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;
              final timeText = createdAt != null
                  ? TimeOfDay.fromDateTime(createdAt.toDate()).format(context)
                  : '';

              return ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(message),
                subtitle:
                    timeText.isNotEmpty ? Text(timeText) : const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}


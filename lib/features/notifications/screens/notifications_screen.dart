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
        .orderBy('createdAt', descending: true)
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

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          final docs = snap.data!.docs;

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


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const accent = Color(0xffff7a00);

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: accent),
            );
          }

          if (snap.hasError) {
            return Center(
              child: Text(
                'Failed to load notifications: ${snap.error}',
                style: const TextStyle(color: Colors.black87),
              ),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 44, color: accent),
                  SizedBox(height: 8),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            );
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

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final message = data['message'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;
              final timeText = createdAt != null
                  ? TimeOfDay.fromDateTime(createdAt.toDate()).format(context)
                  : '';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffffd3b0)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xfffff1e6),
                    child: Icon(Icons.notifications, color: accent),
                  ),
                  title: Text(
                    message,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                  subtitle: timeText.isNotEmpty
                      ? Text(
                          timeText,
                          style: const TextStyle(color: Colors.black54),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}


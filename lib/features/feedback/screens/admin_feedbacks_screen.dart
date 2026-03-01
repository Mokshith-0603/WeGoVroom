import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminFeedbacksScreen extends StatelessWidget {
  const AdminFeedbacksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Feedbacks'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('feedbacks').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load feedbacks.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = [...(snap.data?.docs ?? const <QueryDocumentSnapshot>[])]
            ..sort((a, b) {
              final da = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
                  ?.toDate();
              final db = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
                  ?.toDate();
              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;
              return db.compareTo(da);
            });

          if (docs.isEmpty) {
            return const Center(child: Text('No feedbacks yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final name = (data['userName'] ?? 'User').toString();
              final email = (data['email'] ?? '').toString();
              final message = (data['message'] ?? '').toString();
              final rating = (data['rating'] ?? 0).toString();
              final createdAt = data['createdAt'] as Timestamp?;
              final date = createdAt == null
                  ? ''
                  : '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '$rating/5',
                          style: const TextStyle(
                            color: Color(0xffff7a00),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(email, style: TextStyle(color: Colors.grey.shade700)),
                      ),
                    const SizedBox(height: 8),
                    Text(message),
                    if (date.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          date,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

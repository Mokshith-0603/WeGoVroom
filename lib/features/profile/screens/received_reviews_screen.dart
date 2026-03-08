import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceivedReviewsScreen extends StatelessWidget {
  const ReceivedReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const accent = Color(0xffff7a00);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view reviews')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff6f6f6),
      appBar: AppBar(
        title: const Text('Reviews About You'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tripReviews')
            .where('revieweeId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: accent),
            );
          }

          if (snap.hasError) {
            return Center(
              child: Text('Failed to load reviews: ${snap.error}'),
            );
          }

          final docs = List<QueryDocumentSnapshot>.from(
            snap.data?.docs ?? const [],
          );
          docs.sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bd = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final at = ad?.toDate();
            final bt = bd?.toDate();
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rate_review_outlined, size: 44, color: accent),
                  SizedBox(height: 8),
                  Text('No one has reviewed you yet'),
                ],
              ),
            );
          }

          double total = 0;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            total += ((data['rating'] ?? 0) as num).toDouble();
          }
          final average = total / docs.length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xffffd3b0)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xfffff0e1),
                      child: Icon(Icons.star_rounded, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Review Summary',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${average.toStringAsFixed(1)}/5 from ${docs.length} reviews',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final reviewerName =
                        (data['reviewerName'] ?? 'User').toString();
                    final rating = ((data['rating'] ?? 0) as num).toDouble();
                    final comment = (data['comment'] ?? '').toString().trim();
                    final createdAt = data['createdAt'] as Timestamp?;
                    final tripId = (data['tripId'] ?? '').toString();

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 8,
                            color: Color(0x12000000),
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xfffff0e1),
                                child: Icon(
                                  Icons.person_outline,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reviewerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (createdAt != null)
                                      Text(
                                        DateFormat(
                                          'dd MMM, hh:mm a',
                                        ).format(createdAt.toDate()),
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xfffff0e1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${rating.toStringAsFixed(1)}/5',
                                  style: const TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xfff7f7f7),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                comment,
                                style: const TextStyle(height: 1.35),
                              ),
                            ),
                          ],
                          if (tripId.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Trip: $tripId',
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

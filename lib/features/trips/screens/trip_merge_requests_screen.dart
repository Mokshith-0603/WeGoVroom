import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TripMergeRequestsScreen extends StatelessWidget {
  const TripMergeRequestsScreen({super.key});

  Future<void> _respond(
    BuildContext context,
    String requestId,
    bool accepted,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('tripMergeRequests')
          .doc(requestId)
          .collection('acceptances')
          .doc(user.uid)
          .set({
            'accepted': accepted,
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accepted
                  ? 'Accepted. The trips merge after the other host accepts.'
                  : 'Declined. Both trips will stay unchanged.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your response.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trip merge requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tripMergeRequests')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load merge requests.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final ad = a.data()['createdAt'] as Timestamp?;
              final bd = b.data()['createdAt'] as Timestamp?;
              return (bd?.millisecondsSinceEpoch ?? 0)
                  .compareTo(ad?.millisecondsSinceEpoch ?? 0);
            });
          if (requests.isEmpty) {
            return const Center(child: Text('No matching trips found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final data = request.data();
              final status = (data['status'] ?? 'pending').toString();
              final dateTime = (data['dateTime'] as Timestamp?)?.toDate();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['destination']?.toString() ?? 'Matching trip',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (dateTime != null) ...[
                        const SizedBox(height: 6),
                        Text(DateFormat('dd MMM yyyy, hh:mm a').format(dateTime)),
                      ],
                      const SizedBox(height: 8),
                      Text('Status: ${status.toUpperCase()}'),
                      if (status == 'pending') ...[
                        const SizedBox(height: 12),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('tripMergeRequests')
                              .doc(request.id)
                              .collection('acceptances')
                              .doc(user.uid)
                              .snapshots(),
                          builder: (context, responseSnapshot) {
                            if (responseSnapshot.data?.exists == true) {
                              final accepted =
                                  responseSnapshot.data!.data()?['accepted'] ==
                                      true;
                              return Text(
                                accepted
                                    ? 'You accepted this request'
                                    : 'You declined this request',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }
                            return Row(
                              children: [
                                FilledButton(
                                  onPressed: () =>
                                      _respond(context, request.id, true),
                                  child: const Text('Accept'),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: () =>
                                      _respond(context, request.id, false),
                                  child: const Text('Decline'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String? tripId;

  const ChatScreen({
    super.key,
    this.tripId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final db = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final controller = TextEditingController();
  bool _canChat = false;
  String? _effectiveTripId;

  Future<String?> _resolveFallbackTripId() async {
    if (uid == null) return null;

    final participantSnap = await db
        .collection('tripParticipants')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();

    if (participantSnap.docs.isNotEmpty) {
      final data = participantSnap.docs.first.data();
      final tripId = data['tripId'] as String?;
      if (tripId != null && tripId.isNotEmpty) return tripId;
    }

    final ownerSnap =
        await db.collection('trips').where('ownerId', isEqualTo: uid).limit(1).get();
    if (ownerSnap.docs.isNotEmpty) {
      return ownerSnap.docs.first.id;
    }

    return null;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _noTrip() {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 60, color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(
              'No Active Trip Chat',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              'Join a trip to start chatting',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> send() async {
    if (_effectiveTripId == null || uid == null || !_canChat) return;

    final text = controller.text.trim();
    if (text.isEmpty) return;

    try {
      await db.collection('tripMessages').add({
        'tripId': _effectiveTripId,
        'senderId': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) return _noTrip();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secondary = scheme.secondary;
    final bg = theme.scaffoldBackgroundColor;

    if (widget.tripId != null) {
      _effectiveTripId = widget.tripId;
    }

    if (_effectiveTripId == null) {
      return FutureBuilder<String?>(
        future: _resolveFallbackTripId(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final resolvedTripId = snap.data;
          if (resolvedTripId == null) return _noTrip();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_effectiveTripId != resolvedTripId) {
              setState(() => _effectiveTripId = resolvedTripId);
            }
          });

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: db
          .collection('trips')
          .doc(_effectiveTripId)
          .snapshots(),
      builder: (context, tripSnap) {
        if (tripSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final tripData = tripSnap.data?.data() as Map<String, dynamic>?;
        final isOwner = tripData != null && tripData['ownerId'] == uid;

        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('tripParticipants')
              .where('tripId', isEqualTo: _effectiveTripId)
              .snapshots(),
          builder: (context, participantSnap) {
            if (participantSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final docs = participantSnap.data?.docs ?? const [];
            final isParticipant = docs.any((d) {
              final data = d.data() as Map<String, dynamic>;
              return data['userId'] == uid;
            });

            _canChat = isOwner || isParticipant;
            if (!_canChat) return _noTrip();

            return Scaffold(
              backgroundColor: bg,
              appBar: AppBar(
                title: const Text('Trip Chat'),
                elevation: 0,
              ),
              body: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: db
                          .collection('tripMessages')
                          .where('tripId', isEqualTo: _effectiveTripId)
                          .snapshots(),
                      builder: (_, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snap.hasData || snap.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'Start the conversation',
                              style: theme.textTheme.bodyLarge,
                            ),
                          );
                        }

                        final docs = [...snap.data!.docs]
                          ..sort((a, b) {
                            final ta =
                                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                            final tb =
                                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                            final da = ta?.toDate();
                            final dbb = tb?.toDate();
                            if (da == null && dbb == null) return 0;
                            if (da == null) return 1;
                            if (dbb == null) return -1;
                            return da.compareTo(dbb);
                          });

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final data = docs[i].data() as Map<String, dynamic>;
                            final mine = data['senderId'] == uid;
                            final timestamp = data['createdAt'] as Timestamp?;
                            final time = timestamp != null
                                ? DateFormat('HH:mm').format(timestamp.toDate())
                                : '';

                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                                ),
                                decoration: BoxDecoration(
                                  color: mine ? secondary : Colors.grey[300],
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: Radius.circular(mine ? 12 : 0),
                                    bottomRight: Radius.circular(mine ? 0 : 12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['text'] ?? '',
                                      style: TextStyle(
                                        color: mine ? Colors.white : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (time.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          time,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: mine ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              filled: true,
                              fillColor: bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: secondary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.send, color: scheme.onSecondary),
                            onPressed: send,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/responsive.dart';

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

  @override
  void initState() {
    super.initState();
    _effectiveTripId = widget.tripId;
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tripId != null && widget.tripId != oldWidget.tripId) {
      _effectiveTripId = widget.tripId;
    }
  }

  bool _isTripActive(Map<String, dynamic> tripData) {
    return tripData['completed'] != true;
  }

  int _tripSortScore(Map<String, dynamic> tripData) {
    final ts = tripData['dateTime'];
    try {
      if (ts == null) return 1 << 30;
      final dt = (ts as Timestamp).toDate();
      return dt.millisecondsSinceEpoch;
    } catch (_) {
      return 1 << 30;
    }
  }

  Future<String?> _resolveFallbackTripId({String? excludeTripId}) async {
    if (uid == null) return null;

    final candidates = <Map<String, dynamic>>[];

    final participantSnap = await db
        .collection('tripParticipants')
        .where('userId', isEqualTo: uid)
        .get();

    for (final p in participantSnap.docs) {
      final tripId = p.data()['tripId'] as String?;
      if (tripId == null || tripId.isEmpty) continue;
      if (excludeTripId != null && tripId == excludeTripId) continue;

      final tripDoc = await db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) continue;

      final data = tripDoc.data();
      if (data == null || !_isTripActive(data)) continue;

      candidates.add({'id': tripId, 'data': data});
    }

    final ownerSnap = await db.collection('trips').where('ownerId', isEqualTo: uid).get();
    for (final t in ownerSnap.docs) {
      if (excludeTripId != null && t.id == excludeTripId) continue;
      final data = t.data();
      if (!_isTripActive(data)) continue;

      if (candidates.any((c) => c['id'] == t.id)) continue;
      candidates.add({'id': t.id, 'data': data});
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aa = _tripSortScore(a['data'] as Map<String, dynamic>);
      final bb = _tripSortScore(b['data'] as Map<String, dynamic>);
      return aa.compareTo(bb);
    });

    return candidates.first['id'] as String;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _noTrip() {
    final theme = Theme.of(context);
    final r = context.rs;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: r(60), color: theme.disabledColor),
            SizedBox(height: r(12)),
            Text(
              'No Active Trip Chat',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: r(18)),
            ),
            SizedBox(height: r(6)),
            Text(
              'Join a trip to start chatting',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey, fontSize: r(14)),
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
    final r = context.rs;

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
        final isActiveTrip = tripData != null && _isTripActive(tripData);

        if (!isActiveTrip) {
          return FutureBuilder<String?>(
            future: _resolveFallbackTripId(excludeTripId: _effectiveTripId),
            builder: (context, nextSnap) {
              if (nextSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final nextTripId = nextSnap.data;
              if (nextTripId == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (_effectiveTripId != null) {
                    setState(() => _effectiveTripId = null);
                  }
                });
                return _noTrip();
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_effectiveTripId != nextTripId) {
                  setState(() => _effectiveTripId = nextTripId);
                }
              });

              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          );
        }

        final isOwner = tripData['ownerId'] == uid;

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
                          padding: EdgeInsets.symmetric(horizontal: r(8), vertical: r(12)),
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
                                margin: EdgeInsets.symmetric(vertical: r(4)),
                                padding: EdgeInsets.symmetric(horizontal: r(14), vertical: r(10)),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width *
                                      (context.isTablet ? 0.5 : 0.72),
                                ),
                                decoration: BoxDecoration(
                                  color: mine ? secondary : Colors.grey[300],
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(r(12)),
                                    topRight: Radius.circular(r(12)),
                                    bottomLeft: Radius.circular(mine ? r(12) : 0),
                                    bottomRight: Radius.circular(mine ? 0 : r(12)),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['text'] ?? '',
                                      style: TextStyle(
                                        color: mine ? Colors.white : Colors.black87,
                                        fontSize: r(15),
                                      ),
                                    ),
                                    if (time.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: r(4)),
                                        child: Text(
                                          time,
                                          style: TextStyle(
                                            fontSize: r(12),
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
                    padding: EdgeInsets.symmetric(horizontal: r(12), vertical: r(10)),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: r(16), vertical: r(10)),
                              filled: true,
                              fillColor: bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(r(25)),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: r(8)),
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

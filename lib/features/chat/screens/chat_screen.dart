import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../utils/responsive.dart';
import '../../profile/widgets/avatar_utils.dart';

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

  bool _profileLoaded = false;
  String _myName = 'User';
  int _myAvatar = 0;

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

  DateTime? _tripDateTime(Map<String, dynamic> tripData) {
    final ts = tripData['dateTime'];
    try {
      if (ts is Timestamp) return ts.toDate();
    } catch (_) {}
    return null;
  }

  bool _isTripActive(Map<String, dynamic> tripData) {
    if (tripData['completed'] == true) return false;
    final dt = _tripDateTime(tripData);
    if (dt == null) return false;
    return dt.isAfter(DateTime.now());
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

  Future<void> _ensureMyProfileLoaded() async {
    if (_profileLoaded || uid == null) return;

    try {
      final doc = await db.collection('users').doc(uid).get();
      final data = doc.data() ?? const <String, dynamic>{};
      _myName = (data['displayName'] ?? data['name'] ?? 'User').toString();
      _myAvatar = normalizeAvatarIndex(data['avatar']);
    } catch (_) {
      _myName = 'User';
      _myAvatar = 0;
    }

    _profileLoaded = true;
  }

  Future<String?> _resolveFallbackTripId({String? excludeTripId}) async {
    if (uid == null) return null;

    final candidates = <Map<String, dynamic>>[];

    final participantSnap =
        await db.collection('tripParticipants').where('userId', isEqualTo: uid).get();

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
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: r(82),
              width: r(82),
              decoration: BoxDecoration(
                color: const Color(0xfffff2e8),
                borderRadius: BorderRadius.circular(r(22)),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xffff7a00),
                size: 38,
              ),
            ),
            SizedBox(height: r(14)),
            Text(
              'No Active Trip Chat',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: r(19)),
            ),
            SizedBox(height: r(6)),
            Text(
              'Join a trip to start chatting',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontSize: r(14),
              ),
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

    await _ensureMyProfileLoaded();

    try {
      await db.collection('tripMessages').add({
        'tripId': _effectiveTripId,
        'senderId': uid,
        'senderName': _myName,
        'senderAvatar': _myAvatar,
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

  Widget _buildMessageItem({
    required Map<String, dynamic> data,
    required Map<String, Map<String, dynamic>> participantMeta,
    required bool mine,
    required Color secondary,
  }) {
    final r = context.rs;
    final senderId = data['senderId']?.toString() ?? '';
    final meta = participantMeta[senderId] ?? const <String, dynamic>{};

    final senderName = (data['senderName'] ?? meta['name'] ?? (mine ? 'You' : 'User')).toString();
    final avatarIndex = normalizeAvatarIndex(data['senderAvatar'] ?? meta['avatar']);

    final timestamp = data['createdAt'] as Timestamp?;
    final time = timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : '';

    final bubble = Container(
      margin: EdgeInsets.symmetric(vertical: r(6)),
      padding: EdgeInsets.symmetric(horizontal: r(14), vertical: r(10)),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * (context.isTablet ? 0.5 : 0.68),
      ),
      decoration: BoxDecoration(
        color: mine ? secondary : Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(r(14)),
          topRight: Radius.circular(r(14)),
          bottomLeft: Radius.circular(mine ? r(14) : 0),
          bottomRight: Radius.circular(mine ? 0 : r(14)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mine ? 'You' : senderName,
            style: TextStyle(
              fontSize: r(11),
              fontWeight: FontWeight.w700,
              color: mine ? Colors.black87 : Colors.white70,
            ),
          ),
          SizedBox(height: r(3)),
          Text(
            (data['text'] ?? '').toString(),
            style: TextStyle(
              color: mine ? Colors.black : Colors.white,
              fontSize: r(14.5),
            ),
          ),
          if (time.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: r(5)),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: r(11),
                  color: mine ? Colors.black54 : Colors.white60,
                ),
              ),
            ),
        ],
      ),
    );

    final avatar = Padding(
      padding: EdgeInsets.only(
        left: mine ? r(8) : 0,
        right: mine ? 0 : r(8),
        bottom: r(4),
      ),
      child: buildAvatar(avatarIndex, radius: r(13)),
    );

    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: mine ? [bubble, avatar] : [avatar, bubble],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) return _noTrip();

    final secondary = Theme.of(context).colorScheme.secondary;
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
      stream: db.collection('trips').doc(_effectiveTripId).snapshots(),
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

            if (!_profileLoaded) {
              _ensureMyProfileLoaded();
            }

            final participantMeta = <String, Map<String, dynamic>>{};
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              final pid = data['userId']?.toString();
              if (pid == null || pid.isEmpty) continue;
              participantMeta[pid] = {
                'name': data['name'] ?? 'User',
                'avatar': normalizeAvatarIndex(data['avatar']),
              };
            }

            final ownerId = tripData['ownerId']?.toString() ?? '';
            if (ownerId.isNotEmpty && !participantMeta.containsKey(ownerId)) {
              participantMeta[ownerId] = {
                'name': tripData['ownerName'] ?? 'Host',
                'avatar': normalizeAvatarIndex(tripData['ownerAvatar']),
              };
            }

            final tripTitle = '${tripData['from'] ?? ''} -> ${tripData['to'] ?? ''}';

            return Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Column(
                  children: [
                    Container(
                      color: Colors.black,
                      padding: EdgeInsets.fromLTRB(r(14), r(10), r(14), r(12)),
                      child: Row(
                        children: [
                          Container(
                            width: r(34),
                            height: r(34),
                            decoration: BoxDecoration(
                              color: secondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat, color: Colors.black, size: 20),
                          ),
                          SizedBox(width: r(10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trip Chat',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: r(16),
                                  ),
                                ),
                                Text(
                                  tripTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white70, fontSize: r(12)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: r(8),
                            height: r(8),
                            decoration: const BoxDecoration(
                              color: Color(0xff35d16f),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned(
                            left: -80,
                            top: 80,
                            child: Container(
                              width: 230,
                              height: 230,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: secondary.withOpacity(0.08),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -70,
                            bottom: 120,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.05),
                              ),
                            ),
                          ),
                          StreamBuilder<QuerySnapshot>(
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
                                    style: TextStyle(color: Colors.grey[700], fontSize: r(15)),
                                  ),
                                );
                              }

                              final messageDocs = [...snap.data!.docs]
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
                                padding: EdgeInsets.symmetric(horizontal: r(12), vertical: r(12)),
                                itemCount: messageDocs.length,
                                itemBuilder: (_, i) {
                                  final data = messageDocs[i].data() as Map<String, dynamic>;
                                  final mine = data['senderId'] == uid;

                                  return _buildMessageItem(
                                    data: data,
                                    participantMeta: participantMeta,
                                    mine: mine,
                                    secondary: secondary,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.fromLTRB(r(12), r(8), r(12), r(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: secondary.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(r(30)),
                                border: Border.all(
                                  color: secondary.withOpacity(0.35),
                                ),
                              ),
                              child: TextField(
                                controller: controller,
                                maxLines: null,
                                style: const TextStyle(color: Colors.black87),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => send(),
                                decoration: InputDecoration(
                                  hintText: 'Send a message',
                                  hintStyle: TextStyle(color: Colors.black54, fontSize: r(14)),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: r(18), vertical: r(12)),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: r(8)),
                          Container(
                            decoration: BoxDecoration(
                              color: secondary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: secondary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: send,
                              icon: const Icon(Icons.send_rounded, color: Colors.black),
                            ),
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
      },
    );
  }
}

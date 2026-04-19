import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_profile_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _markingAsRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markNotificationsAsRead();
    });
  }

  Future<void> _markNotificationsAsRead() async {
    if (_markingAsRead) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _markingAsRead = true;
    try {
      final notificationsSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      final unreadDocs = notificationsSnap.docs
          .where((doc) => doc.data()['isRead'] != true)
          .toList();

      if (unreadDocs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadDocs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {
      // If marking read fails, the badge will remain until the next successful visit.
    } finally {
      _markingAsRead = false;
    }
  }

  static const _accent = Color(0xffff7a00);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
      backgroundColor: const Color(0xfff5f5f7).withValues(alpha: 0.94),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Notifications'),
            SizedBox(width: 8),
            Icon(Icons.notifications_active, color: _accent, size: 20),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
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

          final docs = List<QueryDocumentSnapshot>.from(
            snap.data?.docs ?? const [],
          );
          docs.sort((a, b) {
            final da =
                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final db =
                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final ta = da?.toDate();
            final tb = db?.toDate();
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 44, color: _accent),
                  SizedBox(height: 8),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            );
          }

          final profileProvider = context.read<UserProfileProvider>();
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final actorId = (data['actorId'] ?? '').toString().trim();
            if (actorId.isNotEmpty) {
              profileProvider.listenToUserProfile(actorId);
            }
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _NotificationCard(data: data);
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _NotificationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final appearance = _NotificationAppearance.from(data);
    final isUnread = data['isRead'] != true;
    final actorId = (data['actorId'] ?? '').toString().trim();
    final storedMessage = (data['message'] ?? '').toString();
    final storedActorName = (data['actorName'] ?? '').toString().trim();
    final actorProfile = actorId.isNotEmpty
        ? context.watch<UserProfileProvider>().getUserProfile(actorId)
        : null;
    final actorName =
        (actorProfile?['displayName'] ??
                actorProfile?['name'] ??
                storedActorName)
            .toString()
            .trim();
    final message = _replaceActorName(
      storedMessage,
      oldName: storedActorName,
      newName: actorName,
    );
    final createdAt = data['createdAt'] as Timestamp?;
    final tripId = (data['tripId'] ?? '').toString().trim();

    final timeText = createdAt == null
        ? ''
        : DateFormat('dd MMM, hh:mm a').format(createdAt.toDate());

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [appearance.backgroundTop, appearance.backgroundBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: appearance.borderColor),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            color: appearance.shadowColor,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: appearance.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(appearance.icon, color: appearance.iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              appearance.title,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _Badge(
                            label: isUnread
                                ? '${appearance.badgeLabel}  NEW'
                                : appearance.badgeLabel,
                            background: appearance.badgeBackground,
                            foreground: appearance.badgeForeground,
                          ),
                        ],
                      ),
                      if (appearance.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          appearance.subtitle,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.black87,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (actorName.isNotEmpty)
                  _MetaChip(
                    icon: Icons.person_outline,
                    label: actorName,
                    tint: appearance.primary,
                  ),
                if (tripId.isNotEmpty)
                  _MetaChip(
                    icon: Icons.route_outlined,
                    label: 'Trip update',
                    tint: appearance.primary,
                  ),
                if (timeText.isNotEmpty)
                  _MetaChip(
                    icon: Icons.schedule_outlined,
                    label: timeText,
                    tint: appearance.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _replaceActorName(
  String message, {
  required String oldName,
  required String newName,
}) {
  if (message.isEmpty ||
      oldName.isEmpty ||
      newName.isEmpty ||
      oldName == newName) {
    return message;
  }

  return message.replaceFirst(oldName, newName);
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _NotificationAppearance {
  final String title;
  final String subtitle;
  final String badgeLabel;
  final IconData icon;
  final Color primary;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color borderColor;
  final Color shadowColor;
  final Color iconBackground;
  final Color iconColor;
  final Color badgeBackground;
  final Color badgeForeground;

  const _NotificationAppearance({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.icon,
    required this.primary,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.borderColor,
    required this.shadowColor,
    required this.iconBackground,
    required this.iconColor,
    required this.badgeBackground,
    required this.badgeForeground,
  });

  factory _NotificationAppearance.from(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim();
    final createdBy = (data['createdBy'] ?? '').toString().trim();

    if (type == 'admin_announcement' || (type.isEmpty && createdBy.isNotEmpty)) {
      return const _NotificationAppearance(
        title: 'WeGoVroom Team',
        subtitle: 'Message from administration',
        badgeLabel: 'ADMIN',
        icon: Icons.campaign_outlined,
        primary: Color(0xffff7a00),
        backgroundTop: Color(0xfffff6ee),
        backgroundBottom: Color(0xffffead7),
        borderColor: Color(0xffffc89a),
        shadowColor: Color(0x1fff7a00),
        iconBackground: Color(0xffffe3c7),
        iconColor: Color(0xff9b4d00),
        badgeBackground: Color(0xff2d2118),
        badgeForeground: Color(0xffffc48b),
      );
    }

    switch (type) {
      case 'trip_left':
        return const _NotificationAppearance(
          title: 'Trip Exit',
          subtitle: 'A participant left your trip',
          badgeLabel: 'LEAVE',
          icon: Icons.logout_rounded,
          primary: Color(0xffc45a00),
          backgroundTop: Color(0xfffff3eb),
          backgroundBottom: Color(0xffffe1d2),
          borderColor: Color(0xffffc0a2),
          shadowColor: Color(0x18c45a00),
          iconBackground: Color(0xffffd4c0),
          iconColor: Color(0xff8a3d00),
          badgeBackground: Color(0xff8a3d00),
          badgeForeground: Color(0xffffefe5),
        );
      case 'trip_removed':
        return const _NotificationAppearance(
          title: 'Removed From Trip',
          subtitle: 'Host removed you from a trip',
          badgeLabel: 'REMOVED',
          icon: Icons.person_remove_alt_1_outlined,
          primary: Color(0xffb3261e),
          backgroundTop: Color(0xfffff1f1),
          backgroundBottom: Color(0xffffdfdf),
          borderColor: Color(0xffffb0b0),
          shadowColor: Color(0x18b3261e),
          iconBackground: Color(0xffffd3d1),
          iconColor: Color(0xff8a1c16),
          badgeBackground: Color(0xff8a1c16),
          badgeForeground: Color(0xffffefef),
        );
      case 'trip_request':
        return const _NotificationAppearance(
          title: 'Join Request',
          subtitle: 'Someone wants to join your trip',
          badgeLabel: 'REQUEST',
          icon: Icons.mark_email_unread_outlined,
          primary: Color(0xff2563eb),
          backgroundTop: Color(0xfff2f7ff),
          backgroundBottom: Color(0xffe3efff),
          borderColor: Color(0xffb8d1ff),
          shadowColor: Color(0x182563eb),
          iconBackground: Color(0xffd9e7ff),
          iconColor: Color(0xff1d4ed8),
          badgeBackground: Color(0xff1d4ed8),
          badgeForeground: Color(0xffeff6ff),
        );
      case 'trip_request_approved':
        return const _NotificationAppearance(
          title: 'Request Approved',
          subtitle: 'Your trip request was accepted',
          badgeLabel: 'APPROVED',
          icon: Icons.verified_outlined,
          primary: Color(0xff15803d),
          backgroundTop: Color(0xfff1fbf4),
          backgroundBottom: Color(0xffdef6e5),
          borderColor: Color(0xffabdcbc),
          shadowColor: Color(0x1815803d),
          iconBackground: Color(0xffcaedd5),
          iconColor: Color(0xff166534),
          badgeBackground: Color(0xff166534),
          badgeForeground: Color(0xffeffdf5),
        );
      case 'trip_request_rejected':
        return const _NotificationAppearance(
          title: 'Request Rejected',
          subtitle: 'Your trip request was declined',
          badgeLabel: 'REJECTED',
          icon: Icons.cancel_outlined,
          primary: Color(0xffb45309),
          backgroundTop: Color(0xfffff7ed),
          backgroundBottom: Color(0xffffe7cc),
          borderColor: Color(0xffffca96),
          shadowColor: Color(0x18b45309),
          iconBackground: Color(0xffffdbb3),
          iconColor: Color(0xff92400e),
          badgeBackground: Color(0xff92400e),
          badgeForeground: Color(0xfffff7ed),
        );
      case 'trip_joined':
        return const _NotificationAppearance(
          title: 'New Participant',
          subtitle: 'Someone joined your trip',
          badgeLabel: 'JOINED',
          icon: Icons.group_add_outlined,
          primary: Color(0xff0f766e),
          backgroundTop: Color(0xffeefcf9),
          backgroundBottom: Color(0xffdaf5ee),
          borderColor: Color(0xffaadfd2),
          shadowColor: Color(0x180f766e),
          iconBackground: Color(0xffc7ebe2),
          iconColor: Color(0xff115e59),
          badgeBackground: Color(0xff115e59),
          badgeForeground: Color(0xffecfeff),
        );
      default:
        return const _NotificationAppearance(
          title: 'Notification',
          subtitle: 'General update',
          badgeLabel: 'INFO',
          icon: Icons.notifications_outlined,
          primary: Color(0xff475569),
          backgroundTop: Color(0xfffafafa),
          backgroundBottom: Color(0xfff1f5f9),
          borderColor: Color(0xffdbe2ea),
          shadowColor: Color(0x14475569),
          iconBackground: Color(0xffe8edf3),
          iconColor: Color(0xff334155),
          badgeBackground: Color(0xff334155),
          badgeForeground: Color(0xfff8fafc),
        );
    }
  }
}

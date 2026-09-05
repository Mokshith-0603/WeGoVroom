import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_profile_provider.dart';
import '../../../theme/app_theme.dart';
import '../widgets/notification_indicator_icon.dart';

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

  static const _accent = AppTheme.brandOrange;

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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050B12) : const Color(0xFFFFFCF8),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF07131F), Color(0xFF03070C)]
                : const [Color(0xFFFFFCF8), Color(0xFFFFF8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Notifications',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    NotificationIndicatorIcon(
                      icon: Icons.notifications_none_rounded,
                      iconColor: theme.colorScheme.onSurface,
                      size: 26,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _accent),
                      );
                    }

                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Failed to load notifications: ${snap.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }

                    final docs = List<QueryDocumentSnapshot>.from(
                      snap.data?.docs ?? const [],
                    );
                    docs.sort((a, b) {
                      final da =
                          (a.data() as Map<String, dynamic>)['createdAt']
                              as Timestamp?;
                      final db =
                          (b.data() as Map<String, dynamic>)['createdAt']
                              as Timestamp?;
                      final ta = da?.toDate();
                      final tb = db?.toDate();
                      if (ta == null && tb == null) return 0;
                      if (ta == null) return 1;
                      if (tb == null) return -1;
                      return tb.compareTo(ta);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 42,
                                color: _accent,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No notifications yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
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

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _NotificationCard(data: data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 70),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: appearance.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: appearance.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF10161D),
                          appearance.primary.withValues(alpha: 0.075),
                        ]
                      : [appearance.backgroundTop, appearance.backgroundBottom],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? appearance.primary.withValues(alpha: 0.35)
                      : appearance.borderColor,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 22,
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.20)
                        : appearance.shadowColor,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                              width: 58,
                              height: 58,
                  decoration: BoxDecoration(
                                color: isDark
                                    ? appearance.primary.withValues(alpha: 0.16)
                                    : appearance.iconBackground,
                    shape: BoxShape.circle,
                  ),
                              child: Icon(
                                appearance.icon,
                                color: appearance.primary,
                                size: 28,
                              ),
                ),
                            const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              appearance.title,
                              style: TextStyle(
                                            color: appearance.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _Badge(
                                        label: isUnread
                                            ? '${appearance.badgeLabel} NEW'
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
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                                            alpha: 0.58,
                            ),
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
                        const SizedBox(height: 14),
                        Text(
                          message,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            height: 1.36,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
              ),
                        const SizedBox(height: 16),
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
              ],
            ),
                        if (timeText.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_outlined,
                                size: 17,
                                color: isDark
                                    ? theme.colorScheme.onSurface.withValues(
                                        alpha: 0.70,
                                      )
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.58,
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? theme.colorScheme.onSurface.withValues(
                                          alpha: 0.70,
                                        )
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.58,
                                        ),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
          ],
        ),
      ),
            ),
          ),
        ],
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

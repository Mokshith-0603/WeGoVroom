import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/theme_mode_provider.dart';
import '../../contact/screens/contact_us_screen.dart';
import '../../feedback/screens/admin_feedbacks_screen.dart';
import '../../feedback/screens/feedback_form_screen.dart';
import '../../notifications/screens/admin_notifications_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../notifications/widgets/notification_indicator_icon.dart';
import '../screens/received_reviews_screen.dart';
import '../../auth/screens/change_password_screen.dart';
import '../screens/profile_setup_screen.dart';
import 'avatar_utils.dart';
import '../../../utils/responsive.dart';
import '../../../theme/app_theme.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  Future<_DrawerPayload>? _drawerFuture;

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  bool _isAdmin(Map<String, dynamic> data) {
    final role = data['role']?.toString().trim().toLowerCase();
    return role == 'admin' ||
        _parseBool(data['isAdmin']) ||
        _parseBool(data['admin']);
  }

  Future<int> _completedTripCount(String? uid) async {
    if (uid == null) return 0;

    final db = FirebaseFirestore.instance;
    final completedTripIds = <String>{};
    final now = DateTime.now();

    final ownedSnapFuture = db
        .collection('trips')
        .where('ownerId', isEqualTo: uid)
        .get();
    final participantSnapFuture = db
        .collection('tripParticipants')
        .where('userId', isEqualTo: uid)
        .get();

    final ownedSnap = await ownedSnapFuture;
    for (final doc in ownedSnap.docs) {
      final data = doc.data();
      DateTime? dt;
      try {
        dt = (data['dateTime'] as Timestamp?)?.toDate();
      } catch (_) {}
      final autoEnded =
          dt != null && !now.isBefore(dt.add(const Duration(hours: 12)));
      if (data['completed'] == true || autoEnded) {
        completedTripIds.add(doc.id);
      }
    }

    final participantSnap = await participantSnapFuture;
    final participantTripIds = participantSnap.docs
        .map((p) => p.data()['tripId'] as String?)
        .whereType<String>()
        .where(
          (tripId) => tripId.isNotEmpty && !completedTripIds.contains(tripId),
        )
        .toSet()
        .toList();

    for (var i = 0; i < participantTripIds.length; i += 10) {
      final chunk = participantTripIds.sublist(
        i,
        i + 10 > participantTripIds.length ? participantTripIds.length : i + 10,
      );
      final tripsSnap = await db
          .collection('trips')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final tripDoc in tripsSnap.docs) {
        final tripData = tripDoc.data();
        DateTime? dt;
        try {
          dt = (tripData['dateTime'] as Timestamp?)?.toDate();
        } catch (_) {}
        final autoEnded =
            dt != null && !now.isBefore(dt.add(const Duration(hours: 12)));
        if (tripData['completed'] == true || autoEnded) {
          completedTripIds.add(tripDoc.id);
        }
      }
    }

    return completedTripIds.length;
  }

  Future<Map<String, dynamic>> _reviewSummary(String? uid) async {
    if (uid == null) {
      return {'count': 0, 'avg': 0.0};
    }

    final snap = await FirebaseFirestore.instance
        .collection('tripReviews')
        .where('revieweeId', isEqualTo: uid)
        .get();

    final docs = snap.docs;
    if (docs.isEmpty) {
      return {'count': 0, 'avg': 0.0};
    }

    double total = 0;
    for (final doc in docs) {
      final data = doc.data();
      total += ((data['rating'] ?? 0) as num).toDouble();
    }

    return {'count': docs.length, 'avg': total / docs.length};
  }

  Future<Map<String, dynamic>> _profileStats(String? uid) async {
    final results = await Future.wait<dynamic>([
      _completedTripCount(uid),
      _reviewSummary(uid),
    ]);

    return {
      'trips': results[0] as int,
      'review': results[1] as Map<String, dynamic>,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().user?.uid;
    _drawerFuture ??= _loadDrawerPayload(uid);
  }

  Future<_DrawerPayload> _loadDrawerPayload(String? uid) async {
    final profileFuture = uid == null
        ? Future.value(null)
        : FirebaseFirestore.instance.collection('users').doc(uid).get();
    final statsFuture = _profileStats(uid);
    final results = await Future.wait<dynamic>([profileFuture, statsFuture]);

    return _DrawerPayload(
      profile: results[0] as DocumentSnapshot?,
      stats: results[1] as Map<String, dynamic>,
    );
  }

  Stream<int> _unreadNotificationsStream(String? uid) {
    if (uid == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      return snap.docs.where((doc) {
        final data = doc.data();
        return data['isRead'] != true;
      }).length;
    });
  }
  void _refreshDrawer() {
    final uid = context.read<AuthProvider>().user?.uid;
    setState(() {
      _drawerFuture = _loadDrawerPayload(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: FutureBuilder<_DrawerPayload>(
          future: _drawerFuture,
          builder: (_, snap) {
            final payload = snap.data;
            final profileSnap = payload?.profile;
            Map<String, dynamic> data = {};
            if (profileSnap != null && profileSnap.exists) {
              data = profileSnap.data() as Map<String, dynamic>;
            }

            final name =
                data['displayName'] ?? user?.email?.split('@')[0] ?? 'User';

            final email = user?.email ?? '';
            final reg = data['register'] ?? '';
            final avatarIndex = normalizeAvatarIndex(data['avatar']);
            final isAdmin = _isAdmin(data);
            final stats = payload?.stats ?? const <String, dynamic>{};
            final completedTrips = (stats['trips'] ?? 0) as int;
            final review =
                (stats['review'] ??
                        const <String, dynamic>{'count': 0, 'avg': 0.0})
                    as Map<String, dynamic>;
            final reviewCount = (review['count'] ?? 0) as int;
            final avgRating = ((review['avg'] ?? 0.0) as num).toDouble();

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(r(18), r(18), r(18), r(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _drawerHero(
                    context,
                    avatarIndex: avatarIndex,
                    name: name.toString(),
                    email: email,
                    registerNumber: reg.toString(),
                  ),
                  SizedBox(height: r(18)),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.route_rounded,
                          title: 'Trips',
                          value: completedTrips.toString(),
                        ),
                      ),
                      SizedBox(width: r(12)),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.star_rounded,
                          title: 'Reviews Got',
                          value: reviewCount.toString(),
                          subtitle: '${avgRating.toStringAsFixed(1)}/5 avg',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReceivedReviewsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r(20)),
                  _drawerTile(
                    context,
                    icon: Icons.manage_accounts_rounded,
                    title: 'Edit Profile',
                    subtitle: 'Update your info and preferences',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileSetupScreen(),
                        ),
                      );
                      if (mounted) _refreshDrawer();
                    },
                  ),
                  StreamBuilder<int>(
                    stream: _unreadNotificationsStream(user?.uid),
                    builder: (context, unreadSnap) {
                      final unreadCount = unreadSnap.data ?? 0;
                      return _drawerTile(
                        context,
                        customLeading: const NotificationIndicatorIcon(
                          icon: Icons.notifications_active_outlined,
                        ),
                        title: 'Notifications',
                        subtitle: unreadCount == 0
                            ? 'No unread notifications'
                            : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                        badge: unreadCount == 0 ? null : unreadCount.toString(),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  _themeSection(context),
                  SizedBox(height: r(9)),
                  _drawerTile(
                    context,
                    icon: Icons.enhanced_encryption_rounded,
                    title: 'Change Password',
                    subtitle: 'Keep your account secure',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerTile(
                    context,
                    icon: Icons.rate_review_rounded,
                    title: 'Feedback / Report an Issue',
                    subtitle: 'Help us improve WeGoVroom',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FeedbackFormScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerTile(
                    context,
                    icon: Icons.support_agent_rounded,
                    title: 'Contact Us',
                    subtitle: "We're here to help",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ContactUsScreen(),
                        ),
                      );
                    },
                  ),
                  if (isAdmin)
                    _drawerTile(
                      context,
                      icon: Icons.campaign_rounded,
                      title: 'Send Notifications',
                      subtitle: 'Broadcast updates to users',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminNotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  if (isAdmin)
                    _drawerTile(
                      context,
                      icon: Icons.mark_chat_read_rounded,
                      title: 'User Feedbacks',
                      subtitle: 'Review submitted reports',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminFeedbacksScreen(),
                          ),
                        );
                      },
                    ),
                  SizedBox(height: r(10)),
                  _drawerTile(
                    context,
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'See you again soon!',
                    tint: Colors.redAccent,
                    onTap: () async {
                      await context.read<AuthProvider>().logout();
                    },
                  ),
                  SizedBox(height: r(18)),
                  _safetyFooter(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    IconData? icon,
    Widget? customLeading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    Color? tint,
  }) {
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = tint ?? AppTheme.brandOrange;
    return Container(
      margin: EdgeInsets.only(bottom: r(9)),
      decoration: BoxDecoration(
        color: tint != null
            ? color.withValues(alpha: isDark ? 0.16 : 0.09)
            : (isDark ? const Color(0xFF101A24) : Colors.white),
        borderRadius: BorderRadius.circular(r(20)),
        border: Border.all(
          color: tint != null
              ? color.withValues(alpha: 0.14)
              : theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.045),
          ),
        ],
      ),
      child: ListTile(
        minLeadingWidth: 0,
        contentPadding: EdgeInsets.symmetric(horizontal: r(14), vertical: r(7)),
        leading: customLeading == null
            ? Container(
                width: r(46),
                height: r(46),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(r(14)),
                ),
                child: Icon(icon, color: color, size: r(23)),
              )
            : Container(
                width: r(46),
                height: r(46),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.brandOrange.withValues(
                    alpha: isDark ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(r(14)),
                ),
                child: customLeading,
              ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: tint ?? theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (badge != null) ...[
              SizedBox(width: r(7)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: r(6), vertical: r(2)),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: r(10),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: r(2)),
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: tint ?? theme.colorScheme.onSurface,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _themeSection(BuildContext context) {
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeModeProvider>();
    final enabled = themeMode.isDarkMode;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r(14), vertical: r(12)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101A24) : Colors.white,
        borderRadius: BorderRadius.circular(r(20)),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.045),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: r(46),
            height: r(46),
            decoration: BoxDecoration(
              color: AppTheme.brandOrange.withValues(
                alpha: isDark ? 0.16 : 0.10,
              ),
              borderRadius: BorderRadius.circular(r(14)),
            ),
            child: Icon(
              enabled ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppTheme.brandOrange,
              size: r(23),
            ),
          ),
          SizedBox(width: r(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: r(2)),
                Text(
                  enabled ? 'Dark mode enabled' : 'Light mode enabled',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeThumbColor: AppTheme.brandOrange,
            activeTrackColor: AppTheme.brandOrange.withValues(alpha: 0.28),
            onChanged: themeMode.setDarkMode,
          ),
        ],
      ),
    );
  }
  Widget _drawerHero(
    BuildContext context, {
    required int avatarIndex,
    required String name,
    required String email,
    required String registerNumber,
  }) {
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(r(18), r(20), r(18), r(22)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r(28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF071421), const Color(0xFF0D1824)]
              : [const Color(0xFFFF9A28), const Color(0xFFFFF4E8)],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 14),
            color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.09),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: r(18),
            bottom: r(22),
            child: Icon(
              Icons.location_city_rounded,
              size: r(92),
              color: theme.colorScheme.onSurface.withValues(
                alpha: isDark ? 0.08 : 0.07,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(r(4)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF07101A) : Colors.white,
                      border: Border.all(
                        color: AppTheme.brandOrange.withValues(alpha: 0.85),
                        width: isDark ? 1.4 : 0,
                      ),
                    ),
                    child: buildAvatar(avatarIndex, radius: r(42)),
                  ),
                  Positioned(
                    right: r(2),
                    bottom: r(3),
                    child: Container(
                      width: r(20),
                      height: r(20),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF07101A) : Colors.white,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r(22)),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: r(8)),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
              if (registerNumber.isNotEmpty) ...[
                SizedBox(height: r(13)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r(12),
                    vertical: r(7),
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.brandOrange.withValues(alpha: 0.6),
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        const TextSpan(
                          text: 'Reg:  ',
                          style: TextStyle(
                            color: AppTheme.brandOrange,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: registerNumber,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _safetyFooter(BuildContext context) {
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(r(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r(20)),
        color: isDark ? const Color(0xFF101A24) : const Color(0xFFFFFCF8),
        border: Border.all(
          color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.18 : 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: r(48),
            height: r(48),
            decoration: BoxDecoration(
              color: AppTheme.brandOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r(16)),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: AppTheme.brandOrange,
              size: r(28),
            ),
          ),
          SizedBox(width: r(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your safety is our priority',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: r(4)),
                Text(
                  'We keep your data safe and secure.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.brandOrange,
            size: r(26),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r(20)),
        child: Container(
          padding: EdgeInsets.all(r(16)),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101A24) : Colors.white,
            borderRadius: BorderRadius.circular(r(20)),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 8),
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: r(44),
                height: r(44),
                decoration: BoxDecoration(
                  color: AppTheme.brandOrange.withValues(
                    alpha: isDark ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(r(14)),
                ),
                child: Icon(icon, color: AppTheme.brandOrange),
              ),
              SizedBox(height: r(12)),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: r(4)),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: r(2)),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppTheme.brandOrange,
                    fontSize: r(11),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerPayload {
  final DocumentSnapshot? profile;
  final Map<String, dynamic> stats;

  const _DrawerPayload({required this.profile, required this.stats});
}

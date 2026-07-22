import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../utils/responsive.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/user_profile_provider.dart';
import '../../profile/widgets/avatar_utils.dart';

class ChatScreen extends StatefulWidget {
  final String? tripId;

  const ChatScreen({super.key, this.tripId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final db = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final controller = TextEditingController();
  late final ScrollController _scrollController;

  bool _canChat = false;
  String? _effectiveTripId;
  Future<String?>? _tripResolutionFuture;

  bool _profileLoaded = false;
  String _myName = 'User';
  int _myAvatar = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _effectiveTripId = widget.tripId;
    if (_effectiveTripId == null) {
      _tripResolutionFuture = _resolveFallbackTripId();
    }
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tripId != null && widget.tripId != oldWidget.tripId) {
      _effectiveTripId = widget.tripId;
      _tripResolutionFuture = null;
    } else if (widget.tripId == null && oldWidget.tripId != null) {
      _effectiveTripId = null;
      _queueTripResolution();
    }
  }

  void _queueTripResolution({String? excludeTripId}) {
    _tripResolutionFuture = _resolveFallbackTripId(
      excludeTripId: excludeTripId,
    );
  }

  void _setEffectiveTripId(String? tripId) {
    if (!mounted || _effectiveTripId == tripId) return;
    setState(() {
      _effectiveTripId = tripId;
      if (tripId == null) {
        _queueTripResolution();
      } else {
        _tripResolutionFuture = null;
      }
    });
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
    return DateTime.now().isBefore(dt.add(const Duration(hours: 12)));
  }

  Timestamp? _messageTimestamp(Map<String, dynamic> data) {
    final ts = data['createdAt'];
    if (ts is Timestamp) return ts;
    final local = data['createdAtLocal'];
    if (local is Timestamp) return local;
    return null;
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
      final profileProvider = context.read<UserProfileProvider>();
      profileProvider.listenToUserProfile(uid!);
      final cachedProfile = profileProvider.getUserProfile(uid!);
      final data =
          cachedProfile ??
          (await db.collection('users').doc(uid).get()).data() ??
          const <String, dynamic>{};
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
    final participantSnapFuture = db
        .collection('tripParticipants')
        .where('userId', isEqualTo: uid)
        .get();
    final ownerSnapFuture = db
        .collection('trips')
        .where('ownerId', isEqualTo: uid)
        .get();

    final participantSnap = await participantSnapFuture;
    final participantTripIds = participantSnap.docs
        .map((p) => p.data()['tripId'] as String?)
        .whereType<String>()
        .where((tripId) => tripId.isNotEmpty && tripId != excludeTripId)
        .toSet()
        .toList();

    for (var i = 0; i < participantTripIds.length; i += 10) {
      final chunk = participantTripIds.sublist(
        i,
        i + 10 > participantTripIds.length ? participantTripIds.length : i + 10,
      );
      final tripSnap = await db
          .collection('trips')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final tripDoc in tripSnap.docs) {
        final data = tripDoc.data();
        if (_isTripActive(data)) {
          candidates.add({'id': tripDoc.id, 'data': data});
        }
      }
    }

    final ownerSnap = await ownerSnapFuture;
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
    _scrollController.dispose();
    super.dispose();
  }

  Widget _noTrip() {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: _chatBackground(
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(r(20), r(16), r(20), r(110)),
            children: [
              _chatHeader(context, subtitle: 'Chat with your trip members'),
              SizedBox(height: r(34)),
              _emptyHero(context),
              SizedBox(height: r(24)),
              Text(
                'No Active Trip Chat',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: r(22),
                ),
              ),
              SizedBox(height: r(8)),
              Text(
                "You don't have any active trip chats right now.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  fontSize: r(13.5),
                ),
              ),
              SizedBox(height: r(34)),
              _benefitsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatBackground({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF06131E), Color(0xFF08111A)]
              : const [Color(0xFFFFFEFC), Color(0xFFF8F5F0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }

  Widget _chatHeader(
    BuildContext context, {
    required String subtitle,
    bool showBack = false,
    int? onlineCount,
  }) {
    final theme = Theme.of(context);
    final r = context.rs;
    return Row(
      children: [
        if (showBack) ...[
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          SizedBox(width: r(2)),
        ],
        Container(
          width: r(48),
          height: r(48),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.brandOrange, AppTheme.brandOrangeLight],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chat_rounded, color: Colors.white),
        ),
        SizedBox(width: r(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip Chat',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: r(21)),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
        if (onlineCount != null) ...[
          Container(
            width: r(9),
            height: r(9),
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: r(8)),
          Text(
            '$onlineCount online',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(width: r(8)),
        ],
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_vert_rounded),
        ),
      ],
    );
  }

  Widget _emptyHero(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      height: r(190),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Icon(
              Icons.send_rounded,
              color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.22 : 0.16),
              size: r(96),
            ),
          ),
          Container(
            width: r(132),
            height: r(132),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.10 : 0.07),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandOrange.withValues(alpha: 0.12),
                  blurRadius: r(36),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: r(76),
                height: r(64),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.brandOrange,
                      AppTheme.brandOrangeLight,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(r(20)),
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: r(42),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitsCard(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    return Container(
      padding: EdgeInsets.all(r(18)),
      decoration: _surfaceDecoration(context, r(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why chat in trips?', style: theme.textTheme.titleMedium),
          SizedBox(height: r(18)),
          _benefitRow(
            context,
            Icons.groups_rounded,
            AppTheme.brandOrange,
            'Connect with trip members',
            'Get to know your fellow travelers',
          ),
          _benefitRow(
            context,
            Icons.mark_chat_read_rounded,
            Colors.green,
            'Share updates & plans',
            'Stay informed and in sync',
          ),
          _benefitRow(
            context,
            Icons.security_rounded,
            Colors.blue,
            'Safe & secure conversations',
            'We keep your chats private',
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    final r = context.rs;
    return Padding(
      padding: EdgeInsets.only(bottom: r(14)),
      child: Row(
        children: [
          Container(
            width: r(46),
            height: r(46),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r(14)),
            ),
            child: Icon(icon, color: color, size: r(22)),
          ),
          SizedBox(width: r(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                SizedBox(height: r(2)),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestedTrip(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String time,
    required String seats,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final r = context.rs;
    return Container(
      margin: EdgeInsets.only(bottom: r(12)),
      padding: EdgeInsets.all(r(14)),
      decoration: _surfaceDecoration(context, r(18)),
      child: Row(
        children: [
          Container(
            width: r(48),
            height: r(48),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r(14)),
            ),
            child: Icon(icon, color: color, size: r(24)),
          ),
          SizedBox(width: r(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                SizedBox(height: r(5)),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: r(13),
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                    ),
                    SizedBox(width: r(5)),
                    Text(time, style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: r(10), vertical: r(6)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r(16)),
            ),
            child: Text(
              seats,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: r(10.5),
              ),
            ),
          ),
          SizedBox(width: r(6)),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
          ),
        ],
      ),
    );
  }

  BoxDecoration _surfaceDecoration(BuildContext context, double radius) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF101B25) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.055),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _activeTripCard(
    BuildContext context,
    Map<String, dynamic> tripData,
    int participantCount,
  ) {
    final theme = Theme.of(context);
    final r = context.rs;
    final from = (tripData['from'] ?? '').toString();
    final to = (tripData['to'] ?? '').toString();
    final meeting = (tripData['meetingPoint'] ?? from).toString();
    final maxPeople = (tripData['maxPeople'] as num?)?.toInt() ?? 4;
    final joined = (tripData['joined'] as num?)?.toInt() ?? participantCount;
    final seatsLeft = (maxPeople - joined).clamp(0, maxPeople);
    final dt = _tripDateTime(tripData);
    final dateText = dt == null
        ? ''
        : '${dt.day} ${DateFormat('MMM').format(dt)}, ${TimeOfDay.fromDateTime(dt).format(context)}';

    return Container(
      padding: EdgeInsets.all(r(14)),
      decoration: _surfaceDecoration(context, r(20)),
      child: Row(
        children: [
          Container(
            width: r(54),
            height: r(54),
            decoration: BoxDecoration(
              color: AppTheme.brandOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r(16)),
            ),
            child: Icon(
              Icons.directions_bus_rounded,
              color: AppTheme.brandOrange,
              size: r(30),
            ),
          ),
          SizedBox(width: r(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$from → $to',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: r(14.5),
                        ),
                      ),
                    ),
                    SizedBox(width: r(8)),
                    Text(
                      'View Trip',
                      style: TextStyle(
                        color: AppTheme.brandOrange,
                        fontWeight: FontWeight.w800,
                        fontSize: r(11.5),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.brandOrange,
                      size: r(18),
                    ),
                  ],
                ),
                SizedBox(height: r(4)),
                Text(
                  meeting.isEmpty ? 'Pickup point' : meeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                  ),
                ),
                SizedBox(height: r(10)),
                Row(
                  children: [
                    if (dateText.isNotEmpty)
                      Expanded(
                        child: _compactMeta(
                          context,
                          Icons.calendar_today_rounded,
                          dateText,
                        ),
                      ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r(9),
                        vertical: r(5),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(r(16)),
                      ),
                      child: _compactMeta(
                        context,
                        Icons.group_outlined,
                        '$seatsLeft seats left',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routePoint(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final r = context.rs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              color: AppTheme.brandOrange,
              size: r(15),
            ),
            SizedBox(width: r(3)),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r(2)),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _compactMeta(
    BuildContext context,
    IconData icon,
    String text, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    final r = context.rs;
    final tint = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.70);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: tint, size: r(15)),
        SizedBox(width: r(5)),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: tint,
            fontWeight: color == null ? null : FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Future<void> send() async {
    if (_effectiveTripId == null || uid == null || !_canChat) {
      return;
    }

    final text = controller.text.trim();
    if (text.isEmpty) return;

    await _ensureMyProfileLoaded();
    final liveProfile =
        context.read<UserProfileProvider>().getUserProfile(uid!) ??
        const <String, dynamic>{};
    final senderName =
        (liveProfile['displayName'] ?? liveProfile['name'] ?? _myName)
            .toString();
    final senderAvatar = normalizeAvatarIndex(
      liveProfile['avatar'] ?? _myAvatar,
    );

    try {
      await db.collection('tripMessages').add({
        'tripId': _effectiveTripId,
        'senderId': uid,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'text': text,
        // Used for immediate local ordering while server timestamp resolves.
        'createdAtLocal': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildMessageItem({
    required Map<String, dynamic> data,
    required bool mine,
    required Color secondary,
  }) {
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final senderId = data['senderId']?.toString() ?? '';
    final profileProvider = context.watch<UserProfileProvider>();
    final profile = profileProvider.getUserProfile(senderId);

    final senderName =
        (profile?['displayName'] ??
                profile?['name'] ??
                data['senderName'] ??
                (mine ? 'You' : 'User'))
            .toString();
    final avatarIndex = normalizeAvatarIndex(
      profile?['avatar'] ?? data['senderAvatar'],
    );

    final timestamp = _messageTimestamp(data);
    final time = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp.toDate())
        : '';

    final bubble = Container(
      margin: EdgeInsets.symmetric(vertical: r(6)),
      padding: EdgeInsets.symmetric(horizontal: r(14), vertical: r(10)),
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.of(context).size.width * (context.isTablet ? 0.5 : 0.68),
      ),
      decoration: BoxDecoration(
        color: mine
            ? secondary.withValues(alpha: isDark ? 0.24 : 0.14)
            : (isDark ? const Color(0xFF171D23) : const Color(0xFFF2F2F3)),
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
              color: mine
                  ? AppTheme.brandOrange
                  : theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          SizedBox(height: r(3)),
          Text(
            (data['text'] ?? '').toString(),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
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

    final messageWidget = Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: mine ? [bubble, avatar] : [avatar, bubble],
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: messageWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) return _noTrip();
    context.read<UserProfileProvider>().listenToUserProfile(uid!);

    final theme = Theme.of(context);
    final secondary = AppTheme.brandOrange;
    final r = context.rs;

    if (_effectiveTripId == null) {
      return FutureBuilder<String?>(
        future: _tripResolutionFuture ??= _resolveFallbackTripId(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final resolvedTripId = snap.data;
          if (resolvedTripId == null) return _noTrip();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _setEffectiveTripId(resolvedTripId);
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
            future: _tripResolutionFuture ??= _resolveFallbackTripId(
              excludeTripId: _effectiveTripId,
            ),
            builder: (context, nextSnap) {
              if (nextSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final nextTripId = nextSnap.data;
              if (nextTripId == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _setEffectiveTripId(null);
                });
                return _noTrip();
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _setEffectiveTripId(nextTripId);
              });

              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          );
        }

        final isOwner = tripData!['ownerId'] == uid;

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

            final profileProvider = context.read<UserProfileProvider>();
            final userIds = <String>{};
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              final pid = data['userId']?.toString();
              if (pid != null && pid.isNotEmpty) userIds.add(pid);
            }
            final ownerId = tripData['ownerId']?.toString() ?? '';
            if (ownerId.isNotEmpty) userIds.add(ownerId);
            for (final id in userIds) {
              profileProvider.listenToUserProfile(id);
            }

            final tripTitle =
                '${tripData['from'] ?? ''} -> ${tripData['to'] ?? ''}';

            final canSend = _canChat;

            return Scaffold(
              body: _chatBackground(
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(r(12), r(10), r(12), r(8)),
                        child: _chatHeader(
                          context,
                          subtitle: tripTitle,
                          showBack: Navigator.canPop(context),
                          onlineCount: docs.length + (isOwner ? 1 : 0),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(r(16), r(4), r(16), r(10)),
                        child: _activeTripCard(context, tripData, docs.length),
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
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snap.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(r(16)),
                                    child: Text(
                                      'Unable to load messages right now.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: r(14),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final rawDocs = snap.data?.docs ?? const [];
                              if (rawDocs.isEmpty) {
                                return Center(
                                  child: Text(
                                    'Start the conversation',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: r(15),
                                    ),
                                  ),
                                );
                              }

                               final messageDocs = [...rawDocs];
                               final profileProvider =
                                   context.read<UserProfileProvider>();
                               for (final doc in messageDocs) {
                                 final data =
                                     doc.data() as Map<String, dynamic>? ??
                                     const <String, dynamic>{};
                                 final senderId =
                                     data['senderId']?.toString() ?? '';
                                 if (senderId.isNotEmpty) {
                                   profileProvider.listenToUserProfile(senderId);
                                 }
                               }
                               messageDocs.sort((a, b) {
                                final ad =
                                    (a.data() as Map<String, dynamic>?) ??
                                    const <String, dynamic>{};
                                final bd =
                                    (b.data() as Map<String, dynamic>?) ??
                                    const <String, dynamic>{};
                                final at = _messageTimestamp(ad)?.toDate();
                                final bt = _messageTimestamp(bd)?.toDate();
                                if (at == null && bt == null) {
                                  return a.id.compareTo(b.id);
                                }
                                if (at == null) return 1;
                                if (bt == null) return -1;
                                final cmp = at.compareTo(bt);
                                if (cmp != 0) return cmp;
                                return a.id.compareTo(b.id);
                              });

                              // Scroll to last message after widget builds
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_scrollController.hasClients) {
                                  _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              });

                              return ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.symmetric(
                                  horizontal: r(16),
                                  vertical: r(12),
                                ),
                                itemCount: messageDocs.length,
                                itemBuilder: (_, i) {
                                  final data =
                                      messageDocs[i].data()
                                          as Map<String, dynamic>;
                                  final mine = data['senderId'] == uid;

                                  return _buildMessageItem(
                                    data: data,
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
                      Padding(
                        padding: EdgeInsets.fromLTRB(r(14), r(8), r(14), r(14)),
                        child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF101820)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(r(30)),
                                border: Border.all(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: theme.brightness == Brightness.dark
                                          ? 0.16
                                          : 0.07,
                                    ),
                                    blurRadius: r(16),
                                    offset: Offset(0, r(7)),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: controller,
                                enabled: canSend,
                                maxLines: null,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => send(),
                                decoration: InputDecoration(
                                  hintText: 'Send a message',
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.52),
                                    fontSize: r(14),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: r(18),
                                    vertical: r(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: r(8)),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.brandOrange,
                                  AppTheme.brandOrangeLight,
                                ],
                              ),
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
                              onPressed: canSend ? send : null,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

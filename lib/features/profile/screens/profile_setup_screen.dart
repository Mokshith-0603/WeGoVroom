import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../../services/push_notification_service.dart';
import '../../auth/screens/landing_screen.dart';
import '../widgets/avatar_utils.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final nameController = TextEditingController();
  final regController = TextEditingController();
  final phoneController = TextEditingController();

  String gender = 'Male';
  int avatarIndex = 0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data == null || !mounted) return;

    setState(() {
      nameController.text = (data['displayName'] ?? '').toString();
      regController.text = (data['register'] ?? '').toString();
      phoneController.text = (data['phone'] ?? '').toString();
      gender = (data['gender'] ?? 'Male').toString();
      avatarIndex = normalizeAvatarIndex(data['avatar']);
    });
  }

  Future<void> completeProfile() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (user == null) return;

    if (nameController.text.isEmpty ||
        regController.text.isEmpty ||
        phoneController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill all fields')));
      return;
    }

    setState(() => loading = true);
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final existingDoc = await userRef.get();

      final payload = <String, dynamic>{
        'email': user.email,
        'displayName': nameController.text.trim(),
        'register': regController.text.trim(),
        'phone': phoneController.text.trim(),
        'gender': gender,
        'avatar': avatarIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!existingDoc.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      await userRef.set(payload, SetOptions(merge: true));

      final profileProvider = context.read<UserProfileProvider>();
      profileProvider.listenToUserProfile(user.uid);
      profileProvider.setCachedUserProfile(user.uid, payload);
      unawaited(_propagateProfileChanges(user.uid));

      try {
        await PushNotificationService.instance
            .syncCurrentUserToken()
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Profile setup token sync skipped: $e');
      }

      auth.refresh();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } on FirebaseException catch (e, st) {
      debugPrint('Complete profile Firebase error: code=${e.code}, message=${e.message}');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message == null || e.message!.trim().isEmpty
                ? 'Failed to complete profile (${e.code}).'
                : 'Failed to complete profile: ${e.message}',
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Complete profile failed: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete profile: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _propagateProfileChanges(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final displayName = nameController.text.trim();
      final avatar = avatarIndex;
      final snapshots = await Future.wait([
        firestore.collection('trips').where('ownerId', isEqualTo: userId).get(),
        firestore
            .collection('tripParticipants')
            .where('userId', isEqualTo: userId)
            .get(),
        firestore.collection('tripRequests').where('userId', isEqualTo: userId).get(),
        firestore.collection('tripMessages').where('senderId', isEqualTo: userId).get(),
      ]);

      final tripDocs = snapshots[0].docs;
      final participantDocs = snapshots[1].docs;
      final requestDocs = snapshots[2].docs;
      final messageDocs = snapshots[3].docs;

      final operations = <({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data})>[
        for (final doc in tripDocs)
          (
            ref: doc.reference,
            data: {'ownerName': displayName, 'ownerAvatar': avatar},
          ),
        for (final doc in participantDocs)
          (ref: doc.reference, data: {'name': displayName, 'avatar': avatar}),
        for (final doc in requestDocs)
          (ref: doc.reference, data: {'name': displayName, 'avatar': avatar}),
        for (final doc in messageDocs)
          (
            ref: doc.reference,
            data: {'senderName': displayName, 'senderAvatar': avatar},
          ),
      ];

      for (var i = 0; i < operations.length; i += 400) {
        final batch = firestore.batch();
        final chunk = operations.skip(i).take(400);
        for (final operation in chunk) {
          batch.update(operation.ref, operation.data);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Failed to propagate profile changes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050B12) : const Color(0xFFFFFCF9),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF07121D), Color(0xFF05080D)]
                : const [Color(0xFFFFFCF9), Color(0xFFFFF4EA)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(r(20), r(10), r(20), r(26)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: theme.colorScheme.onSurface,
                    ),
                    const Spacer(),
                    _dotGrid(context),
                  ],
                ),
                SizedBox(height: r(46)),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Complete Your '),
                      const TextSpan(
                        text: 'Profile',
                        style: TextStyle(color: AppTheme.brandOrange),
                      ),
                    ],
                  ),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                    fontSize: r(29),
                  ),
                ),
                SizedBox(height: r(8)),
                Text(
                  'Tell us a bit more about yourself',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                SizedBox(height: r(28)),
                Container(
                  padding: EdgeInsets.all(r(16)),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.055)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(r(22)),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.20 : 0.055,
                        ),
                      ),
                    ],
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 10,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.82,
                        ),
                    itemBuilder: (_, i) {
                      final selected = avatarIndex == i;

                      return _profileChoice(
                        context,
                        index: i,
                        selected: selected,
                        onTap: () => setState(() => avatarIndex = i),
                      );
                    },
                  ),
                ),
                SizedBox(height: r(20)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: r(16), vertical: r(6)),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.055)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(r(22)),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.20 : 0.055,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _profileField(
                        context,
                        icon: Icons.person_rounded,
                        label: 'Full Name',
                        child: TextField(
                        controller: nameController,
                          decoration: const InputDecoration(
                            hintText: 'Your name',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      _fieldDivider(context),
                      _profileField(
                        context,
                        icon: Icons.badge_outlined,
                        label: 'Register number',
                        child: TextField(
                        controller: regController,
                          decoration: const InputDecoration(
                            hintText: 'Register number',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      _fieldDivider(context),
                      _profileField(
                        context,
                        icon: Icons.groups_rounded,
                        label: 'Gender',
                        child: DropdownButtonFormField(
                        value: gender,
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (v) => setState(() => gender = v.toString()),
                          dropdownColor:
                              isDark ? const Color(0xFF111A24) : Colors.white,
                      ),
                      ),
                      _fieldDivider(context),
                      _profileField(
                        context,
                        icon: Icons.phone_rounded,
                        label: 'Phone number',
                        child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            hintText: 'Phone number',
                            border: InputBorder.none,
                            isDense: true,
                        ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r(24)),
                Container(
                  padding: EdgeInsets.all(r(16)),
                  decoration: BoxDecoration(
                    color: AppTheme.brandOrange.withValues(
                      alpha: isDark ? 0.08 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(r(18)),
                    border: Border.all(
                      color: AppTheme.brandOrange.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: AppTheme.brandOrange,
                        size: 34,
                      ),
                      SizedBox(width: r(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your information is secure with us',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: r(4)),
                            Text(
                              'We never share your data with anyone.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.62,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r(32)),
                SizedBox(
                  width: double.infinity,
                  height: r(58),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r(28)),
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.brandOrange,
                          AppTheme.brandOrangeLight,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandOrange.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(r(28)),
                        onTap: loading ? null : completeProfile,
                        child: Center(
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Complete Setup',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 28),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: r(34)),
                _bottomLandscape(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileChoice(
    BuildContext context, {
    required int index,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final r = context.rs;
    final labels = const [
      'Personal',
      'About Me',
      'Mood',
      'Hobbies',
      'Music',
      'Education',
      'Fitness',
      'Travel',
      'Photos',
      'Interests',
    ];

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              buildAvatar(index, radius: r(23), selected: selected),
              if (selected)
                Container(
                  width: r(14),
                  height: r(14),
                  decoration: const BoxDecoration(
                    color: AppTheme.brandOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: r(10),
                  ),
                ),
            ],
          ),
          SizedBox(height: r(6)),
          Text(
            labels[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? AppTheme.brandOrange
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: r(10),
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: r(48),
            height: r(48),
            decoration: BoxDecoration(
              color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(r(14)),
            ),
            child: Icon(icon, color: AppTheme.brandOrange),
          ),
          SizedBox(width: r(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: r(6)),
                DefaultTextStyle.merge(
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: context.rs(62),
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.11),
    );
  }

  Widget _dotGrid(BuildContext context) {
    final r = context.rs;
    return SizedBox(
      width: r(42),
      height: r(42),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          9,
          (_) => Center(
            child: Container(
              width: r(3.5),
              height: r(3.5),
              decoration: BoxDecoration(
                color: AppTheme.brandOrange.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomLandscape(BuildContext context) {
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: r(190),
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ProfileLandscapePainter(isDark: isDark),
            ),
          ),
          Positioned(
            right: r(44),
            bottom: r(36),
            child: Icon(
              Icons.location_on_rounded,
              color: AppTheme.brandOrange,
              size: r(38),
            ),
          ),
          Positioned(
            right: r(76),
            top: r(28),
            child: Icon(
              isDark ? Icons.nightlight_round : Icons.cloud_rounded,
              color: isDark
                  ? const Color(0xFFFFC46A)
                  : AppTheme.brandOrange.withValues(alpha: 0.18),
              size: r(28),
            ),
          ),
          Positioned(
            left: r(14),
            bottom: r(36),
            child: Icon(
              Icons.park_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
              size: r(48),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLandscapePainter extends CustomPainter {
  final bool isDark;

  const _ProfileLandscapePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark ? const Color(0xFF111A24) : const Color(0xFFFFE9DA);

    final path = Path()
      ..moveTo(0, size.height * 0.58)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.35,
        size.width * 0.55,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.78,
        size.width,
        size.height * 0.52,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);

    final secondPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark ? const Color(0xFF0C141D) : const Color(0xFFFFD8C2);
    final second = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.60,
        size.width * 0.62,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.88,
        size.width,
        size.height * 0.70,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(second, secondPaint);
  }

  @override
  bool shouldRepaint(covariant _ProfileLandscapePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';

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

  (Color, IconData, String) _statusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'merged':
        return (const Color(0xFF18A957), Icons.call_merge_rounded, 'Merged');
      case 'rejected':
      case 'declined':
        return (const Color(0xFFE05252), Icons.close_rounded, 'Declined');
      case 'expired':
        return (const Color(0xFF7A8491), Icons.schedule_rounded, 'Expired');
      default:
        return (AppTheme.brandOrange, Icons.hourglass_top_rounded, 'Pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF050B12)
          : const Color(0xFFFFFCF8),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF07131F), Color(0xFF03070C)]
                : const [Color(0xFFFFFCF8), Color(0xFFFFF7EE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(r(12), r(10), r(18), r(12)),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    SizedBox(width: r(4)),
                    Container(
                      width: r(44),
                      height: r(44),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.brandOrangeLight,
                            AppTheme.brandOrange,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(r(14)),
                      ),
                      child: const Icon(
                        Icons.call_merge_rounded,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: r(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip merge requests',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Combine matching rides safely',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.58,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('tripMergeRequests')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _messageState(
                        context,
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load requests',
                        message: 'Check your connection and try again.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.brandOrange,
                        ),
                      );
                    }

                    final requests = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final ad = a.data()['createdAt'] as Timestamp?;
                        final bd = b.data()['createdAt'] as Timestamp?;
                        return (bd?.millisecondsSinceEpoch ?? 0).compareTo(
                          ad?.millisecondsSinceEpoch ?? 0,
                        );
                      });
                    if (requests.isEmpty) {
                      return _messageState(
                        context,
                        icon: Icons.route_rounded,
                        title: 'No merge requests',
                        message:
                            'Matching trips with the same destination and time will appear here.',
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(r(18), r(10), r(18), r(24)),
                      itemCount: requests.length,
                      separatorBuilder: (_, _) => SizedBox(height: r(14)),
                      itemBuilder: (context, index) => _requestCard(
                        context,
                        request: requests[index],
                        userId: user.uid,
                      ),
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

  Widget _requestCard(
    BuildContext context, {
    required QueryDocumentSnapshot<Map<String, dynamic>> request,
    required String userId,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;
    final data = request.data();
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final style = _statusStyle(status);
    final dateTime = (data['dateTime'] as Timestamp?)?.toDate();
    final destination = (data['destination'] ?? 'Matching trip').toString();
    final tripCount = (data['tripIds'] as List?)?.length ?? 2;

    return Container(
      padding: EdgeInsets.all(r(18)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101B25) : Colors.white,
        borderRadius: BorderRadius.circular(r(24)),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: r(24),
            offset: Offset(0, r(10)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: r(52),
                height: r(52),
                decoration: BoxDecoration(
                  color: AppTheme.brandOrange.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(r(16)),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: AppTheme.brandOrange,
                ),
              ),
              SizedBox(width: r(13)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: r(3)),
                    Text(
                      '$tripCount matching trips',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.58,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r(10),
                  vertical: r(7),
                ),
                decoration: BoxDecoration(
                  color: style.$1.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.$2, color: style.$1, size: r(15)),
                    SizedBox(width: r(5)),
                    Text(
                      style.$3,
                      style: TextStyle(
                        color: style.$1,
                        fontSize: r(11),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dateTime != null) ...[
            SizedBox(height: r(16)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: r(13), vertical: r(11)),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(r(14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.brandOrange,
                    size: 19,
                  ),
                  SizedBox(width: r(9)),
                  Expanded(
                    child: Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(dateTime),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: r(14)),
          Text(
            status == 'pending'
                ? 'Both hosts must accept before the trips are combined.'
                : status == 'merged'
                ? 'The matching trips were successfully combined.'
                : 'This request is no longer active.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              height: 1.4,
            ),
          ),
          if (status == 'pending') ...[
            SizedBox(height: r(16)),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('tripMergeRequests')
                  .doc(request.id)
                  .collection('acceptances')
                  .doc(userId)
                  .snapshots(),
              builder: (context, responseSnapshot) {
                if (responseSnapshot.data?.exists == true) {
                  final accepted =
                      responseSnapshot.data!.data()?['accepted'] == true;
                  final responseColor = accepted
                      ? const Color(0xFF18A957)
                      : const Color(0xFFE05252);
                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(r(13)),
                    decoration: BoxDecoration(
                      color: responseColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(r(14)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          accepted
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: responseColor,
                        ),
                        SizedBox(width: r(9)),
                        Expanded(
                          child: Text(
                            accepted
                                ? 'You accepted this request'
                                : 'You declined this request',
                            style: TextStyle(
                              color: responseColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _respond(context, request.id, false),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(r(50)),
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.16,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r(15)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: r(10)),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _respond(context, request.id, true),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Accept'),
                        style: FilledButton.styleFrom(
                          minimumSize: Size.fromHeight(r(50)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r(15)),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _messageState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;

    return Center(
      child: Container(
        margin: EdgeInsets.all(r(24)),
        padding: EdgeInsets.all(r(24)),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101B25) : Colors.white,
          borderRadius: BorderRadius.circular(r(24)),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r(68),
              height: r(68),
              decoration: BoxDecoration(
                color: AppTheme.brandOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.brandOrange, size: r(34)),
            ),
            SizedBox(height: r(16)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: r(7)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

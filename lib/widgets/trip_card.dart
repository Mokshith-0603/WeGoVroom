import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/trips/screens/trip_detail_screen.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/transport_icons.dart';

class TripCard extends StatelessWidget {
  final String tripId;
  final Map<String, dynamic> data;

  const TripCard({super.key, required this.tripId, required this.data});

  @override
  Widget build(BuildContext context) {
    final joined = (data["joined"] as num?)?.toInt() ?? 1;
    final max = (data["maxPeople"] as num?)?.toInt() ?? 4;
    final seatsLeft = (max - joined).clamp(0, max);
    final isPublic = data["isPublic"] ?? true;
    final ownerId = (data["ownerId"] ?? "").toString();
    if (ownerId.isNotEmpty) {
      context.read<UserProfileProvider>().listenToUserProfile(ownerId);
    }
    final ownerProfile = ownerId.isNotEmpty
        ? context.watch<UserProfileProvider>().getUserProfile(ownerId)
        : null;
    final ownerName =
        (ownerProfile?["displayName"] ??
                ownerProfile?["name"] ??
                data["ownerName"] ??
                "Trip Host")
            .toString();
    final tripIcon = destinationTransportIcon(data["to"]?.toString());

    DateTime? dt;
    try {
      dt = data["dateTime"]?.toDate();
    } catch (_) {}

    final dateText = dt != null ? "${dt.day}/${dt.month}/${dt.year}" : "";
    final timeText = dt != null
        ? TimeOfDay.fromDateTime(dt).format(context)
        : "";
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final completed = data["completed"] == true;
    final isOngoing =
        dt != null &&
        !completed &&
        !now.isBefore(dt) &&
        now.isBefore(dt.add(const Duration(hours: 12)));

    return InkWell(
      borderRadius: BorderRadius.circular(r(24)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(tripId: tripId, data: data),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: r(18)),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101B25) : Colors.white,
          borderRadius: BorderRadius.circular(r(24)),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : const Color(0xFFEAE5DE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.07),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(r(18)),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: r(54),
                        height: r(54),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.brandOrange,
                              AppTheme.brandOrangeLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(r(16)),
                        ),
                        child: Icon(
                          tripIcon,
                          color: Colors.white,
                          size: r(28),
                        ),
                      ),
                      SizedBox(width: r(14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (data["from"] ?? "").toString(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.60),
                              ),
                            ),
                            Text(
                              (data["to"] ?? "").toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: r(24),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r(10),
                          vertical: r(6),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(r(18)),
                        ),
                        child: Text(
                          isOngoing
                              ? "Ongoing"
                              : (isPublic ? "Public trip" : "Private trip"),
                          style: TextStyle(
                            color: isOngoing
                                ? AppTheme.brandOrange
                                : Colors.blue,
                            fontSize: r(11),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r(18)),
                  Row(
                    children: [
                      _meta(
                        context,
                        Icons.calendar_today_rounded,
                        dateText,
                      ),
                      SizedBox(width: r(18)),
                      _meta(context, Icons.schedule_rounded, timeText),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹${data["cost"] ?? 0}",
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF20B653),
                            ),
                          ),
                          Text(
                            "per person",
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: r(16)),
                  Divider(color: scheme.onSurface.withValues(alpha: 0.09)),
                  SizedBox(height: r(10)),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: r(22),
                        backgroundColor: AppTheme.brandOrange.withValues(
                          alpha: 0.13,
                        ),
                        child: Text(
                          _initials(ownerName),
                          style: const TextStyle(
                            color: AppTheme.brandOrange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(width: r(10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ownerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              "Trip Host",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r(12),
                          vertical: r(7),
                        ),
                        decoration: BoxDecoration(
                          color: (seatsLeft == 0 ? Colors.red : Colors.green)
                              .withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(r(18)),
                        ),
                        child: Text(
                          seatsLeft == 0 ? "Full" : "$seatsLeft seats left",
                          style: TextStyle(
                            color: seatsLeft == 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: r(11.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: r(18),
                vertical: r(15),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.brandOrange,
                    AppTheme.brandOrangeLight,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.confirmation_number_outlined,
                      color: Colors.white, size: r(21)),
                  const Spacer(),
                  Text(
                    "JOIN TRIP",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: r(13),
                    ),
                  ),
                  SizedBox(width: r(10)),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: r(22)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String value) {
    final theme = Theme.of(context);
    final r = context.rs;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: r(17),
          color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
        ),
        SizedBox(width: r(6)),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return "?";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return "${parts.first[0]}${parts.last[0]}".toUpperCase();
  }
}

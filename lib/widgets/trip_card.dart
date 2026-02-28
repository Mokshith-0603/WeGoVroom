import 'package:flutter/material.dart';

import '../features/trips/screens/trip_detail_screen.dart';
import '../utils/responsive.dart';

class TripCard extends StatelessWidget {
  final String tripId;
  final Map<String, dynamic> data;

  const TripCard({
    super.key,
    required this.tripId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final joined = data["joined"] ?? 1;
    final max = data["maxPeople"] ?? 4;
    final seatsLeft = (max - joined).clamp(0, max);
    final isPublic = data["isPublic"] ?? true;
    final ownerName = data["ownerName"] ?? "Trip Host";

    DateTime? dt;
    try {
      dt = data["dateTime"]?.toDate();
    } catch (_) {}

    final dateText = dt != null ? "${dt.day}/${dt.month}/${dt.year}" : "";
    final timeText = dt != null ? TimeOfDay.fromDateTime(dt).format(context) : "";

    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    final r = context.rs;

    return InkWell(
      borderRadius: BorderRadius.circular(r(20)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(
              tripId: tripId,
              data: data,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: r(16)),
        padding: EdgeInsets.all(r(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r(20)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: secondary),
                SizedBox(width: r(8)),
                Expanded(
                  child: Text(
                    "${data["from"] ?? ""} -> ${data["to"] ?? ""}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: r(16),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isPublic ? Icons.public : Icons.lock_outline,
                  size: r(18),
                  color: Colors.grey,
                ),
              ],
            ),
            SizedBox(height: r(8)),
            Row(
              children: [
                Icon(Icons.calendar_today, size: r(16), color: Colors.grey[700]),
                SizedBox(width: r(6)),
                Text(dateText),
                SizedBox(width: r(12)),
                Icon(Icons.access_time, size: r(16), color: Colors.grey[700]),
                SizedBox(width: r(4)),
                Text(timeText),
                const Spacer(),
                Icon(Icons.currency_rupee, size: r(16), color: Colors.green[700]),
                Text("${data["cost"] ?? 0}/person"),
              ],
            ),
            SizedBox(height: r(10)),
            Row(
              children: [
                CircleAvatar(
                  radius: r(14),
                  backgroundColor: Colors.grey[200],
                  child: Icon(Icons.person, size: r(14)),
                ),
                SizedBox(width: r(8)),
                Text(
                  ownerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r(10),
                    vertical: r(4),
                  ),
                  decoration: BoxDecoration(
                    color: seatsLeft == 0
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r(20)),
                  ),
                  child: Text(
                    seatsLeft == 0 ? "Full" : "$seatsLeft spots left",
                    style: TextStyle(
                      color: seatsLeft == 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: r(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

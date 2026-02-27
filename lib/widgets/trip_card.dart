import 'package:flutter/material.dart';
import '../features/trips/screens/trip_detail_screen.dart';

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

    /// ⭐ NEW — host name
    final ownerName = data["ownerName"] ?? "Trip Host";

    DateTime? dt;
    try {
      dt = data["dateTime"]?.toDate();
    } catch (_) {}

    final dateText =
        dt != null ? "${dt.day}/${dt.month}/${dt.year}" : "";
    final timeText =
        dt != null ? TimeOfDay.fromDateTime(dt).format(context) : "";

    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ROUTE
            Row(
              children: [
                Icon(Icons.directions_bus, color: secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${data["from"] ?? ""} → ${data["to"] ?? ""}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Icon(
                  isPublic ? Icons.public : Icons.lock_outline,
                  size: 18,
                  color: Colors.grey,
                ),
              ],
            ),

            const SizedBox(height: 8),

            /// DATE + TIME + COST
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(dateText),

                const SizedBox(width: 12),

                Icon(Icons.access_time,
                    size: 16, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text(timeText),

                const Spacer(),

                Icon(Icons.currency_rupee,
                    size: 16, color: Colors.green[700]),
                Text("${data["cost"] ?? 0}/person"),
              ],
            ),

            const SizedBox(height: 10),

            /// HOST + SEATS
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.person, size: 14),
                ),
                const SizedBox(width: 8),

                /// ⭐ HOST NAME SHOWN
                Text(
                  ownerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const Spacer(),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: seatsLeft == 0
                        ? Colors.red.withOpacity(.1)
                        : Colors.green.withOpacity(.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    seatsLeft == 0
                        ? "Full"
                        : "$seatsLeft spots left",
                    style: TextStyle(
                      color: seatsLeft == 0
                          ? Colors.red
                          : Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
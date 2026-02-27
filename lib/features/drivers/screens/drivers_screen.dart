import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class DriversScreen extends StatelessWidget {
  const DriversScreen({super.key});

  Future<void> callDriver(String phone) async {
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget driverCard(Map<String, dynamic> d, BuildContext context) {
    final name = d["name"] ?? "Driver";
    final phone = d["phone"] ?? "";
    final vehicle = d["vehicle"] ?? "";
    final rating = (d["rating"] ?? 4.5).toString();

    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(blurRadius: 10, color: Colors.black12)
        ],
      ),
      child: Row(
        children: [
          /// ⭐ AVATAR
          CircleAvatar(
            radius: 28,
            backgroundColor: secondary,
            child: const Icon(Icons.directions_car, color: Colors.white),
          ),

          const SizedBox(width: 14),

          /// ⭐ INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(vehicle,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star,
                        size: 16, color: secondary),
                    Text(rating)
                  ],
                )
              ],
            ),
          ),

          /// ⭐ CALL BUTTON
          GestureDetector(
            onTap: () => callDriver(phone),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,

      /// ⭐ HEADER
      appBar: AppBar(
        title: Text(
          "Drivers",
          style: theme.textTheme.headlineMedium
              ?.copyWith(color: Colors.black),
        ),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection("drivers").snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No drivers available"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return driverCard(d, context);
            },
          );
        },
      ),
    );
  }
}
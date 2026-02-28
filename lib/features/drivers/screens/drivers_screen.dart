import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/responsive.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> callDriver(String phone) async {
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<bool> _isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db.collection("users").doc(user.uid).get();
    if (!doc.exists) return false;
    final data = doc.data() ?? {};
    return data["role"] == "admin" || data["isAdmin"] == true;
  }

  Future<void> _showAddDriverDialog() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final vehicle = TextEditingController();
    final rating = TextEditingController(text: "4.5");

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Driver"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Phone"),
                ),
                TextField(
                  controller: vehicle,
                  decoration: const InputDecoration(labelText: "Vehicle"),
                ),
                TextField(
                  controller: rating,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Rating"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () async {
                final driverName = name.text.trim();
                final driverPhone = phone.text.trim();
                final driverVehicle = vehicle.text.trim();
                final driverRating = double.tryParse(rating.text.trim()) ?? 4.5;

                if (driverName.isEmpty || driverPhone.isEmpty || driverVehicle.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text("Please fill all required fields")),
                  );
                  return;
                }

                try {
                  await _db.collection("drivers").add({
                    "name": driverName,
                    "phone": driverPhone,
                    "vehicle": driverVehicle,
                    "rating": driverRating,
                    "createdAt": FieldValue.serverTimestamp(),
                    "createdBy": _auth.currentUser?.uid,
                  });
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text("Failed to add driver: $e")),
                  );
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Widget driverCard(Map<String, dynamic> d, BuildContext context) {
    final name = d["name"] ?? "Driver";
    final phone = d["phone"] ?? "";
    final vehicle = d["vehicle"] ?? "";
    final rating = (d["rating"] ?? 4.5).toString();

    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    final r = context.rs;

    return Container(
      margin: EdgeInsets.only(bottom: r(14)),
      padding: EdgeInsets.all(r(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r(18)),
        boxShadow: const [
          BoxShadow(blurRadius: 10, color: Colors.black12)
        ],
      ),
      child: Row(
        children: [
          /// ⭐ AVATAR
          CircleAvatar(
            radius: r(28),
            backgroundColor: secondary,
            child: const Icon(Icons.directions_car, color: Colors.white),
          ),

          SizedBox(width: r(14)),

          /// ⭐ INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: r(16)),
                ),
                Text(vehicle,
                    style: const TextStyle(color: Colors.grey)),
                SizedBox(height: r(4)),
                Row(
                  children: [
                    Icon(Icons.star,
                        size: r(16), color: secondary),
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
              padding: EdgeInsets.all(r(10)),
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
    final r = context.rs;

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
            padding: EdgeInsets.all(r(16)),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return driverCard(d, context);
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _isAdmin(),
        builder: (context, snap) {
          if (snap.data != true) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _showAddDriverDialog,
            icon: const Icon(Icons.add),
            label: const Text("Add Driver"),
          );
        },
      ),
    );
  }
}

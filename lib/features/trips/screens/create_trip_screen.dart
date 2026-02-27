import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final fromController = TextEditingController();
  final meetingController = TextEditingController();
  final costController = TextEditingController();
  final descController = TextEditingController();
  final customDestinationController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  String selectedDestination = "Bus Stand";
  int maxPeople = 4;
  bool isPublic = true;
  bool loading = false;

  final db = FirebaseFirestore.instance;

  final List<String> hotspots = [
    "Bus Stand",
    "Railway Station",
    "Airport",
    "City Center",
    "Shopping Mall",
    "Hospital",
    "Other"
  ];

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (d != null) setState(() => selectedDate = d);
  }

  Future<void> pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null) setState(() => selectedTime = t);
  }

  /// ⭐ CHECK ACTIVE TRIP (IGNORE HISTORY)
  Future<bool> hasActiveTrip(String uid) async {
    final now = DateTime.now();

    // check owned trips in addition to participant records
    final ownSnap = await db
        .collection("trips")
        .where("ownerId", isEqualTo: uid)
        .get();
    for (final t in ownSnap.docs) {
      final dt = t.data()["dateTime"]?.toDate();
      if (dt != null && dt.isAfter(now)) return true;
    }

    final parts = await db
        .collection("tripParticipants")
        .where("userId", isEqualTo: uid)
        .get();

    for (final p in parts.docs) {
      final tripId = p["tripId"];
      final tripDoc = await db.collection("trips").doc(tripId).get();

      if (!tripDoc.exists) {
        await p.reference.delete(); // cleanup orphan
        continue;
      }

      final data = tripDoc.data()!;
      final ts = data["dateTime"];

      if (ts == null) continue;

      DateTime dt;
      try {
        dt = ts.toDate();
      } catch (_) {
        continue;
      }

      if (dt.isAfter(now)) {
        return true; // active future trip exists
      }
    }

    return false;
  }

  /// ⭐ FINAL CREATE TRIP
  Future<void> createTrip() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final destination = selectedDestination == "Other"
        ? customDestinationController.text.trim()
        : selectedDestination;

    if (fromController.text.isEmpty ||
        destination.isEmpty ||
        selectedDate == null ||
        selectedTime == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Fill required fields")));
      return;
    }

    setState(() => loading = true);

    try {
      /// ⭐ ACTIVE CHECK
      final active = await hasActiveTrip(user.uid);

      if (active) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You already have an active trip")));
        return;
      }

      /// ⭐ USER SNAPSHOT
      final userDoc = await db.collection("users").doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final name =
          userData["displayName"] ?? userData["name"] ?? "Host";
      final avatar = userData["avatar"] ?? 0;

      final dateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      /// ⭐ CREATE TRIP
      final tripRef = await db.collection("trips").add({
        "ownerId": user.uid,
        "ownerName": name,
        "ownerAvatar": avatar,
        "from": fromController.text.trim(),
        "to": destination,
        "meetingPoint": meetingController.text.trim(),
        "cost": int.tryParse(costController.text) ?? 0,
        "maxPeople": maxPeople,
        "joined": 1,
        "description": descController.text.trim(),
        "isPublic": isPublic,
        "dateTime": dateTime,
        "createdAt": FieldValue.serverTimestamp(),
      });

      /// ⭐ HOST PARTICIPANT SNAPSHOT
      await db.collection("tripParticipants").add({
        "tripId": tripRef.id,
        "userId": user.uid,
        "name": name,
        "avatar": avatar,
        "isHost": true,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Widget section(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xffff7a00)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOther = selectedDestination == "Other";

    return Scaffold(
      appBar: AppBar(title: const Text("Create Trip")),
      backgroundColor: const Color(0xfff7f7f7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            section(
              "Route",
              Icons.place_outlined,
              Column(
                children: [
                  TextField(
                    controller: fromController,
                    decoration:
                        const InputDecoration(labelText: "Departure point"),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedDestination,
                    items: hotspots
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => selectedDestination = v!),
                    decoration:
                        const InputDecoration(labelText: "Destination"),
                  ),
                  if (isOther)
                    TextField(
                      controller: customDestinationController,
                      decoration:
                          const InputDecoration(labelText: "Enter destination"),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: meetingController,
                    decoration:
                        const InputDecoration(labelText: "Meeting point"),
                  ),
                ],
              ),
            ),
            section(
              "When",
              Icons.calendar_today_outlined,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: pickDate,
                      child: Text(selectedDate == null
                          ? "Select date"
                          : selectedDate.toString().split(" ")[0]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: pickTime,
                      child: Text(selectedTime == null
                          ? "Select time"
                          : selectedTime!.format(context)),
                    ),
                  ),
                ],
              ),
            ),
            section(
              "Details",
              Icons.people_outline,
              Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: maxPeople,
                    items: [2, 3, 4, 5, 6]
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text("$e people")))
                        .toList(),
                    onChanged: (v) => setState(() => maxPeople = v!),
                    decoration:
                        const InputDecoration(labelText: "Max people"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: "Cost per person"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: "Description"),
                  ),
                ],
              ),
            ),
            section(
              "Visibility",
              Icons.visibility_outlined,
              SwitchListTile(
                value: isPublic,
                onChanged: (v) => setState(() => isPublic = v),
                title: const Text("Public trip"),
                subtitle: const Text("Anyone can join instantly"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffff7a00),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: loading ? null : createTrip,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Create Trip 🚀",
                        style: TextStyle(
                          color: Color(0xff1a1a1a),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
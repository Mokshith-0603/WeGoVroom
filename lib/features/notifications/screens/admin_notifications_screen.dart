import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _messageController = TextEditingController();

  String? _selectedUserId;
  bool _sendToAll = false;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendNotifications() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message is required")),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final usersSnap = await _db.collection("users").get();
      final docs = usersSnap.docs;
      if (docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No users found")),
        );
        setState(() => _sending = false);
        return;
      }

      final targetUserIds = _sendToAll
          ? docs.map((d) => d.id).toList()
          : (_selectedUserId == null ? <String>[] : <String>[_selectedUserId!]);

      if (targetUserIds.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select a user or choose Send to all")),
        );
        setState(() => _sending = false);
        return;
      }

      final batch = _db.batch();
      for (final userId in targetUserIds) {
        final ref = _db.collection("notifications").doc();
        batch.set(ref, {
          "userId": userId,
          "message": message,
          "createdAt": FieldValue.serverTimestamp(),
          "createdBy": _auth.currentUser?.uid,
        });
      }
      await batch.commit();

      _messageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _sendToAll
                ? "Notification sent to all users"
                : "Notification sent",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send notification: $e")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection("users").snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? const [];
          final labels = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data["displayName"] ?? "User").toString();
            final email = (data["email"] ?? "").toString();
            return email.isEmpty ? name : "$name ($email)";
          }).toList();

          final items = docs.asMap().entries.map((entry) {
            final index = entry.key;
            final doc = entry.value;
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(
                labels[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList();

          if (_selectedUserId != null &&
              !docs.any((d) => d.id == _selectedUserId)) {
            _selectedUserId = null;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: _sendToAll,
                  onChanged: (v) => setState(() => _sendToAll = v),
                  title: const Text("Send to all users"),
                ),
                if (!_sendToAll)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedUserId,
                    isExpanded: true,
                    items: items,
                    selectedItemBuilder: (context) {
                      return labels
                          .map(
                            (label) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList();
                    },
                    onChanged: (v) => setState(() => _selectedUserId = v),
                    decoration: const InputDecoration(
                      labelText: "Select user",
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Message",
                    hintText: "Type notification message",
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _sending ? null : _sendNotifications,
                    child: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Send Notification"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

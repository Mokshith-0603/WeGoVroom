import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/transport_icons.dart';
import '../../../utils/responsive.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isAdminUser = false;
  bool _adminLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final isAdmin = await _isAdmin();
    if (!mounted) return;
    setState(() {
      _isAdminUser = isAdmin;
      _adminLoaded = true;
    });
  }

  Future<void> callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<bool> _isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1' || normalized == 'yes';
      }
      return false;
    }

    String normalizedRole(dynamic value) {
      return value?.toString().trim().toLowerCase() ?? '';
    }

    try {
      final token = await user.getIdTokenResult(true);
      final claims = token.claims ?? const <String, dynamic>{};
      if (parseBool(claims['admin']) ||
          parseBool(claims['isAdmin']) ||
          normalizedRole(claims['role']) == 'admin') {
        return true;
      }
    } catch (_) {}

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;
    final data = doc.data() ?? {};
    return normalizedRole(data['role']) == 'admin' ||
        parseBool(data['isAdmin']) ||
        parseBool(data['admin']);
  }

  Future<void> _showAddDriverDialog() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final vehicle = TextEditingController();
    final rating = TextEditingController(text: '4.5');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Driver'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                TextField(
                  controller: vehicle,
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                ),
                TextField(
                  controller: rating,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rating'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final driverName = name.text.trim();
                final driverPhone = phone.text.trim();
                final driverVehicle = vehicle.text.trim();
                final driverRating = double.tryParse(rating.text.trim()) ?? 4.5;

                if (driverName.isEmpty || driverPhone.isEmpty || driverVehicle.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                try {
                  await _db.collection('drivers').add({
                    'name': driverName,
                    'phone': driverPhone,
                    'vehicle': driverVehicle,
                    'rating': driverRating,
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': _auth.currentUser?.uid,
                  });
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Failed to add driver: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDriverDialog(String driverId, Map<String, dynamic> driverData) async {
    final name = TextEditingController(text: (driverData['name'] ?? '').toString());
    final phone = TextEditingController(text: (driverData['phone'] ?? '').toString());
    final vehicle = TextEditingController(text: (driverData['vehicle'] ?? '').toString());
    final rating = TextEditingController(text: (driverData['rating'] ?? 4.5).toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Driver'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                TextField(
                  controller: vehicle,
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                ),
                TextField(
                  controller: rating,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rating'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final driverName = name.text.trim();
                final driverPhone = phone.text.trim();
                final driverVehicle = vehicle.text.trim();
                final driverRating = double.tryParse(rating.text.trim()) ?? 4.5;

                if (driverName.isEmpty || driverPhone.isEmpty || driverVehicle.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                try {
                  await _db.collection('drivers').doc(driverId).update({
                    'name': driverName,
                    'phone': driverPhone,
                    'vehicle': driverVehicle,
                    'rating': driverRating,
                    'updatedAt': FieldValue.serverTimestamp(),
                    'updatedBy': _auth.currentUser?.uid,
                  });
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Failed to update driver: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDriver(String driverId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Driver'),
          content: const Text('Are you sure you want to delete this driver?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _db.collection('drivers').doc(driverId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete driver: $e')),
      );
    }
  }

  Widget _driverCard(String driverId, Map<String, dynamic> d, BuildContext context) {
    final name = d['name'] ?? 'Driver';
    final phone = d['phone'] ?? '';
    final vehicle = d['vehicle'] ?? '';
    final rating = (d['rating'] ?? 4.5).toString();
    final vehicleIcon = vehicleTransportIcon(vehicle.toString());

    final secondary = Theme.of(context).colorScheme.secondary;
    final r = context.rs;

    return Container(
      margin: EdgeInsets.only(bottom: r(14)),
      padding: EdgeInsets.all(r(16)),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(r(18)),
        border: Border.all(color: secondary.withOpacity(0.35)),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: r(28),
            backgroundColor: secondary,
            child: Icon(vehicleIcon, color: Colors.black),
          ),
          SizedBox(width: r(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: r(16), color: Colors.white),
                ),
                Text(vehicle, style: const TextStyle(color: Colors.white70)),
                SizedBox(height: r(4)),
                Text('Phone: $phone', style: const TextStyle(color: Colors.white70)),
                SizedBox(height: r(4)),
                Row(
                  children: [
                    Icon(Icons.star, size: r(16), color: secondary),
                    Text(' $rating', style: TextStyle(color: secondary)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (phone.toString().trim().isNotEmpty)
                GestureDetector(
                  onTap: () => callDriver(phone),
                  child: Container(
                    padding: EdgeInsets.all(r(10)),
                    decoration: BoxDecoration(color: secondary, shape: BoxShape.circle),
                    child: const Icon(Icons.call, color: Colors.black),
                  ),
                ),
              if (_isAdminUser) ...[
                SizedBox(height: r(8)),
                IconButton(
                  tooltip: 'Edit Driver',
                  onPressed: () => _showEditDriverDialog(driverId, d),
                  icon: Icon(Icons.edit_outlined, color: secondary),
                ),
                IconButton(
                  tooltip: 'Delete Driver',
                  onPressed: () => _deleteDriver(driverId),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade300,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final r = context.rs;
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('drivers').snapshots(),
      builder: (_, snap) {
        if (!_adminLoaded || !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No drivers available'));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r(16), r(12), r(16), r(8)),
              child: Text(
                'Best drivers who take you at the best price.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(r(16)),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final d = doc.data() as Map<String, dynamic>;
                  return _driverCard(doc.id, d, context);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Drivers',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: secondary),
      ),
      body: _buildBody(context),
      floatingActionButton: !_adminLoaded || !_isAdminUser
          ? null
          : FloatingActionButton.extended(
              backgroundColor: secondary,
              foregroundColor: Colors.black,
              onPressed: _showAddDriverDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Driver'),
            ),
    );
  }
}

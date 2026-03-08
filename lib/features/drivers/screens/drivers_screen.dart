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
  Future<String>? _reviewerNameFuture;

  Timestamp? _reviewTimestamp(Map<String, dynamic> data) {
    final updated = data['updatedAt'];
    if (updated is Timestamp) return updated;
    final created = data['createdAt'];
    if (created is Timestamp) return created;
    return null;
  }

  Future<String> _currentReviewerName() async {
    if (_reviewerNameFuture != null) {
      return _reviewerNameFuture!;
    }
    _reviewerNameFuture = _loadCurrentReviewerName();
    return _reviewerNameFuture!;
  }

  Future<String> _loadCurrentReviewerName() async {
    final user = _auth.currentUser;
    if (user == null) return 'User';
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? const <String, dynamic>{};
      final name = (data['displayName'] ?? data['name'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return user.email?.split('@').first ?? 'User';
  }

  Future<void> _openDriverReviewsBottomSheet({
    required String driverId,
    required String driverName,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('driverReviews')
                  .where('driverId', isEqualTo: driverId)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Unable to load reviews right now.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final rawDocs = List<QueryDocumentSnapshot>.from(
                  snap.data?.docs ?? const [],
                );

                final docs = [...rawDocs];
                docs.sort((a, b) {
                  final ad = _reviewTimestamp(
                    a.data() as Map<String, dynamic>,
                  )?.toDate();
                  final bd = _reviewTimestamp(
                    b.data() as Map<String, dynamic>,
                  )?.toDate();
                  if (ad == null && bd == null) {
                    return b.id.compareTo(a.id);
                  }
                  if (ad == null) return 1;
                  if (bd == null) return -1;
                  // Newest first.
                  final cmp = bd.compareTo(ad);
                  if (cmp != 0) return cmp;
                  return b.id.compareTo(a.id);
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(
                        '$driverName Reviews',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: docs.isEmpty
                          ? const Center(child: Text('No reviews yet'))
                          : ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (_, i) {
                                final data =
                                    docs[i].data() as Map<String, dynamic>;
                                final reviewerName =
                                    (data['reviewerName'] ?? '')
                                        .toString()
                                        .trim();
                                final rating = ((data['rating'] ?? 0) as num)
                                    .toDouble();
                                final comment = (data['comment'] ?? '')
                                    .toString();
                                return ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(
                                    '${reviewerName.isNotEmpty ? reviewerName : 'User'} - ${rating.toStringAsFixed(1)}/5',
                                  ),
                                  subtitle: comment.trim().isEmpty
                                      ? const Text('No comment')
                                      : Text(comment),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDriverReviewDialog({
    required String driverId,
    required String driverName,
    double? initialRating,
    String? initialComment,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final commentController = TextEditingController(text: initialComment ?? '');
    double rating = (initialRating ?? 5).clamp(1, 5).toDouble();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Rate $driverName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rating: ${rating.toStringAsFixed(1)}/5'),
                  Slider(
                    value: rating,
                    min: 1,
                    max: 5,
                    divisions: 8,
                    label: rating.toStringAsFixed(1),
                    onChanged: (v) => setDialogState(() => rating = v),
                  ),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Write your review (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final reviewerName = await _currentReviewerName();
                      final reviewId = '${driverId}_$uid';
                      await _db.collection('driverReviews').doc(reviewId).set({
                        'driverId': driverId,
                        'userId': uid,
                        'reviewerName': reviewerName,
                        'rating': rating,
                        'comment': commentController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Review saved')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Failed to save review: $e')),
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
    } catch (_) {
      // Fallback to user document if token claims are unavailable.
    }

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
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Rating'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final driverName = name.text.trim();
                final driverPhone = phone.text.trim();
                final driverVehicle = vehicle.text.trim();
                final driverRating = double.tryParse(rating.text.trim()) ?? 4.5;

                if (driverName.isEmpty ||
                    driverPhone.isEmpty ||
                    driverVehicle.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                    ),
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

  Future<void> _showEditDriverDialog(
    String driverId,
    Map<String, dynamic> driverData,
  ) async {
    final name = TextEditingController(
      text: (driverData['name'] ?? '').toString(),
    );
    final phone = TextEditingController(
      text: (driverData['phone'] ?? '').toString(),
    );
    final vehicle = TextEditingController(
      text: (driverData['vehicle'] ?? '').toString(),
    );
    final rating = TextEditingController(
      text: (driverData['rating'] ?? 4.5).toString(),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Driver'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Rating'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final driverName = name.text.trim();
                final driverPhone = phone.text.trim();
                final driverVehicle = vehicle.text.trim();
                final driverRating = double.tryParse(rating.text.trim()) ?? 4.5;

                if (driverName.isEmpty ||
                    driverPhone.isEmpty ||
                    driverVehicle.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                    ),
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _db.collection('drivers').doc(driverId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Driver deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete driver: $e')));
    }
  }

  Widget _driverCard(
    String driverId,
    Map<String, dynamic> d,
    _DriverReviewSummary reviewSummary,
    BuildContext context,
  ) {
    final name = d['name'] ?? 'Driver';
    final phone = d['phone'] ?? '';
    final vehicle = d['vehicle'] ?? '';
    final fallbackRating = ((d['rating'] ?? 4.5) as num).toDouble();
    final vehicleIcon = vehicleTransportIcon(vehicle.toString());
    final uid = _auth.currentUser?.uid;

    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    final r = context.rs;

    return Container(
      margin: EdgeInsets.only(bottom: r(14)),
      padding: EdgeInsets.all(r(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r(18)),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: r(28),
            backgroundColor: secondary,
            child: Icon(vehicleIcon, color: Colors.white),
          ),
          SizedBox(width: r(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: r(16),
                  ),
                ),
                Text(vehicle, style: const TextStyle(color: Colors.grey)),
                SizedBox(height: r(4)),
                Text(
                  'Phone: $phone',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: r(4)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, size: r(16), color: secondary),
                        Text(
                          '${reviewSummary.averageOr(fallbackRating).toStringAsFixed(1)} (${reviewSummary.count} reviews)',
                        ),
                      ],
                    ),
                    SizedBox(height: r(6)),
                    TextButton.icon(
                      onPressed: () => _openDriverReviewsBottomSheet(
                        driverId: driverId,
                        driverName: name.toString(),
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View Reviews'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(0, r(28)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: uid == null
                          ? null
                          : () => _openDriverReviewDialog(
                              driverId: driverId,
                              driverName: name.toString(),
                              initialRating: reviewSummary.myRating,
                              initialComment: reviewSummary.myComment,
                            ),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: Text(
                        reviewSummary.myRating == null
                            ? 'Rate/Review'
                            : 'Edit Review',
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(0, r(28)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
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
                    decoration: BoxDecoration(
                      color: secondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call, color: Colors.white),
                  ),
                ),
              if (_isAdminUser) ...[
                SizedBox(height: r(8)),
                IconButton(
                  tooltip: 'Edit Driver',
                  onPressed: () => _showEditDriverDialog(driverId, d),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete Driver',
                  onPressed: () => _deleteDriver(driverId),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade600,
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
      builder: (_, driversSnap) {
        if (!_adminLoaded || !driversSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = driversSnap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No drivers available'));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _db.collection('driverReviews').snapshots(),
          builder: (_, reviewsSnap) {
            final summaries = _buildReviewSummaries(
              reviewsSnap.data?.docs ?? const [],
              _auth.currentUser?.uid,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(r(16), r(12), r(16), r(8)),
                  child: Text(
                    'Best drivers who take you at the best price.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(r(16)),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data() as Map<String, dynamic>;
                      return _driverCard(
                        doc.id,
                        d,
                        summaries[doc.id] ?? const _DriverReviewSummary(),
                        context,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, _DriverReviewSummary> _buildReviewSummaries(
    List<QueryDocumentSnapshot> docs,
    String? currentUserId,
  ) {
    final summaries = <String, _DriverReviewSummaryAccumulator>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final driverId = (data['driverId'] ?? '').toString();
      if (driverId.isEmpty) continue;

      final summary = summaries.putIfAbsent(
        driverId,
        _DriverReviewSummaryAccumulator.new,
      );
      final rating = ((data['rating'] ?? 0) as num).toDouble();
      summary.total += rating;
      summary.count += 1;
      if (currentUserId != null && data['userId'] == currentUserId) {
        summary.myRating = rating;
        summary.myComment = (data['comment'] ?? '').toString();
      }
    }

    return summaries.map(
      (key, value) => MapEntry(
        key,
        _DriverReviewSummary(
          count: value.count,
          average: value.count == 0 ? null : value.total / value.count,
          myRating: value.myRating,
          myComment: value.myComment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Drivers',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.black,
              ),
            ),
            SizedBox(width: context.rs(8)),
            Icon(
              Icons.directions_car_outlined,
              color: Colors.black,
              size: context.rs(22),
            ),
          ],
        ),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _buildBody(context),
      floatingActionButton: !_adminLoaded || !_isAdminUser
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddDriverDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Driver'),
            ),
    );
  }
}

class _DriverReviewSummaryAccumulator {
  double total = 0;
  int count = 0;
  double? myRating;
  String myComment = '';
}

class _DriverReviewSummary {
  final int count;
  final double? average;
  final double? myRating;
  final String myComment;

  const _DriverReviewSummary({
    this.count = 0,
    this.average,
    this.myRating,
    this.myComment = '',
  });

  double averageOr(double fallback) => average ?? fallback;
}

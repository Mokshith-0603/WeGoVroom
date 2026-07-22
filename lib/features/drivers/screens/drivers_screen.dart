import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/transport_icons.dart';
import '../../../utils/responsive.dart';
import '../../../theme/app_theme.dart';

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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final r = sheetContext.rs;
        final isDark = theme.brightness == Brightness.dark;

        return SafeArea(
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * 0.74,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF07111B) : const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(r(28))),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
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

                final docs = List<QueryDocumentSnapshot>.from(
                  snap.data?.docs ?? const [],
                );
                docs.sort((a, b) {
                  final ad = _reviewTimestamp(
                    a.data() as Map<String, dynamic>,
                  )?.toDate();
                  final bd = _reviewTimestamp(
                    b.data() as Map<String, dynamic>,
                  )?.toDate();
                  if (ad == null && bd == null) return b.id.compareTo(a.id);
                  if (ad == null) return 1;
                  if (bd == null) return -1;
                  final cmp = bd.compareTo(ad);
                  if (cmp != 0) return cmp;
                  return b.id.compareTo(a.id);
                });

                final ratings = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ((data['rating'] ?? 0) as num).toDouble();
                }).where((rating) => rating > 0).toList();
                final average = ratings.isEmpty
                    ? 0.0
                    : ratings.reduce((a, b) => a + b) / ratings.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(r(18), r(12), r(18), r(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: r(42),
                              height: r(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          SizedBox(height: r(18)),
                          Row(
                            children: [
                              Container(
                                width: r(52),
                                height: r(52),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.brandOrangeLight,
                                      AppTheme.brandOrange,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(r(16)),
                                ),
                                child: const Icon(
                                  Icons.rate_review_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: r(14)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$driverName Reviews',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: r(3)),
                                    Text(
                                      docs.isEmpty
                                          ? 'No reviews yet'
                                          : '${average.toStringAsFixed(1)}/5 from ${docs.length} review${docs.length == 1 ? '' : 's'}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: docs.isEmpty
                          ? _emptyDriverReviews(sheetContext)
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(r(18), 0, r(18), r(20)),
                              itemCount: docs.length,
                              itemBuilder: (_, i) {
                                final data = docs[i].data() as Map<String, dynamic>;
                                return _driverReviewCard(sheetContext, data);
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

  Widget _emptyDriverReviews(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    return Center(
      child: Container(
        margin: EdgeInsets.all(r(22)),
        padding: EdgeInsets.all(r(22)),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF101A24)
              : Colors.white,
          borderRadius: BorderRadius.circular(r(22)),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.reviews_rounded,
              color: AppTheme.brandOrange,
              size: r(38),
            ),
            SizedBox(height: r(10)),
            Text(
              'No reviews yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverReviewCard(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    final reviewerName = (data['reviewerName'] ?? '').toString().trim();
    final rating = ((data['rating'] ?? 0) as num).toDouble();
    final comment = (data['comment'] ?? '').toString().trim();

    return Container(
      margin: EdgeInsets.only(bottom: r(12)),
      padding: EdgeInsets.all(r(14)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101A24) : Colors.white,
        borderRadius: BorderRadius.circular(r(20)),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.045),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: r(22),
            backgroundColor: AppTheme.brandOrange.withValues(alpha: 0.14),
            child: Icon(
              Icons.person_rounded,
              color: AppTheme.brandOrange,
              size: r(22),
            ),
          ),
          SizedBox(width: r(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reviewerName.isNotEmpty ? reviewerName : 'User',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r(8),
                        vertical: r(4),
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: AppTheme.brandOrange,
                            size: r(15),
                          ),
                          SizedBox(width: r(3)),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: AppTheme.brandOrange,
                              fontSize: r(12),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r(7)),
                Text(
                  comment.isEmpty ? 'No comment' : comment,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    final average = reviewSummary.averageOr(fallbackRating);
    final countLabel = reviewSummary.count == 1 ? 'review' : 'reviews';
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.64);

    return Container(
      margin: EdgeInsets.fromLTRB(r(20), 0, r(20), r(18)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101A24) : Colors.white,
        borderRadius: BorderRadius.circular(r(24)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFEAE5DE),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.07),
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r(24)),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(r(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: r(82),
                        height: r(82),
                        decoration: BoxDecoration(
                          color: AppTheme.brandOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(r(22)),
                        ),
                        child: Icon(
                          vehicleIcon,
                          color: AppTheme.brandOrange,
                          size: r(36),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r(8),
                          vertical: r(4),
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.brandOrange,
                              AppTheme.brandOrangeLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: r(12),
                            ),
                            SizedBox(width: r(2)),
                            Text(
                              average.toStringAsFixed(1),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: r(11),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: r(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toString(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                        SizedBox(height: r(5)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: r(8),
                            vertical: r(4),
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brandOrange.withValues(
                              alpha: isDark ? 0.16 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            vehicle.toString().isEmpty
                                ? 'Auto'
                                : vehicle.toString(),
                            style: TextStyle(
                              color: AppTheme.brandOrange,
                              fontWeight: FontWeight.w800,
                              fontSize: r(12),
                            ),
                          ),
                        ),
                        SizedBox(height: r(10)),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              color: AppTheme.brandOrange,
                              size: r(16),
                            ),
                            SizedBox(width: r(7)),
                            Expanded(
                              child: Text(
                                phone.toString(),
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: r(10)),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: AppTheme.brandOrange,
                              size: r(17),
                            ),
                            SizedBox(width: r(6)),
                            Flexible(
                              child: Text(
                                '${average.toStringAsFixed(1)} (${reviewSummary.count} $countLabel)',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (phone.toString().trim().isNotEmpty)
                    GestureDetector(
                      onTap: () => callDriver(phone),
                      child: Container(
                        width: r(58),
                        height: r(58),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.brandOrangeLight,
                              AppTheme.brandOrange,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.brandOrange.withValues(
                                alpha: isDark ? 0.34 : 0.25,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.call_rounded,
                          color: Colors.white,
                          size: r(25),
                        ),
                      ),
                    ),
                  if (_isAdminUser)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDriverDialog(driverId, d);
                        } else if (value == 'delete') {
                          _deleteDriver(driverId);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            Container(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.025)
                  : const Color(0xFFFFFBF7),
              padding: EdgeInsets.symmetric(horizontal: r(14), vertical: r(8)),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _openDriverReviewsBottomSheet(
                        driverId: driverId,
                        driverName: name.toString(),
                      ),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('View Reviews'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.brandOrange,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: uid == null
                          ? null
                          : () => _openDriverReviewDialog(
                                driverId: driverId,
                                driverName: name.toString(),
                                initialRating: reviewSummary.myRating,
                                initialComment: reviewSummary.myComment,
                              ),
                      icon: const Icon(Icons.edit_square),
                      label: Text(
                        reviewSummary.myRating == null
                            ? 'Rate/Review'
                            : 'Edit Review',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.brandOrange,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

            return ListView.builder(
              padding: EdgeInsets.only(bottom: r(26)),
              itemCount: docs.length + 1,
              itemBuilder: (_, i) {
                if (i == docs.length) return _safetyCard(context);
                final doc = docs[i];
                final d = doc.data() as Map<String, dynamic>;
                return _driverCard(
                  doc.id,
                  d,
                  summaries[doc.id] ?? const _DriverReviewSummary(),
                  context,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _driversHero(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(r(20), r(8), r(20), r(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            color: theme.colorScheme.onSurface,
          ),
          SizedBox(height: r(8)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Drivers',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        SizedBox(width: r(10)),
                        Icon(
                          Icons.directions_car_filled_rounded,
                          color: AppTheme.brandOrange,
                          size: r(23),
                        ),
                      ],
                    ),
                    SizedBox(height: r(18)),
                    Text(
                      'Best drivers who take you\nat the best price.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: r(132),
                height: r(88),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r(24)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF142334),
                            const Color(0xFF07111B),
                          ]
                        : [
                            const Color(0xFFFFF1E4),
                            const Color(0xFFFFFBF7),
                          ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: r(12),
                      top: r(12),
                      child: Icon(
                        Icons.location_city_rounded,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: isDark ? 0.12 : 0.08,
                        ),
                        size: r(58),
                      ),
                    ),
                    Positioned(
                      left: r(18),
                      bottom: r(18),
                      child: Container(
                        width: r(54),
                        height: r(34),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.brandOrangeLight,
                              AppTheme.brandOrange,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(r(18)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.brandOrange.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_taxi_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r(24)),
          _verifiedBanner(context),
        ],
      ),
    );
  }

  Widget _verifiedBanner(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(r(16)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101A24) : const Color(0xFFFFF1E6),
        borderRadius: BorderRadius.circular(r(20)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.brandOrange.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: r(45),
            height: r(45),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.brandOrangeLight, AppTheme.brandOrange],
              ),
              borderRadius: BorderRadius.circular(r(16)),
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.white),
          ),
          SizedBox(width: r(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified & trusted drivers',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: r(2)),
                Text(
                  'Safe rides. Happy journeys.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_user_outlined,
            color: AppTheme.brandOrange,
            size: r(38),
          ),
        ],
      ),
    );
  }

  Widget _safetyCard(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.fromLTRB(r(20), r(4), r(20), r(22)),
      padding: EdgeInsets.all(r(18)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r(22)),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF101A24), const Color(0xFF0B131C)]
              : [const Color(0xFFFFF7EF), Colors.white],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.brandOrange.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: r(58),
            height: r(58),
            decoration: BoxDecoration(
              color: AppTheme.brandOrange.withValues(
                alpha: isDark ? 0.16 : 0.10,
              ),
              borderRadius: BorderRadius.circular(r(18)),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: AppTheme.brandOrange,
              size: r(32),
            ),
          ),
          SizedBox(width: r(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your safety is our priority',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: r(6)),
                Text(
                  'All drivers are verified and background checked.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06101A) : const Color(0xFFFFFCF8);

    return Scaffold(
      backgroundColor: bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF071523), const Color(0xFF02070C)]
                : [const Color(0xFFFFFCF8), const Color(0xFFFFF7EF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _driversHero(context),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
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

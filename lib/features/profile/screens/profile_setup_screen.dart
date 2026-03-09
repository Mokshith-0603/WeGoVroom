import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/push_notification_service.dart';
import '../../auth/screens/landing_screen.dart';
import '../widgets/avatar_utils.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final nameController = TextEditingController();
  final regController = TextEditingController();
  final phoneController = TextEditingController();

  String gender = 'Male';
  int avatarIndex = 0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data == null || !mounted) return;

    setState(() {
      nameController.text = (data['displayName'] ?? '').toString();
      regController.text = (data['register'] ?? '').toString();
      phoneController.text = (data['phone'] ?? '').toString();
      gender = (data['gender'] ?? 'Male').toString();
      avatarIndex = normalizeAvatarIndex(data['avatar']);
    });
  }

  Future<void> completeProfile() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (user == null) return;

    if (nameController.text.isEmpty ||
        regController.text.isEmpty ||
        phoneController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill all fields')));
      return;
    }

    setState(() => loading = true);

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final existingDoc = await userRef.get();

    final payload = <String, dynamic>{
      'email': user.email,
      'displayName': nameController.text,
      'register': regController.text,
      'phone': phoneController.text,
      'gender': gender,
      'avatar': avatarIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existingDoc.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await userRef.set(payload, SetOptions(merge: true));

    // propagate updated name/avatar throughout the app
    try {
      final displayName = nameController.text;
      final avatar = avatarIndex;
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // update trips owned by this user
      final tripsSnap = await firestore
          .collection('trips')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      for (final doc in tripsSnap.docs) {
        batch.update(doc.reference, {
          'ownerName': displayName,
          'ownerAvatar': avatar,
        });
      }

      // update participation records
      final partsSnap = await firestore
          .collection('tripParticipants')
          .where('userId', isEqualTo: user.uid)
          .get();
      for (final doc in partsSnap.docs) {
        batch.update(doc.reference, {'name': displayName, 'avatar': avatar});
      }

      // update any pending/processed trip requests
      final reqSnap = await firestore
          .collection('tripRequests')
          .where('userId', isEqualTo: user.uid)
          .get();
      for (final doc in reqSnap.docs) {
        batch.update(doc.reference, {'name': displayName, 'avatar': avatar});
      }

      // update sender info on existing chat messages
      final msgSnap = await firestore
          .collection('tripMessages')
          .where('senderId', isEqualTo: user.uid)
          .get();
      for (final doc in msgSnap.docs) {
        batch.update(doc.reference, {
          'senderName': displayName,
          'senderAvatar': avatar,
        });
      }

      await batch.commit();
    } catch (e) {
      // silently ignore any errors updating references
      debugPrint('Failed to propagate profile changes: $e');
    }

    await PushNotificationService.instance.syncCurrentUserToken();

    auth.refresh();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xfff5f7ff), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LandingScreen(),
                        ),
                        (_) => false,
                      );
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 10,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (_, i) {
                      final selected = avatarIndex == i;

                      return GestureDetector(
                        onTap: () => setState(() => avatarIndex = i),
                        child: buildAvatar(i, radius: 26, selected: selected),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: regController,
                        decoration: const InputDecoration(
                          labelText: 'Register number',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField(
                        value: gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (v) => setState(() => gender = v.toString()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xffff7a00), Color(0xffff9a3c)],
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: loading ? null : completeProfile,
                        child: Center(
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Complete Setup',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

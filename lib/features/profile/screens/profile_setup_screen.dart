import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../widgets/avatar_utils.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final nameController = TextEditingController(); // ⭐ NEW
  final regController = TextEditingController();
  final phoneController = TextEditingController();

  String gender = "Male";
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

    final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
    final data = doc.data();
    if (data == null || !mounted) return;

    setState(() {
      nameController.text = (data["displayName"] ?? "").toString();
      regController.text = (data["register"] ?? "").toString();
      phoneController.text = (data["phone"] ?? "").toString();
      gender = (data["gender"] ?? "Male").toString();
      avatarIndex = normalizeAvatarIndex(data["avatar"]);
    });
  }

  Future<void> completeProfile() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (user == null) return;

    if (nameController.text.isEmpty ||
        regController.text.isEmpty ||
        phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Fill all fields")));
      return;
    }

    setState(() => loading = true);

    /// ⭐ SAVE PROFILE (WITH NAME)
    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "email": user.email,
      "displayName": nameController.text, // ⭐ IMPORTANT
      "register": regController.text,
      "phone": phoneController.text,
      "gender": gender,
      "avatar": avatarIndex,
      "createdAt": FieldValue.serverTimestamp(),
    });

    auth.refresh();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil("/", (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();

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
                if (canGoBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),

                const Text(
                  "Complete Your Profile",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                /// AVATAR GRID
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

                /// FORM CARD
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      /// ⭐ NAME FIELD (NEW)
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Full Name",
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: regController,
                        decoration: const InputDecoration(
                          labelText: "Register number",
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField(
                        value: gender,
                        items: const [
                          DropdownMenuItem(
                              value: "Male", child: Text("Male")),
                          DropdownMenuItem(
                              value: "Female", child: Text("Female")),
                          DropdownMenuItem(
                              value: "Other", child: Text("Other")),
                        ],
                        onChanged: (v) => setState(() => gender = v.toString()),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Phone number",
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                /// BUTTON
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
                                  color: Colors.white)
                              : const Text(
                                  "Complete Setup",
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

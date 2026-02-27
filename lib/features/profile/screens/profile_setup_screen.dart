import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';

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
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: selected
                              ? const Color(0xffff7a00)
                              : Colors.grey.shade200,
                          child: Text(
                            "${i + 1}",
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
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
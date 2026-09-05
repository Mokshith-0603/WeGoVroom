import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationIndicatorIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? iconColor;

  const NotificationIndicatorIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Icon(icon, size: size, color: iconColor);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final hasUnread = docs.any((doc) {
          final data = doc.data();
          return data['isRead'] != true;
        });

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: size, color: iconColor),
            if (hasUnread)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xffe53935),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

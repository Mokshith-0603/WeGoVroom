import 'package:flutter/material.dart';

const List<IconData> kAvatarIcons = [
  Icons.person,
  Icons.face,
  Icons.sentiment_very_satisfied,
  Icons.sports_esports,
  Icons.music_note,
  Icons.school,
  Icons.directions_bike,
  Icons.travel_explore,
  Icons.camera_alt,
  Icons.star,
];

const List<Color> kAvatarColors = [
  Color(0xff4e79a7),
  Color(0xfff28e2b),
  Color(0xffe15759),
  Color(0xff76b7b2),
  Color(0xff59a14f),
  Color(0xffedc948),
  Color(0xffb07aa1),
  Color(0xff9c755f),
  Color(0xffbab0ab),
  Color(0xff577590),
];

int normalizeAvatarIndex(dynamic raw) {
  final index = raw is int ? raw : 0;
  if (index < 0) return 0;
  if (index >= kAvatarIcons.length) return 0;
  return index;
}

Widget buildAvatar(int index, {double radius = 22, bool selected = false}) {
  final safeIndex = normalizeAvatarIndex(index);
  final bg = kAvatarColors[safeIndex];

  return CircleAvatar(
    radius: radius,
    backgroundColor: selected ? const Color(0xffff7a00) : bg,
    child: Icon(
      kAvatarIcons[safeIndex],
      color: Colors.white,
      size: radius,
    ),
  );
}

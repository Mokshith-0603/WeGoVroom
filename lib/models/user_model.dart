class AppUser {
  final String uid;
  final String email;
  final String register;
  final String phone;
  final String gender;
  final int avatar;

  AppUser({
    required this.uid,
    required this.email,
    required this.register,
    required this.phone,
    required this.gender,
    required this.avatar,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data["email"] ?? "",
      register: data["register"] ?? "",
      phone: data["phone"] ?? "",
      gender: data["gender"] ?? "",
      avatar: data["avatar"] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "email": email,
      "register": register,
      "phone": phone,
      "gender": gender,
      "avatar": avatar,
    };
  }
}

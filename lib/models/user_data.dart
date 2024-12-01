class UserData {
  final String uid;
  final String fullName;
  final String email;
  final DateTime joinDate;

  const UserData({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.joinDate,
  });


  String get displayName => fullName;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'joinDate': joinDate.millisecondsSinceEpoch,
    };
  }

  factory UserData.fromMap(Map<String, dynamic> map) {
    return UserData(
      uid: map['uid'],
      fullName: map['fullName'],
      email: map['email'],
      joinDate: DateTime.fromMillisecondsSinceEpoch(map['joinDate']),
    );
  }
}

class User {
  final int? id;
  final String username;
  final String passwordHash;
  final String? email;
  final DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.passwordHash,
    this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      passwordHash: map['password_hash'],
      email: map['email'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

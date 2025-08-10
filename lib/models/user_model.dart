class UserModel {
  final int? id;
  final String username;
  final String password; // plain text untuk demo, sebaiknya hash di produksi

  UserModel({this.id, required this.username, required this.password});

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'],
        username: map['username'],
        password: map['password'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'password': password,
      };
}

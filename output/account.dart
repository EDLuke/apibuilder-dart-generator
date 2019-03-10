import 'AccountUnion.dart';

class Account implements AccountUnion {
  Account({this.id, this.first_name, this.last_name, this.email});

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
        id: json['id'],
        first_name: json['first_name'],
        last_name: json['last_name'],
        email: (json.containsKey("email")) ? json['email'] : null);
  }

  final int id;

  final String first_name;

  final String last_name;

  final String email;
}

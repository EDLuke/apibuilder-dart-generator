import 'account.dart';

class NestedAccount {
  NestedAccount({this.account});

  factory NestedAccount.fromJson(Map<String, dynamic> json) {
    return NestedAccount(account: Account.fromJson(json['account']));
  }

  final Account account;
}

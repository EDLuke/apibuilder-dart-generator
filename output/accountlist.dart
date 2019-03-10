import 'AccountUnion.dart';
import 'account.dart';

class AccountList implements AccountUnion {
  AccountList({this.accounts});

  factory AccountList.fromJson(Map<String, dynamic> json) {
    return AccountList(
        accounts: (json['accounts'] as List)
            .map((i) => Account.fromJson(i))
            .toList());
  }

  final List<Account> accounts;
}

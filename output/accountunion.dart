import 'account.dart';
import 'accountlist.dart';

class AccountUnion {
  factory AccountUnion.fromJson(Map<String, dynamic> json) {
    final String type = json['type'];
    json.remove('type');
    switch (type) {
      case 'account':
        return Account.fromJson(json) as AccountUnion;
      case 'account_list':
        return AccountList.fromJson(json) as AccountUnion;
      default:
        throw FormatException('Unknown AccountUnion type: $type');
    }
  }
}

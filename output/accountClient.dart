import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'account.dart';

class AccountClient {
  AccountClient(this.baseUrl);

  final String baseUrl;

  Future<Account> getAccount() async {
    final String url = baseUrl;
    final response = await http.get(url);
    switch (response.statusCode) {
      case 200:
        return Account.fromJson(json.decode(response.body));
      default:
        throw Exception('Failed to load account');
    }
  }
}

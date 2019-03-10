import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'accountunion.dart';

class AccountUnionClient {
  AccountUnionClient(this.baseUrl);

  final String baseUrl;

  Future<AccountUnion> getAccountUnion() async {
    final String url = baseUrl;
    final response = await http.get(url);
    switch (response.statusCode) {
      case 200:
        return AccountUnion.fromJson(json.decode(response.body));
      default:
        throw Exception('Failed to load account_union');
    }
  }
}

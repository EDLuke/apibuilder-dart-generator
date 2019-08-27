import 'dart:convert';

class Generator{
  final String key;
  final String name;
  final String language;
  final String description;
  final List<String> attributes;

  Generator({this.key, this.name, this.language, this.description, this.attributes});

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'language': language,
    "description": description,
    "attributes": attributes
  };

  String toJsonString() => jsonEncode(this);
  String toString() => toJsonString();
}
import 'dart:convert';
import 'dart:io';

import 'package:apibuilder_dart_generator/apibuilder_dart_generator.dart' as apibuilder_dart_generator;
import 'package:built_collection/built_collection.dart';
import 'package:code_builder/code_builder.dart' as dartBuilder;
import 'package:dart_style/dart_style.dart';

main(List<String> arguments) {
  File file = File(arguments.first);
  String jsonRaw = file.readAsStringSync();
//
//  print('animalClass():\n${'=' * 40}\n${animalClass()}!');
//  print('scopedLibrary():\n${'=' * 40}\n${scopedLibrary()}');


  Map<String, dynamic> jsonParsed = json.decode(jsonRaw);

  Map<String, dynamic> models = jsonParsed['models'];

//  models.forEach((key, value) =>
//    print(key+ "\n" + value.toString() + "\n")
//  );

  var modelsList = models.entries.map((MapEntry<String, dynamic> entry) => Model.fromJson(entry.key, entry.value));

  modelsList.forEach((model) => modelClass(model));
}

final _dartfmt = DartFormatter();

String modelClass(Model model){

  final modelGenerated = dartBuilder.Class((b) => b
    ..name = model.name
    ..fields = ListBuilder(model.fields.map((field) => dartBuilder.Field((f) => f
      ..name = field.name
      ..modifier = dartBuilder.FieldModifier.final$
      ..type = dartBuilder.Reference("String")
      )))
    ..constructors.addAll([
      dartBuilder.Constructor((c) => c
        ..requiredParameters = ListBuilder(model.fields.map((field) => dartBuilder.Parameter((p) => p
          ..name = field.name
          ..type = dartBuilder.Reference("String"))))
      ),
      dartBuilder.Constructor((c) => c
        ..factory = true
        ..name = "fromJson"
        ..requiredParameters.add(dartBuilder.Parameter((p) => p
          ..name = "json"
          ..type = dartBuilder.Reference("Map<String, dynamic>")))
          ..body = const dartBuilder.Code(''))
    ]));
  final emitter = dartBuilder.DartEmitter();
  print(DartFormatter().format('${modelGenerated.accept(emitter)}'));
}

class Model{
  final String name;
  final List<Field> fields;

  Model({this.name, this.fields});

  factory Model.fromJson(String name, Map<String, dynamic> json){
    List<Field> fields = (json['fields'] as List).map((i) => Field.fromJson(i)).toList();
    return Model(
      name: toClassName(name),
      fields: fields
    );
  }
}

class Field{
  final String name;
  final String type;

  Field({this.name, this.type});

  factory Field.fromJson(Map<String, dynamic> json){
    return Field(
      name: json["name"],
      type: json["type"]
    );
  }
}

String toClassName(String className){
  return '${className[0].toUpperCase()}${className.substring(1)}';
}
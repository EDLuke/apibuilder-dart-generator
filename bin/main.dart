import 'dart:convert';
import 'dart:io';
import 'package:built_collection/built_collection.dart';
import 'package:code_builder/code_builder.dart' as dartBuilder;
import 'package:dart_style/dart_style.dart';

main(List<String> arguments) {
  File file = File(arguments.first);
  String jsonRaw = file.readAsStringSync();

  Map<String, dynamic> jsonParsed = json.decode(jsonRaw);

  Map<String, dynamic> models = jsonParsed['models'];

  var modelsList = models.entries.map((MapEntry<String, dynamic> entry) => Model.fromJson(entry.key, entry.value));

  modelsList.forEach((model) => modelClass(model));

}

final _dartfmt = DartFormatter();

modelClass(Model model){

  final modelGenerated = dartBuilder.Class((b) => b
    ..name = model.name
    ..fields = ListBuilder(model.fields.map((field) => dartBuilder.Field((f) => f
      ..name = field.name
      ..modifier = dartBuilder.FieldModifier.final$
      ..type = dartBuilder.Reference("String")
      )))
    ..constructors.addAll([
      dartBuilder.Constructor((c) => c
        ..optionalParameters = ListBuilder(model.fields.map((field) => dartBuilder.Parameter((p) => p
          ..name = 'this.${field.name}'
          ..named = true)))
      ),
      dartBuilder.Constructor((c) => c
        ..factory = true
        ..name = "fromJson"
        ..requiredParameters.add(dartBuilder.Parameter((p) => p
          ..name = "json"
          ..type = dartBuilder.Reference("Map<String, dynamic>")))
          ..body = dartBuilder.Code.scope((s){
              return factoryConstructor(model.name, model.fields);
          }))
    ]));
  final emitter = dartBuilder.DartEmitter();
  final String modelString = DartFormatter().format('${modelGenerated.accept(emitter)}');

  final fileName = './output/${model.name.toLowerCase()}.dart';

  new File(fileName).writeAsString(modelString);
}

String factoryConstructor(String name, List<Field> fields) {
  var parameterString = fields.map((f) =>
  '${f.name}: json[\'${f.name}\']'
  ).join(",\n");

  var constructorString =
      'return $name('
      '$parameterString'
      ');';

  return constructorString;
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
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
  Map<String, dynamic> resources = jsonParsed['resources'];

  var modelsList = models.entries.map((MapEntry<String, dynamic> entry) => Model.fromJson(entry.key, entry.value));
  var clientsList = resources.entries.map((MapEntry<String, dynamic> entry) => Client.fromJson(entry.key, entry.value));

  modelsList.forEach((model) => modelClass(model));
  clientsList.forEach((client) => clientClass(client);
}

final _dartfmt = DartFormatter();

modelClass(Model model){

  final modelGenerated = dartBuilder.Class((b) => b
    ..name = model.name
    ..fields = ListBuilder(model.fields.map((field) => dartBuilder.Field((f) => f
      ..name = field.name
      ..modifier = dartBuilder.FieldModifier.final$
      ..type = dartBuilder.Reference(getDartType(field.type))
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

clientClass(Client client){
  
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

class Client{
  final String name;
  final String path;
  final List<Operation> operations;

  Client({this.name, this.path, this.operations});

  factory Client.fromJson(String name, Map<String, dynamic> json){
    List<Operation> operations = (json['operations'] as List).map((i) => Operation.fromJson(i)).toList();
    return Client(
      name: name,
      path: json['path'],
      operations: operations
    );
  }
}

class Operation{
  final String method;
  final String description;
  final List<Parameter> parameters;
  final List<Response> responses;
  
  Operation({this.method, this.description, this.parameters, this.responses});
  
  factory Operation.fromJson(Map<String, dynamic> json){
    List<Parameter> parameters = (json['parameters'] as List).map((i) => Parameter.fromJson(i)).toList();
    return Operation(
      method: json['method'],
      description: json['description'],
      parameters: parameters,
      responses: Responses.fromJson(json['responses']).responses
    );
  }
}

class Parameter{
  final String name;
  final String type;
  final String location;

  Parameter({this.name, this.type, this.location});

  factory Parameter.fromJson(Map<String, dynamic> json){
    return Parameter(
      name: json['name'],
      type: json['type'],
      location: json['location']
    );
  }
}

class Responses{
  final List<Response> responses;
  
  Responses({this.responses});
  
  factory Responses.fromJson(Map<String, dynamic> json){
    List<Response> responses = json.entries.map((entry) => Response.fromJson(int.parse(entry.key), entry.value));
    return Responses(
      responses: responses
    );
  }
}

class Response{
  final int code;
  final String type;
  
  Response({this.code, this.type});
  
  factory Response.fromJson(int code, Map<String, dynamic> json){
    return Response(
      code: code,
      type: json['type']
    );
  }
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

String getDartType(String apiBuilderType){
  apiBuilderType = apiBuilderType.toLowerCase();
  String dartType;

  switch(apiBuilderType){
    case "string":
      dartType = "String";
      break;
    case "boolean":
      dartType = "bool";
      break;
    case "double":
    case "decimal":
      dartType = "double";
      break;
    case "integer":
    case "long":
      dartType = "int";
      break;
    case "json":
      dartType = "Map<String, dynamic>";
      break;
    default:
      throw FormatException('Type $apiBuilderType is unsupported currently');
  }

  return dartType;
}
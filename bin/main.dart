import 'dart:convert';
import 'dart:io';
import 'package:built_collection/built_collection.dart';
import 'package:code_builder/code_builder.dart' as dartBuilder;
import 'package:dart_style/dart_style.dart';


List<Model> modelsList;
List<Client> clientsList;

main(List<String> arguments) {
  File file = File(arguments.first);
  String jsonRaw = file.readAsStringSync();

  Map<String, dynamic> jsonParsed = json.decode(jsonRaw);

  Map<String, dynamic> models = jsonParsed['models'];
  Map<String, dynamic> resources = jsonParsed['resources'];

  modelsList = models.entries.map((MapEntry<String, dynamic> entry) => Model.fromJson(entry.key, entry.value)).toList();
  clientsList = resources.entries.map((MapEntry<String, dynamic> entry) => Client.fromJson(entry.key, entry.value)).toList();

  modelsList.forEach((model) => modelClass(model));
  clientsList.forEach((client) => clientClass(client));
}

modelClass(Model model){

  final modelGenerated = dartBuilder.Class((b) => b
    ..name = model.name
    ..fields = ListBuilder(model.fields.map((field) => dartBuilder.Field((f) => f
      ..name = field.name
      ..modifier = dartBuilder.FieldModifier.final$
      ..type = getDartType(field.type)
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
  final emitter = dartBuilder.DartEmitter(dartBuilder.Allocator());
  final String modelString = DartFormatter().format('${modelGenerated.accept(emitter)}');

  final fileName = './output/${model.name.toLowerCase()}.dart';

  new File(fileName).writeAsString(modelString);
}

clientClass(Client client){
  String clientName = '${toClassName(client.name)}Client';

  final clientGenerated = dartBuilder.Class((c) => c
    ..name = clientName
    ..fields.add(dartBuilder.Field((f) => f
      ..name = "baseUrl"
      ..modifier = dartBuilder.FieldModifier.final$
      ..type = dartBuilder.Reference("String")
    ))
    ..constructors.add(
      dartBuilder.Constructor((c) => c
        ..requiredParameters.add(dartBuilder.Parameter((p) => p
          ..name = 'this.baseUrl'))
      )
    )
    ..methods.addAll(client.operations.map((operation) => operationClass(operation, client.name, client.path)))
  );

  final emitter = dartBuilder.DartEmitter(dartBuilder.Allocator());
  final String modelString = DartFormatter().format('${clientGenerated.accept(emitter)}');

  final String modelStringWithImports =
      "import \'dart:async\';\n"
      "import \'dart:convert\';\n"
      "import \'package:http/http.dart\' as http;\n" + modelString;

  final fileName = './output/${client.name.toLowerCase()}Client.dart';

  new File(fileName).writeAsString(modelStringWithImports);
}

dartBuilder.Method operationClass(Operation operation, String resourceName, String resourcePath){
  final operationGenerated = dartBuilder.Method((m) => m
    ..name = '${operation.method.toLowerCase()}${toClassName(resourceName)}'
    ..returns = dartBuilder.Reference('Future<${toClassName(resourceName)}>', '$resourceName.dart')
    ..modifier = dartBuilder.MethodModifier.async
    ..body = dartBuilder.Code.scope((s) {
      return operationMethod(operation, resourceName);
    })
  );

  return operationGenerated;
}

String operationMethod(Operation operation, String resourceName) {
  String url = "final String url = baseUrl;\n";
  String response = "final response = await http.get(url);\n";

  String responseSwitch = "switch(response.statusCode){\n";
  operation.responses.forEach((response) =>
    responseSwitch += '\tcase ${response.code}:\n \t\treturn ${toClassName(response.type)}.fromJson(json.decode(response.body));\n'
  );
  responseSwitch += "\tdefault:\n \t\tthrow Exception('Failed to load ${resourceName}');\n}\n";

  return url + response + responseSwitch;
}

String factoryConstructor(String name, List<Field> fields) {
  String parameterString = fields.map((f) =>
    factoryConstructorField(f)
  ).join(",\n");

  var constructorString =
      'return $name('
      '$parameterString'
      ');';

  return constructorString;
}

String factoryConstructorField(Field f){
  if(isListType(f.type)) {
    final String type = f.type.substring(1, f.type.length - 1);
    return "${f.name}: (json[\'${f.name}\'] as List).map((i) => ${toClassName(
        type)}.fromJson(i)).toList()";
  }
  else {
    if (isBuiltInType(f.type))
      return '${f.name}: json[\'${f.name}\']';
    else
      return '${f.name}: ${toClassName(f.name)}.fromJson(json[\'${f.name}\'])';
  }
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
    List<Response> responses = json.entries.map((entry) =>
        Response.fromJson(int.parse(entry.key), entry.value)
    ).toList();
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
  //camelCase className
  final List<String> parts = className.split('_');
  StringBuffer output = StringBuffer();
  parts.forEach((p) =>
    output.write(toProperCase(p))
  );
  return output.toString();
}

String toProperCase(String s){
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

dartBuilder.Reference getDartType(String apiBuilderType){
  apiBuilderType = apiBuilderType.toLowerCase();
  String dartType;
  String import;

  bool isArray = isListType(apiBuilderType);

  if(isArray)
    apiBuilderType = apiBuilderType.substring(1, apiBuilderType.length - 1);

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
      if(modelsList.any((model) => model.name.toLowerCase() == apiBuilderType)) {
        dartType = toClassName(apiBuilderType);
        import = "$apiBuilderType.dart";
        break;
      }
      else
        throw FormatException('Type $apiBuilderType is not found');
  }

  if(isArray)
    dartType = "List<$dartType>";

  return dartBuilder.Reference(dartType, import);
}

bool isListType(String apiBuilderType){
  return apiBuilderType.startsWith("[") && apiBuilderType.endsWith("]");
}

bool isBuiltInType(String apiBuilderType){
  return apiBuilderType == "string" ||
      apiBuilderType == "boolean" ||
      apiBuilderType == "double" ||
      apiBuilderType == "decimal" ||
      apiBuilderType == "integer" ||
      apiBuilderType == "long" ||
      apiBuilderType == "json";
}
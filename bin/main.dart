import 'dart:convert';
import 'dart:io';
import 'package:built_collection/built_collection.dart';
import 'package:code_builder/code_builder.dart' as dartBuilder;
import 'package:dart_style/dart_style.dart';


List<Model> modelsList;
List<Client> clientsList;
List<Union> unionsList;
String outputDir;

main(List<String> arguments) {
  File file = File(arguments.first);
  outputDir = arguments[1];
  String jsonRaw = file.readAsStringSync();

  Map<String, dynamic> jsonParsed = json.decode(jsonRaw);

  Map<String, dynamic> models = jsonParsed['models'];
  Map<String, dynamic> resources = jsonParsed['resources'];
  Map<String, dynamic> unions = jsonParsed['unions'];

  modelsList = models.entries.map((MapEntry<String, dynamic> entry) => Model.fromJson(entry.key, entry.value)).toList();
  clientsList = resources.entries.map((MapEntry<String, dynamic> entry) => Client.fromJson(entry.key, entry.value)).toList();
  unionsList = unions.entries.map((MapEntry<String, dynamic> entry) => Union.fromJson(entry.key, entry.value)).toList();

  modelsList.forEach((model) => modelClass(model));
  clientsList.forEach((client) => clientClass(client));
  unionsList.forEach((union) => unionClass(union));
}

modelClass(Model model){
  final String modelClassName = toClassName(model.name);
  
  final modelGenerated = dartBuilder.Class((b) => b
    ..name = modelClassName
    ..implements.addAll(getUnionType(model.name))
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
              return factoryConstructor(modelClassName, model.fields);
          }))
    ]));
  final emitter = dartBuilder.DartEmitter(dartBuilder.Allocator());
  final String modelString = DartFormatter().format('${modelGenerated.accept(emitter)}');

  final fileName = '$outputDir/${modelClassName.toLowerCase()}.dart';

  new File(fileName).writeAsString(modelString);
}

clientClass(Client client){
  final String clientName = '${toClassName(client.name)}Client';

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

  final fileName = '$outputDir/${clientName.toLowerCase()}.dart';

  new File(fileName).writeAsString(modelStringWithImports);
}

unionClass(Union union){
  final String unionClassName = toClassName(union.name);

  //Generate empty class for interface
  final interfaceGenerated = dartBuilder.Class((b) => b
    ..name = unionClassName
    ..constructors.add(
      dartBuilder.Constructor((c) => c
        ..factory = true
        ..name = "fromJson"
        ..requiredParameters.add(dartBuilder.Parameter((p) => p
          ..name = "json"
          ..type = dartBuilder.Reference("Map<String, dynamic>")))
          ..body = dartBuilder.Code.scope((s){
            return factoryUnionConstructor(union);
          }))
      )
    );

  final emitter = dartBuilder.DartEmitter(dartBuilder.Allocator());
  final String unionString = DartFormatter().format('${interfaceGenerated.accept(emitter)}');

  final String unionStringWithImports =
      union.types.map((type) => "import \'${toClassName(type).toLowerCase()}.dart\';").join("\n") +
          "\n\n" +
          unionString;

  final fileName = '$outputDir/${unionClassName.toLowerCase()}.dart';

  new File(fileName).writeAsString(unionStringWithImports);

}


dartBuilder.Method operationClass(Operation operation, String resourceName, String resourcePath){
  final operationGenerated = dartBuilder.Method((m) => m
    ..name = '${operation.method.toLowerCase()}${toClassName(resourceName)}'
    ..returns = dartBuilder.Reference('Future<${toClassName(resourceName)}>', '${toClassName(resourceName).toLowerCase()}.dart')
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
  String block;

  if(isListType(f.type)) {
    final String type = f.type.substring(1, f.type.length - 1);
    block = "(json[\'${f.name}\'] as List).map((i) => ${toClassName(
        type)}.fromJson(i)).toList()";
  }
  else {
    if (isBuiltInType(f.type))
      block = 'json[\'${f.name}\']';
    else
      block = '${toClassName(f.name)}.fromJson(json[\'${f.name}\'])';
  }

  return '${f.name}: ${factoryConstructorOptionalBlock(f, block)}';
}

String factoryConstructorOptionalBlock(Field f, String block){
  if(f.required)
    return block;
  else{
    return "(json.containsKey(\"${f.name}\")) ? $block : null";
  }
}

/*
*
import 'account.dart';
import 'accountlist.dart';

class AccountUnion {

  factory AccountUnion.fromJson(Map<String, dynamic> json){
    final String type = json['type'];
    json.remove('type');

    switch(type){
      case 'account':
        return Account.fromJson(json) as AccountUnion;
      case 'account_list':
        return AccountList.fromJson(json) as AccountUnion;
      default:
        throw FormatException('Unknown AccountUnion type: $type');
    }
  }
}
*/

String factoryUnionConstructor(Union union){
  final String typeDiff =
      "final String type = json[\'type\'];\n"
      "json.remove(\'type\');\n";

  String typeSwitch = "switch(type){\n";
  union.types.forEach((type) =>
    typeSwitch += '\tcase \'$type\':\n\t\t return ${toClassName(type)}.fromJson(json) as ${toClassName(union.name)};\n'
  );
  typeSwitch += '\tdefault:\n\t\tthrow FormatException(\'Unknown ${toClassName(union.name)} type: \$type\');\n}';

  return typeDiff + typeSwitch;
}

class Union{
  final String name;
  final List<String> types;

  Union({this.name, this.types});

  factory Union.fromJson(String name, Map<String, dynamic> json){
    return Union(
      name: name,
      types: (json['types'] as List)
        .map((i) => i['type'])
        .toList()
        .cast<String>()
    );
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
      name: name,
      fields: fields
    );
  }
}

class Field{
  final String name;
  final String type;
  final bool required;

  Field({this.name, this.type, this.required});

  factory Field.fromJson(Map<String, dynamic> json){
    return Field(
      name: json["name"],
      type: json["type"],
      required: (json.containsKey("required")) ? json["required"] : true
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

List<dartBuilder.Reference> getUnionType(String apiBuilderType){
  final Union interface = unionsList.firstWhere((union) => union.types.contains(apiBuilderType), orElse: () => null);

  if(interface != null) {
    final String interfaceClassName = toClassName(interface.name);

    return [dartBuilder.Reference(interfaceClassName, "$interfaceClassName.dart")];
  }
  else
    return List();
}

bool isUnion(String apiBuilderType){
  return unionsList.firstWhere((union) => union.types.contains(apiBuilderType), orElse: () => null) != null;
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
import 'dart:convert';
import 'dart:io';
import 'dart:io' as dart;
import 'package:built_collection/built_collection.dart';
import 'package:code_builder/code_builder.dart' as dartBuilder;
import 'package:dart_style/dart_style.dart';

import 'models/server_models.dart';
import 'models/server_models.dart' as prefix0;




main(List<String> arguments) {
  dart.File file = dart.File(arguments.first);
//  outputDir = arguments[1];
  String jsonRaw = file.readAsStringSync();

  Map<String, dynamic> jsonParsed = json.decode(jsonRaw);
  InvocationForm invocationForm = InvocationForm.fromJson(jsonParsed);
  FileGenerator generator = new FileGenerator(invocationForm);

  Invocation invocation = generator.getInvocation();
//  print(invocation.toJsonString());
//  List<File> modelFile = invocationForm.service.models.map((Model entry) => modelClass(entry)).toList();
//  List<File> resourceFile = invocationForm.service.resources.map((Resource entry) => clientClass(entry)).toList();
//  List<File> unionFile = invocationForm.service.unions.map((Union entry) => unionClass(entry)).toList();
//
//  Map<String, dynamic> models = jsonParsed['models'];
//  Map<String, dynamic> resources = jsonParsed['resources'];
//  Map<String, dynamic> unions = jsonParsed['unions'];
//
//  modelsList = models.entries.map((MapEntry<String, dynamic> entry) => Model.fromJson(entry.key, entry.value)).toList();
//  resourcesList = resources.entries.map((MapEntry<String, dynamic> entry) => Resource.fromJson(entry.key, entry.value)).toList();
//  unionsList = unions.entries.map((MapEntry<String, dynamic> entry) => Union.fromJson(entry.key, entry.value)).toList();
//
//  modelsList.forEach((model) => modelClass(model));
//  resourcesList.forEach((client) => clientClass(client));
//  unionsList.forEach((union) => unionClass(union));
}

class FileGenerator {

  List<Model> modelsList;
  List<Resource> resourcesList;
  List<Union> unionsList;
  String outputDir;

  FileGenerator(InvocationForm invocationForm) {
    modelsList = invocationForm.service.models;
    resourcesList = invocationForm.service.resources;
    unionsList = invocationForm.service.unions;
  }

  Invocation getInvocation(){
    List<File> modelFile = modelsList.map((Model entry) => modelClass(entry)).toList();
    List<File> resourceFile = resourcesList.map((Resource entry) => clientClass(entry)).toList();
    List<File> unionFile = unionsList.map((Union entry) => unionClass(entry)).toList();

    return new Invocation([...modelFile, ...resourceFile, ...unionFile]);
  }

  File modelClass(Model model) {
    final String modelClassName = toClassName(model.name);
    final List<dartBuilder.Reference> unionType = getUnionType(model.name);
    final bool hasUnion = unionType.isNotEmpty;

    final modelGenerated = dartBuilder.Class((b) {
      return b
        ..name = modelClassName
        ..implements.addAll(unionType)
        ..fields = ListBuilder(model.fields.map((field) =>
            dartBuilder.Field((f) =>
            f
              ..name = field.name
              ..modifier = dartBuilder.FieldModifier.final$
              ..type = getDartType(field.type)
            )))
        ..constructors.addAll([
          dartBuilder.Constructor((c) =>
          c
            ..initializers.addAll(
                (hasUnion) ? [dartBuilder.Code("super()")] : [])
            ..optionalParameters = ListBuilder(model.fields.map((field) =>
                dartBuilder.Parameter((p) =>
                p
                  ..name = 'this.${field.name}'
                  ..named = true)))
          ),
          dartBuilder.Constructor((c) =>
          c
            ..factory = true
            ..name = "fromJson"
            ..requiredParameters.add(dartBuilder.Parameter((p) =>
            p
              ..name = "json"
              ..type = dartBuilder.Reference("Map<String, dynamic>")))
            ..body = dartBuilder.Code.scope((s) {
              return factoryConstructor(modelClassName, model.fields);
            }))
        ]);
    });
    final emitter = dartBuilder.DartEmitter(dartBuilder.Allocator());
    final String modelString = DartFormatter().format(
        '${modelGenerated.accept(emitter)}');

    final fileName = '${model.name}.dart';

    return new File(fileName, modelString);
  }

  File clientClass(Resource client) {
    final String clientName = '${toClassName(client.name)}Client';

    final clientGenerated = dartBuilder.Class((c) =>
    c
      ..name = clientName
      ..fields.add(dartBuilder.Field((f) =>
      f
        ..name = "baseUrl"
        ..modifier = dartBuilder.FieldModifier.final$
        ..type = dartBuilder.Reference("String")
      ))
      ..constructors.add(
          dartBuilder.Constructor((c) =>
          c
            ..requiredParameters.add(dartBuilder.Parameter((p) =>
            p
              ..name = 'this.baseUrl'))
          )
      )
      ..methods = ListBuilder(client.operations.map((operation) =>
          operationClass(operation, client.name, client.path)))
    );

    final emitter = dartBuilder.DartEmitter(dartBuilder.Allocator());
    final String modelString = DartFormatter().format(
        '${clientGenerated.accept(emitter)}');

    final String modelStringWithImports =
        "import \'dart:async\';\n"
            "import \'dart:convert\';\n"
            "import \'package:http/http.dart\' as http;\n" + modelString;

    final fileName = '${clientName.toLowerCase()}.dart';

    return new File(fileName, modelStringWithImports);
  }

  File unionClass(Union union) {
    final String unionClassName = toClassName(union.name);

    //Generate empty class for interface
    final interfaceGenerated = dartBuilder.Class((b) =>
    b
      ..name = unionClassName
      ..constructors.addAll([
        dartBuilder.Constructor((c) =>
        c
          ..factory = true
          ..name = "fromJson"
          ..requiredParameters.add(dartBuilder.Parameter((p) =>
          p
            ..name = "json"
            ..type = dartBuilder.Reference("Map<String, dynamic>")))
          ..body = dartBuilder.Code.scope((s) {
            return factoryUnionConstructor(union);
          })),
        dartBuilder.Constructor((c) => c
        )
      ]
      )
    );

    final emitter = dartBuilder.DartEmitter(dartBuilder.Allocator());
    final String unionString = DartFormatter().format(
        '${interfaceGenerated.accept(emitter)}');

    final String unionStringWithImports =
        union.types.map((type) => "import \'${toClassName(type)
            .toLowerCase()}.dart\';").join("\n") +
            "\n\n" +
            unionString;

    final fileName = '${union.name}.dart';

    return new File(fileName, unionStringWithImports);
  }


  dartBuilder.Method operationClass(Operation operation, String resourceName,
      String resourcePath) {
    final operationGenerated = dartBuilder.Method((m) =>
    m
      ..name = '${operation.method.toLowerCase()}${toClassName(resourceName)}'
      ..requiredParameters = operationRequiredParameters(operation.parameters)
      ..returns = dartBuilder.Reference('Future<${toClassName(resourceName)}>',
          '${toClassName(resourceName).toLowerCase()}.dart')
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
    responseSwitch += operationResponse(response.code, response.type)
    );
    responseSwitch +=
    "\tdefault:\n \t\tthrow Exception('Failed to load ${resourceName}');\n}\n";

    return url + response + responseSwitch;
  }

  String operationResponse(int responseCode, String type) {
    final String caseString = '\tcase ${responseCode}:\n';

    if (isUnitType(type))
      return caseString + '\t\treturn null;\n';
    else
      return caseString + '\t\treturn ${toClassName(
          type)}.fromJson(json.decode(response.body));\n';
  }

  ListBuilder<dartBuilder.Parameter> operationRequiredParameters(
      List<Parameter> parameters) {
//    parameters.forEach((parameter) =>
//        print(parameter.name + "\t" + parameter.type));

    List<Parameter> requiredParameter = parameters;
    requiredParameter.retainWhere((parameter) =>
    parameter.location != "header");

    List<dartBuilder.Parameter> requiredParameterDart
    = requiredParameter.map((parameter) => operationParameter(parameter))
        .toList();

    return ListBuilder<dartBuilder.Parameter>(requiredParameterDart);
//  return ListBuilder();

  }

  dartBuilder.Parameter operationParameter(Parameter parameter) {
    return dartBuilder.Parameter((p) =>
    p
      ..name = parameter.name
      ..type = getDartType(parameter.type)
    );
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

  String factoryConstructorField(Field f) {
    String block;

    if (isListType(f.type)) {
      final String type = f.type.substring(1, f.type.length - 1);

      if (isBuiltInType(type))
        block =
        ("new List<${getDartType(type).symbol}>.from(json[\'${f.name}\'])");
      else
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

  String factoryConstructorOptionalBlock(Field f, String block) {
    if (f.required)
      return block;
    else {
      return "(json.containsKey(\"${f.name}\")) ? $block : null";
    }
  }

  String factoryUnionConstructor(Union union) {
    final String typeDiff =
        "final String type = json[\'type\'];\n"
        "json.remove(\'type\');\n";

    String typeSwitch = "switch(type){\n";
    union.types.forEach((type) =>
    typeSwitch += '\tcase \'$type\':\n\t\t return ${toClassName(
        type)}.fromJson(json) as ${toClassName(union.name)};\n'
    );
    typeSwitch +=
    '\tdefault:\n\t\tthrow FormatException(\'Unknown ${toClassName(
        union.name)} type: \$type\');\n}';

    return typeDiff + typeSwitch;
  }


  String toClassName(String className) {
    //camelCase className
    final List<String> parts = className.split('_');
    StringBuffer output = StringBuffer();
    parts.forEach((p) =>
        output.write(toProperCase(p))
    );
    return output.toString();
  }

  String toProperCase(String s) {
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  dartBuilder.Reference getDartType(String apiBuilderType) {
    apiBuilderType = apiBuilderType.toLowerCase();
    String dartType;
    String import;

    bool isArray = isListType(apiBuilderType);

    if (isArray)
      apiBuilderType = apiBuilderType.substring(1, apiBuilderType.length - 1);

    switch (apiBuilderType) {
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
        if (modelsList.any((model) =>
        model.name.toLowerCase() == apiBuilderType)) {
          dartType = toClassName(apiBuilderType);
          import = "$apiBuilderType.dart";
          break;
        }
        else if (unionsList.any((union) => union.name.toLowerCase() ==
            apiBuilderType)) {
          dartType = toClassName(apiBuilderType);
          import = "$apiBuilderType.dart";
          break;
        }
        else
          throw FormatException('Type $apiBuilderType is not found');
    }

    if (isArray)
      dartType = "List<$dartType>";

    return dartBuilder.Reference(dartType, import);
  }

  List<dartBuilder.Reference> getUnionType(String apiBuilderType) {
    final Union interface = unionsList.firstWhere((union) =>
        union.types.contains(apiBuilderType), orElse: () => null);

    if (interface != null) {
      final String interfaceClassName = toClassName(interface.name);

      return [
        dartBuilder.Reference(interfaceClassName, "$interfaceClassName.dart")
      ];
    }
    else
      return List();
  }

  bool isUnion(String apiBuilderType) {
    return unionsList.firstWhere((union) =>
        union.types.contains(apiBuilderType), orElse: () => null) != null;
  }

  bool isListType(String apiBuilderType) {
    return apiBuilderType.startsWith("[") && apiBuilderType.endsWith("]");
  }

  bool isBuiltInType(String apiBuilderType) {
    return apiBuilderType == "string" ||
        apiBuilderType == "boolean" ||
        apiBuilderType == "double" ||
        apiBuilderType == "decimal" ||
        apiBuilderType == "integer" ||
        apiBuilderType == "long" ||
        apiBuilderType == "json";
  }

  bool isUnitType(String type) {
    return type == "unit";
  }
}
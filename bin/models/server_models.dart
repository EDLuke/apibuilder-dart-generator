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

class InvocationForm{
  final Service service;

  InvocationForm({this.service});

  factory InvocationForm.fromJson(Map<String, dynamic> json){
    return InvocationForm(
      service: Service.fromJson(json["service"])
    );
  }
}

class Invocation{
  final List<File> files;

  Invocation({this.files});
}

class File{
  final String name;
  final String contents;

  File({this.name, this.contents});
}

class Service{
  final List<Union> unions;
  final List<Model> models;
  final List<Resource> resources;

  Service({this.unions, this.models, this.resources});

  factory Service.fromJson(Map<String, dynamic> json){
    Map<String, dynamic> models = json['models'];
    Map<String, dynamic> resources = json['resources'];
    Map<String, dynamic> unions = json['unions'];

    List<Model> modelsList = models.entries.map((MapEntry<String, dynamic> entry) => Model.fromJson(entry.key, entry.value)).toList();
    List<Resource> resourcesList = resources.entries.map((MapEntry<String, dynamic> entry) => Resource.fromJson(entry.key, entry.value)).toList();
    List<Union> unionsList = unions.entries.map((MapEntry<String, dynamic> entry) => Union.fromJson(entry.key, entry.value)).toList();

    return Service(
      unions: unionsList,
      models: modelsList,
      resources: resourcesList
    );
  }
}

class ApiDoc{
  final String version;

  ApiDoc({this.version});


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

class Resource{
  final String name;
  final String path;
  final List<Operation> operations;

  Resource({this.name, this.path, this.operations});

  factory Resource.fromJson(String name, Map<String, dynamic> json){
    List<Operation> operations = (json['operations'] as List).map((i) => Operation.fromJson(i)).toList();
    return Resource(
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
import 'dart:io';

import 'models/server_models.dart';

List<Generator> generators = [new Generator(
    key: "1",
    name: "Flutter Generator",
    language: "dart",
    description: "Flutter network client generator",
    attributes: []
)];

Future main() async {
  var portEnv = Platform.environment['PORT'];
  var port = portEnv == null ? 4040 : int.parse(portEnv);

  var server = await HttpServer.bind(
    InternetAddress.anyIPv6,
    port,
  );
  print('Listening on:${server.port}');

  await for (HttpRequest request in server) {
    handleRequest(request);
    await request.response.close();
  }
}

void handleRequest(HttpRequest request){
  try{
    if(request.method == 'GET'){
      handleGet(request);
    } else
      sendMethodNotAllowed(request.response, request.method);
  } catch (e, stacktrace) {
    print('Exception in handleRequest: $e');
    print(stacktrace);
  }
}

void handleGet(HttpRequest request) {
  List<String> segments = request.uri.pathSegments;

  final response = request.response;

  if(segments.isEmpty)
    sendNotFound(response);
  else{
    if(segments.first == "generators"){
      if(segments.length == 1){
        response
          ..statusCode = HttpStatus.ok
          ..write(generators.toString())
          ..close();
      }
      else if(segments.length == 2 && segments[1] == "1"){
          response
          ..statusCode = HttpStatus.ok
          ..write(generators.first.toString())
          ..close();
      }
      else
        sendNotFound(response);
    }
    else if(segments.first == "_internal_"){
      if(segments.length < 2 || segments[1] != "healthcheck")
        sendNotFound(response);
      else {
        response
          ..statusCode = HttpStatus.ok
          ..close();
      }
    }
    else
      sendNotFound(response);
  }
}

void handlePost(HttpRequest request){

}

void sendNotFound(HttpResponse response){
  response
    ..statusCode = HttpStatus.notFound
    ..close();
}

void sendMethodNotAllowed(HttpResponse response, String method){
  response
    ..statusCode = HttpStatus.methodNotAllowed
    ..write('Unsupported request: $method.')
    ..close();
}
import 'dart:convert';
import 'dart:io';
import 'dart:io' as prefix0;

import 'generator.dart';
import 'models/server_models.dart';

List<Generator> generators = [new Generator(
    key: "dart_client",
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
    final HttpResponse response = await handleRequest(request);
    await response.close();
  }
}

Future<HttpResponse> handleRequest(HttpRequest request) async {
  try{
    if(request.method == 'GET')
      return handleGet(request);
    else if(request.method == 'POST')
      return await handlePost(request);
    else
      sendMethodNotAllowed(request.response, request.method);
  } catch (e, stacktrace) {
    print('Exception in handleRequest: $e');
    print(stacktrace);

    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write("Exception during file I/O: $e.");
  } finally {
    return request.response;
  }
}

Future<HttpResponse> handleGet(HttpRequest request) async {
  final List<String> segments = request.uri.pathSegments;
  final response = request.response;

  if(segments.isEmpty)
    sendNotFound(response);
  else{
    if(segments.first == "generators"){
      if(segments.length == 1){
        response
          ..statusCode = HttpStatus.ok
          ..write(generators.toString());
      }
      else if(segments.length == 2 && segments[1] == "1") {
        response
          ..statusCode = HttpStatus.ok
          ..write(generators.first.toString());
      }
      else
        sendNotFound(response);
    }
    else if(segments.first == "_internal_"){
      if(segments.length < 2 || segments[1] != "healthcheck")
        sendNotFound(response);
      else {
        response
          ..statusCode = HttpStatus.ok;
      }
    }
    else
      sendNotFound(response);
  }
  
  return response;
}

Future<HttpResponse> handlePost(HttpRequest request) async {
  final List<String> segments = request.uri.pathSegments;
  final response = request.response;

  if(segments.length != 2)
    sendNotFound(response);
  else{
    if(segments.first == "invocations" && segments[1] == "1"){
      try{
        String content = await utf8.decoder.bind(request).join();
        Map<String, dynamic> jsonParsed = jsonDecode(content);
        InvocationForm invocationForm = InvocationForm.fromJson(jsonParsed);
        String jsonRet = invocationFormToInvocation(invocationForm).toJsonString();
        print(jsonRet);
        response
          ..statusCode = HttpStatus.ok
          ..write(jsonRet);
      }catch (e, stacktrace) {
        print(e);
        print(stacktrace);
//        response
//          ..statusCode = HttpStatus.internalServerError
//          ..write("Exception during file I/O: $e.");
      }
    }
    else
      sendNotFound(response);
  }
  
  return response;
}

Invocation invocationFormToInvocation(InvocationForm form){
  FileGenerator generator = new FileGenerator(form);

  return generator.getInvocation();
}

void sendNotFound(HttpResponse response){
  response
    ..statusCode = HttpStatus.notFound;
}

void sendMethodNotAllowed(HttpResponse response, String method){
  response
    ..statusCode = HttpStatus.methodNotAllowed
    ..write('Unsupported request: $method.');
}